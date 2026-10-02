@preconcurrency import ApplicationServices
import Carbon
import Cocoa
import Foundation
import os

enum Log {
  static let tap = Logger(subsystem: "com.khanhicetea.Caffee", category: "tap")
  static let app = Logger(subsystem: "com.khanhicetea.Caffee", category: "app")
  static let automation = Logger(subsystem: "com.khanhicetea.Caffee", category: "automation")
  static let accessibility = Logger(subsystem: "com.khanhicetea.Caffee", category: "accessibility")

  static let subsystem = "com.khanhicetea.Caffee"
}

/// Health of the global keyboard event tap, surfaced in the menu bar.
enum TapStatus: Equatable {
  /// No tap has been requested yet (e.g. waiting for Accessibility permission).
  case inactive
  case active
  /// `CGEvent.tapCreate` failed.
  case failed
  /// A tap exists but Accessibility trust was revoked while running.
  case permissionRevoked

  var isHealthy: Bool { self == .active || self == .inactive }
}

/// Owns the global event tap. The tap runs on the main run loop, so everything here is
/// main-actor isolated; the C callback re-enters isolation with `MainActor.assumeIsolated`.
@MainActor
final class EventHook {

  var eventTap: CFMachPort?
  var inputProcessor: InputProcessor
  var processing = false
  weak var appState: AppState?

  private var runLoopSource: CFRunLoopSource?
  private var secureInputTimer: Timer?
  private let secureInputChecker: () -> Bool
  private let trustChecker: () -> Bool
  /// Whether real key events must queue behind pending synthetic output.
  private let isOutputBusy: () -> Bool
  /// Re-posts a real key event behind pending synthetic output.
  private let repostEvent: (CGEvent) -> Void
  private var tapUserInfo: Unmanaged<EventHook>?
  private(set) var secureInputActive = false
  private(set) var tapStatus: TapStatus = .inactive

  /// Tracks how many times the tap has been auto-recovered
  var tapRecoveryCount = 0

  init(
    inputProcessor: InputProcessor,
    poster: KeyEventPoster = KeyEventPoster(),
    secureInputChecker: @escaping () -> Bool = { IsSecureEventInputEnabled() },
    trustChecker: @escaping () -> Bool = { AXIsProcessTrusted() },
    isOutputBusy: (() -> Bool)? = nil,
    repostEvent: ((CGEvent) -> Void)? = nil
  ) {
    self.inputProcessor = inputProcessor
    self.secureInputChecker = secureInputChecker
    self.trustChecker = trustChecker
    self.isOutputBusy = isOutputBusy ?? { poster.isBusy }
    self.repostEvent = repostEvent ?? { poster.repost($0) }
  }

  func setEnabled(_ value: Bool) {
    self.processing = value
    self.inputProcessor.newWord()
  }

  // Removes the event tap before the application terminates.
  func destroy() {
    secureInputTimer?.invalidate()
    secureInputTimer = nil
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    runLoopSource = nil
    if let eventTap {
      CFMachPortInvalidate(eventTap)
    }
    eventTap = nil
    tapUserInfo?.release()
    tapUserInfo = nil
    secureInputActive = false
    appState?.secureInputActive = false
    publish(tapStatus: .inactive)
    appState = nil
  }

  private func publish(tapStatus status: TapStatus) {
    tapStatus = status
    if let appState, appState.tapStatus != status {
      appState.tapStatus = status
    }
  }

  // Sets up the event tap to listen for keyboard and mouse events.
  func setupEventTap(give appState: AppState) {
    precondition(Thread.isMainThread)
    destroy()
    self.appState = appState
    startSecureInputMonitoring()

    // Don't let a hung target app stall the tap through a slow Accessibility query.
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.1)

