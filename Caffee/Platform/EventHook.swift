import ApplicationServices
import Carbon
import Cocoa
import Foundation

// EventHook manages keyboard events and interacts with the Telex engine.
class EventHook {

  var eventTap: CFMachPort?
  var keyLayout: KeyboardUS
  var inputProcessor: InputProcessor
  var processing = false
  weak var appState: AppState?

  private var runLoopSource: CFRunLoopSource?
  private var secureInputTimer: Timer?
  private let secureInputChecker: () -> Bool
  private(set) var secureInputActive = false

  /// Tracks how many times the tap has been auto-recovered
  var tapRecoveryCount = 0

  init(
    inputProcessor: InputProcessor,
    secureInputChecker: @escaping () -> Bool = { IsSecureEventInputEnabled() }
  ) {
    self.keyLayout = KeyboardUS()
    self.inputProcessor = inputProcessor
    self.secureInputChecker = secureInputChecker
  }

  deinit {
    destroy()
  }

  func setEnabled(_ value: Bool) {
    self.processing = value
    self.inputProcessor.newWord()
  }

  // Checks if the application has accessibility permissions.
  func isTrusted(prompt: Bool = true) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt as CFBoolean]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
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
    secureInputActive = false
    appState?.secureInputActive = false
    appState = nil
  }

  // Sets up the event tap to listen for keyboard and mouse events.
  func setupEventTap(give appState: AppState) {
    precondition(Thread.isMainThread)
    destroy()
    self.appState = appState
    startSecureInputMonitoring()

    let eventMask =
      (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
      | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventTapCallback,
        userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
      )
    else {
      print("Failed to create event tap")
      return
    }

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    self.eventTap = eventTap
    self.runLoopSource = runLoopSource
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
      if !self.refreshSecureInputState(), let eventTap = self.eventTap,
        !CGEvent.tapIsEnabled(tap: eventTap)
      {
        self.recoverEventTap()
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
    #if DEBUG
      print("[Caffee] Event tap auto-recovered (count: \(tapRecoveryCount))")
    #endif
  }

  func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // A disabled tap may stop sending normal callbacks. The timer also checks it.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      recoverEventTap()
      return Unmanaged.passRetained(event)
    }

    // Ignore keystrokes not from hardware (HID system state).
    if event.getIntegerValueField(.eventSourceStateID) != 1 {
      return Unmanaged.passRetained(event)
    }

    // Always use a fresh system sample, not the last timer/UI value, for safety.
    let isSecureInput = refreshSecureInputState()
    if type == .keyDown && processing {
      if isSecureInput {
        return Unmanaged.passRetained(event)
      }
      return inputProcessor.handleEvent(event: event)
    } else if type == .leftMouseDown || type == .rightMouseDown {
      inputProcessor.newWord()
    }
    return Unmanaged.passRetained(event)
  }
}

// Callback function for the event tap.
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passRetained(event) }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()
  return eventHook.handleEvent(type: type, event: event)
}
