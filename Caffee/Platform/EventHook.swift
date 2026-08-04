import ApplicationServices
import Cocoa
import Foundation

// Private macOS API to detect secure input mode (password fields)
@_silgen_name("CGSIsSecureEventInputSet")
func CGSIsSecureEventInputSet() -> Bool

// EventHook manages keyboard events and interacts with the Telex engine.
class EventHook {

  private static let spotlightBundleIdentifiers = [
    "com.apple.campo",
    "com.apple.Spotlight",
  ]
  private static let defaultSpotlightBundleIdentifier = "com.apple.campo"
  private static let spotlightObserverMaxSetupAttempts = 5
  private static let spotlightObserverRetryDelay: TimeInterval = 0.05

  var eventTap: CFMachPort?
  var keyLayout: KeyboardUS
  var inputProcessor: InputProcessor
  var processing = false
  var appState: AppState?

  // Retain the exact source added to the run loop so teardown removes that source.
  private var eventTapRunLoopSource: CFRunLoopSource?
  private var spotlightObserver: AXObserver?
  private var spotlightElement: AXUIElement?
  private var spotlightProcessIdentifier: pid_t?
  private var spotlightProcessBundleIdentifier: String?
  private var applicationBeforeSpotlight: String?
  private var spotlightDismissed = false
  private var spotlightOpenPending = false
  private var spotlightProcessObserverTokens: [NSObjectProtocol] = []
  private var spotlightObserverSetupGeneration = 0

  /// Tracks how many times the tap has been auto-recovered
  var tapRecoveryCount = 0

