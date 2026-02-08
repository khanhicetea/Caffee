import ApplicationServices
import Cocoa
import Foundation

// Private macOS API to detect secure input mode (password fields)
@_silgen_name("CGSIsSecureEventInputSet")
func CGSIsSecureEventInputSet() -> Bool

// EventHook manages keyboard events and interacts with the Telex engine.
class EventHook {

  var eventTap: CFMachPort?
  var keyLayout: KeyboardUS
  var inputProcessor: InputProcessor
  var processing = false
  var appState: AppState?

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

  // Removes the event tap before the application terminates.
  func destroy() {
    if let eventTap = eventTap {
      CFMachPortInvalidate(eventTap)
      unregisterEventTap(eventTap)
    }
  }

  // Sets up the event tap to listen for keyboard and mouse events.
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

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    self.eventTap = eventTap
    self.appState = appState
  }

  // Unregisters the event tap from the run loop.
  func unregisterEventTap(_ eventTap: CFMachPort) {
    if let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    }
  }
}

// Callback function for the event tap.
func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passRetained(event) }
  let eventHook = Unmanaged<EventHook>.fromOpaque(refcon).takeUnretainedValue()

  // Ignore keystrokes not from hardware (HID system state).
  if event.getIntegerValueField(.eventSourceStateID) != 1 {
    return Unmanaged.passRetained(event)
  }

  // IME Switcher button on keyboard
  //    if let appState = eventHook.appState,
  //      type == .flagsChanged && (event.flags.contains(.maskSecondaryFn))  // Left Fn
  //    {
  //      appState.setEnabled(set: !appState.enabled)
  //      return nil
  //    }

  let input = eventHook.inputProcessor

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
      return Unmanaged.passRetained(event)
    }

    // Benchmark
    //    let start = CFAbsoluteTimeGetCurrent()
    let ret = input.handleEvent(event: event)
    //    let diff = CFAbsoluteTimeGetCurrent() - start
    //    print("Processed handler in \(diff * 1000) ms")

    return ret
  } else if type == .leftMouseDown || type == .rightMouseDown {
    input.newWord()
  }

  return Unmanaged.passRetained(event)
}