    let eventMask =
      (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
      | (1 << CGEventType.flagsChanged.rawValue)
      | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
      | (1 << CGEventType.otherMouseDown.rawValue)

    // The tap callback gets this pointer; retain it until `destroy()` so a late callback can
    // never see a freed hook.
    let userInfo = Unmanaged.passRetained(self)
    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventTapCallback,
        userInfo: UnsafeMutableRawPointer(userInfo.toOpaque())
      )
    else {
      userInfo.release()
      Log.tap.error("Failed to create event tap (Accessibility trusted: \(self.trustChecker()))")
      publish(tapStatus: .failed)
      return
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
    self.tapUserInfo = userInfo
    publish(tapStatus: .active)
  }

  // Secure Input suppresses keyboard tap callbacks, so do not use them as the only
  // source of state updates. Common modes keep polling while a menu is open.
  func startSecureInputMonitoring() {
    precondition(Thread.isMainThread)
    secureInputTimer?.invalidate()
    refreshSecureInputState()
    let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }
      MainActor.assumeIsolated {
        let isSecureInput = self.refreshSecureInputState()
        guard let eventTap = self.eventTap else { return }
        if !self.trustChecker() {
          self.publish(tapStatus: .permissionRevoked)
        } else if !isSecureInput && !CGEvent.tapIsEnabled(tap: eventTap) {
          self.recoverEventTap()
        } else if self.tapStatus == .permissionRevoked {
          self.publish(tapStatus: .active)
        }
      }
    }
    timer.tolerance = 0.1
    secureInputTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  @discardableResult
  func refreshSecureInputState() -> Bool {
    precondition(Thread.isMainThread)
    let isSecureInput = secureInputChecker()
    if secureInputActive != isSecureInput {
      secureInputActive = isSecureInput
      // Never reuse a word typed before entering or leaving a protected field.
      inputProcessor.newWord()
    }
    // The tap and timer both run on the main run loop. Publish synchronously so
    // an older queued update cannot overwrite a newer Secure Input sample.
    if let appState, appState.secureInputActive != isSecureInput {
      appState.secureInputActive = isSecureInput
    }
    return isSecureInput
  }

  private func recoverEventTap() {
    guard let eventTap else { return }
    CGEvent.tapEnable(tap: eventTap, enable: true)
    tapRecoveryCount += 1
    Log.tap.notice("Event tap auto-recovered (count: \(self.tapRecoveryCount))")
    if tapStatus == .permissionRevoked && trustChecker() { publish(tapStatus: .active) }
  }

  /// Returns `result` unchanged unless earlier synthetic output is still being posted. In that
  /// case a key that would pass straight through is re-posted behind the pending output
  /// (and swallowed here), so replacements and real keys always reach the app in order.
  private func ordered(
    _ result: Unmanaged<CGEvent>?, for event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    guard result != nil, isOutputBusy() else { return result }
    repostEvent(event)
    return nil
  }

  func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // The event belongs to the system for the duration of the callback: pass it back
    // unretained, never `passRetained` (that leaks one reference per event).
    let passThrough = Unmanaged.passUnretained(event)

    // A disabled tap may stop sending normal callbacks. The timer also checks it.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      recoverEventTap()
      return passThrough
    }

    // Never reprocess what Caffee itself posted.
    if KeyEventPoster.isSynthetic(event) {
      return passThrough
    }

    // Always use a fresh system sample, not the last timer/UI value, for safety.
    let isSecureInput = refreshSecureInputState()

    switch type {
    case .keyDown:
      let result =
        processing && !isSecureInput ? inputProcessor.handleEvent(event: event) : passThrough
      return ordered(result, for: event)
    case .keyUp:
      return ordered(passThrough, for: event)
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
      inputProcessor.newWord()
      return passThrough
    default:
      return passThrough
    }
  }
}

// Callback function for the event tap.
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()
  // The tap source is on the main run loop, so this is always the main thread.
  nonisolated(unsafe) let event = event
  return MainActor.assumeIsolated { eventHook.handleEvent(type: type, event: event) }
}