  init(inputProcessor: InputProcessor) {
    self.keyLayout = KeyboardUS()
    self.inputProcessor = inputProcessor
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

  /// Routes input to Spotlight only after a real focus notification or open pre-arm.
  func spotlightFocusedUIElementDidChange() {
    guard !spotlightDismissed else { return }
    guard
      spotlightOpenPending
        || spotlightProcessIdentifier == nil
        || spotlightIsVisible
    else {
      return
    }
    spotlightOpenPending = false
    activateSpotlight()
  }

  /// A visible new Spotlight window is concrete evidence that the overlay opened.
  func spotlightWindowCreated() {
    guard spotlightProcessIdentifier == nil || spotlightIsVisible else { return }
    spotlightWindowCreated(isVisible: true)
  }

  /// Applies the window-created transition after visibility has been verified.
  func spotlightWindowCreated(isVisible: Bool) {
    guard isVisible else { return }
    spotlightDismissed = false
    spotlightOpenPending = false
    activateSpotlight()
  }

  /// Pre-arms routing while waiting for Spotlight's AX notification.
  func spotlightWillOpen() {
    spotlightDismissed = false
    spotlightOpenPending = true
    activateSpotlight()
  }

  /// Reconciles the observer's initial state with a pending or visible overlay.
  func spotlightObserverDidAttach(isVisible: Bool) {
    guard spotlightOpenPending || (isVisible && !spotlightDismissed) else { return }
    spotlightDismissed = false
    spotlightOpenPending = false
    activateSpotlight()
  }

  /// Clears stale restoration state when a normal application becomes active.
  func applicationDidActivate(_ bundleIdentifier: String) {
    if Self.isSpotlightBundle(inputProcessor.activeApp) {
      spotlightDismissed = true
    }
    spotlightOpenPending = false
    spotlightProcessBundleIdentifier = nil
    applicationBeforeSpotlight = nil
    inputProcessor.changeActiveApp(bundleIdentifier)
  }

  /// Switches the processor to Spotlight while remembering the host application.
  private func activateSpotlight() {
    guard !Self.isSpotlightBundle(inputProcessor.activeApp) else { return }

    let bundleIdentifier =
      spotlightProcessIdentifier
      .flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
      .flatMap { Self.isSpotlightBundle($0) ? $0 : nil }
      ?? spotlightProcessBundleIdentifier
      ?? Self.defaultSpotlightBundleIdentifier

    applicationBeforeSpotlight =
      inputProcessor.activeApp.isEmpty
      ? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
      : inputProcessor.activeApp
    spotlightProcessBundleIdentifier = bundleIdentifier
    inputProcessor.changeActiveApp(bundleIdentifier)
  }

  /// Restores the application that was active before the Spotlight overlay.
  func spotlightDidDismiss() {
    spotlightDismissed = true
    spotlightOpenPending = false

    guard Self.isSpotlightBundle(inputProcessor.activeApp) else {
      applicationBeforeSpotlight = nil
      return
    }

    let previousApplication = applicationBeforeSpotlight
    applicationBeforeSpotlight = nil

    guard
      let previousApplication,
      !previousApplication.isEmpty,
      !Self.isSpotlightBundle(previousApplication)
    else {
      return
    }

    spotlightProcessBundleIdentifier = nil
    inputProcessor.changeActiveApp(previousApplication)
  }

  /// Detects Command-Space before Spotlight emits its first AX focus notification.
  func shouldOpenSpotlight(type: CGEventType, event: CGEvent) -> Bool {
    guard type == .keyDown else { return false }
    guard !Self.isSpotlightBundle(inputProcessor.activeApp) else { return false }
    guard !spotlightOpenPending else { return false }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    return keyCode == 49 && event.flags.contains(.maskCommand)
  }

  /// Applies Spotlight open/dismiss transitions at the event-tap boundary.
  func prepareSpotlightLifecycle(type: CGEventType, event: CGEvent) -> Bool {
    if shouldOpenSpotlight(type: type, event: event) {
      spotlightWillOpen()
      return false
    }
    return shouldDismissSpotlight(type: type, event: event)
  }

  /// Detects keys and outside clicks that close the Spotlight overlay.
  func shouldDismissSpotlight(type: CGEventType, event: CGEvent) -> Bool {
    guard
      Self.isSpotlightBundle(inputProcessor.activeApp)
        || spotlightOpenPending
    else {
      return false
    }

    if type == .keyDown {
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      return keyCode == 53 || keyCode == 36 || keyCode == 52
        || (keyCode == 49 && event.flags.contains(.maskCommand))
    }

    if type == .leftMouseDown || type == .rightMouseDown {
      guard let spotlightProcessIdentifier else { return false }
      let targetProcessIdentifier = pid_t(
        event.getIntegerValueField(.eventTargetUnixProcessID)
      )
      return targetProcessIdentifier > 0
        && targetProcessIdentifier != spotlightProcessIdentifier
    }

    return false
  }

  private var spotlightIsVisible: Bool {
    guard let spotlightProcessIdentifier else { return false }
    return Focused.applicationHasOnScreenWindow(
      processIdentifier: spotlightProcessIdentifier
    )
  }

  private static func isSpotlightBundle(_ bundleIdentifier: String) -> Bool {
    spotlightBundleIdentifiers.contains(bundleIdentifier)
  }

  private static func runningSpotlightProcessIdentifier() -> pid_t? {
    for bundleIdentifier in spotlightBundleIdentifiers {
      if let processIdentifier =
        NSRunningApplication.runningApplications(
          withBundleIdentifier: bundleIdentifier
        ).first?.processIdentifier
      {
        return processIdentifier
      }
    }
    return nil
  }

  /// Attaches to the current Spotlight process, if it is already running.
  private func setupSpotlightObserver(processIdentifier: pid_t? = nil) {
    guard spotlightObserver == nil else { return }
    let resolvedProcessIdentifier =
      processIdentifier
      ?? Self.runningSpotlightProcessIdentifier()
    guard let resolvedProcessIdentifier else { return }

    spotlightObserverSetupGeneration += 1
    setupSpotlightObserver(
      processIdentifier: resolvedProcessIdentifier,
      attempt: 0,
      generation: spotlightObserverSetupGeneration
    )
  }

  /// Completes AX observer setup after Campo starts and accepts notifications.
  private func setupSpotlightObserver(
    processIdentifier: pid_t,
    attempt: Int,
    generation: Int
  ) {
    guard
      spotlightObserver == nil,
      generation == spotlightObserverSetupGeneration,
      let app = NSRunningApplication(processIdentifier: processIdentifier),
      !app.isTerminated,
      app.bundleIdentifier.map(Self.isSpotlightBundle) == true
    else {
      return
    }

    // Spotlight can reject AX observer setup briefly while its search process starts.
    let appElement = AXUIElementCreateApplication(processIdentifier)
    var observer: AXObserver?
    let createResult = AXObserverCreate(
      processIdentifier,
      spotlightObserverCallback,
      &observer
    )
    guard createResult == .success, let observer else {
      scheduleSpotlightObserverRetry(
        processIdentifier: processIdentifier,
        attempt: attempt,
        generation: generation
      )
      return
    }

    let addResult = AXObserverAddNotification(
      observer,
      appElement,
      kAXFocusedUIElementChangedNotification as CFString,
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
    guard addResult == .success else {
      scheduleSpotlightObserverRetry(
        processIdentifier: processIdentifier,
        attempt: attempt,
        generation: generation
      )
      return
    }

    let windowCreatedResult = AXObserverAddNotification(
      observer,
      appElement,
      kAXWindowCreatedNotification as CFString,
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
    guard windowCreatedResult == .success else {
      scheduleSpotlightObserverRetry(
        processIdentifier: processIdentifier,
        attempt: attempt,
        generation: generation
      )
      return
    }

    CFRunLoopAddSource(
      CFRunLoopGetCurrent(),
      AXObserverGetRunLoopSource(observer),
      .commonModes
    )
    spotlightObserver = observer
    spotlightElement = appElement
    spotlightProcessIdentifier = processIdentifier
    spotlightProcessBundleIdentifier = app.bundleIdentifier
    spotlightObserverDidAttach(
      isVisible: Focused.applicationHasOnScreenWindow(
        processIdentifier: processIdentifier
      )
    )
  }

  /// Retries observer setup during the short Spotlight process-start race.
  private func scheduleSpotlightObserverRetry(
    processIdentifier: pid_t,
    attempt: Int,
    generation: Int
  ) {
    let nextAttempt = attempt + 1
    guard nextAttempt < Self.spotlightObserverMaxSetupAttempts else { return }

    DispatchQueue.main.asyncAfter(
      deadline: .now() + Self.spotlightObserverRetryDelay
    ) { [weak self] in
      self?.setupSpotlightObserver(
        processIdentifier: processIdentifier,
        attempt: nextAttempt,
        generation: generation
      )
    }
  }

  /// Removes the observer source and invalidates queued setup retries.
  private func teardownSpotlightObserver() {
    spotlightObserverSetupGeneration += 1
    if let spotlightObserver {
      CFRunLoopRemoveSource(
        CFRunLoopGetCurrent(),
        AXObserverGetRunLoopSource(spotlightObserver),
        .commonModes
      )
    }

    spotlightObserver = nil
    spotlightElement = nil
    spotlightProcessIdentifier = nil
  }

  /// Tracks Spotlight launch/termination so its AX observer follows the process.
  private func startSpotlightProcessMonitoring() {
    guard spotlightProcessObserverTokens.isEmpty else { return }

    let notificationCenter = NSWorkspace.shared.notificationCenter
    let launchToken = notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let app =
          notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        app.bundleIdentifier.map(Self.isSpotlightBundle) == true
      else {
        return
      }

      self.setupSpotlightObserver(processIdentifier: app.processIdentifier)
    }

    let terminationToken = notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let app =
          notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        app.bundleIdentifier.map(Self.isSpotlightBundle) == true
      else {
        return
      }

      self.spotlightDidDismiss()
      self.teardownSpotlightObserver()
    }

    spotlightProcessObserverTokens = [launchToken, terminationToken]
  }

  /// Removes workspace notifications before the event hook is destroyed.
  private func stopSpotlightProcessMonitoring() {
    let notificationCenter = NSWorkspace.shared.notificationCenter
    for token in spotlightProcessObserverTokens {
      notificationCenter.removeObserver(token)
    }
    spotlightProcessObserverTokens = []
  }

  // Removes the event tap and Spotlight observers on termination or TCC revoke.
  func destroy() {
    if Self.isSpotlightBundle(inputProcessor.activeApp) {
      spotlightDidDismiss()
    }

    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      unregisterEventTap(eventTap)
      CFMachPortInvalidate(eventTap)
      self.eventTap = nil
    }

    stopSpotlightProcessMonitoring()
    teardownSpotlightObserver()
    eventTapRunLoopSource = nil
    spotlightDismissed = false
    spotlightProcessBundleIdentifier = nil
    applicationBeforeSpotlight = nil
    spotlightOpenPending = false
  }

  // Sets up the event tap and the Spotlight lifecycle observers.
  func setupEventTap(give appState: AppState) {
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

    guard
      let runLoopSource = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault,
        eventTap,
        0
      )
    else {
      CFMachPortInvalidate(eventTap)
      return
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

    CGEvent.tapEnable(tap: eventTap, enable: true)
    self.eventTap = eventTap
    self.eventTapRunLoopSource = runLoopSource
    self.appState = appState

    startSpotlightProcessMonitoring()
    setupSpotlightObserver()
  }

  // Unregisters the event tap from the run loop.
  func unregisterEventTap(_ eventTap: CFMachPort) {
    if let runLoopSource = eventTapRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      eventTapRunLoopSource = nil
    }
  }
}

// Callback function for the event tap and Spotlight lifecycle transitions.
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passRetained(event) }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()

  // Auto-recover when macOS disables the event tap
  // This happens when the tap callback takes too long or the system is under load
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if !AXIsProcessTrusted() {
      // TCC transition handling owns teardown; do not re-enable a revoked tap.
      return Unmanaged.passRetained(event)
    }

    if let eventTap = eventHook.eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: true)
      eventHook.tapRecoveryCount += 1
      #if DEBUG
      print("[Caffee] Event tap was disabled by system (\(type == .tapDisabledByTimeout ? "timeout" : "user input")), auto-recovered (count: \(eventHook.tapRecoveryCount))")
      #endif
    }
    return Unmanaged.passRetained(event)
  }

  // Ignore keystrokes not from hardware (HID system state).
  if event.getIntegerValueField(.eventSourceStateID) != 1 {
    return Unmanaged.passRetained(event)
  }

  let shouldDismissSpotlight = eventHook.prepareSpotlightLifecycle(type: type, event: event)

  // IME Switcher button on keyboard
  //    if let appState = eventHook.appState,
  //      type == .flagsChanged && (event.flags.contains(.maskSecondaryFn))  // Left Fn
  //    {
  //      appState.setEnabled(set: !appState.enabled)
  //      return nil
  //    }

  let input = eventHook.inputProcessor
  // Keep the closing event flowing, then restore host-app routing afterward.

  // Check for secure input mode (password fields)
  let isSecureInput = CGSIsSecureEventInputSet()
  if let appState = eventHook.appState, appState.secureInputActive != isSecureInput {
    DispatchQueue.main.async {
      appState.secureInputActive = isSecureInput
    }
  }

  if type == .keyDown && eventHook.processing {
    // Skip IME processing when secure input is active (password fields)
    if isSecureInput {
      if shouldDismissSpotlight {
        eventHook.spotlightDidDismiss()
      }
      return Unmanaged.passRetained(event)
    }

    // Benchmark
    //    let start = CFAbsoluteTimeGetCurrent()
    let ret = input.handleEvent(event: event)
    //    let diff = CFAbsoluteTimeGetCurrent() - start
    //    print("Processed handler in \(diff * 1000) ms")

    if shouldDismissSpotlight {
      eventHook.spotlightDidDismiss()
    }
    return ret
  } else if type == .leftMouseDown || type == .rightMouseDown {
    input.newWord()
  }

  if shouldDismissSpotlight {
    eventHook.spotlightDidDismiss()
  }
  return Unmanaged.passRetained(event)
}

/// Bridges C AX notifications back to the owning EventHook instance.
func spotlightObserverCallback(
  observer: AXObserver,
  element: AXUIElement,
  notification: CFString,
  refcon: UnsafeMutableRawPointer?
) {
  guard let refcon else { return }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()
  if notification as String == kAXWindowCreatedNotification {
    eventHook.spotlightWindowCreated()
  } else {
    eventHook.spotlightFocusedUIElementDidChange()
  }
}
