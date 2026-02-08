//
//  InputProcessor.swift
//  Caffee
//
//  Created by KhanhIceTea on 24/02/2024.
//

import AppKit
import CoreGraphics
import Defaults
import Foundation

class InputProcessor {
  static let FixAutocompleteApps = [
    "com.apple.Safari", "com.google.Chrome", "org.chromium.Chromium",
    "org.mozilla.firefox", "org.mozilla.nightly", "com.electron.min", "com.brave.Browser",
    "company.thebrowser.Browser", "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
    "com.microsoft.edge", "com.microsoft.Edge", "com.microsoft.Excel", "com.microsoft.Office.Excel",
  ]
  static let NewWordKeys = "`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?"
  static let NewWordTaskKeys: [TaskKey] = [.Enter, .Space, .Tab]
  static let JumpTaskKeys: [TaskKey] = [.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight]



  public var engine: TypingMethod
  public var typingMethod: TypingMethods

  public var keyLayout = KeyboardUS()
  public var keys: [Character] = []
  public var stopProcessing = false
  public var lastTransformed = ""
  public var transformed = ""

  public var activeApp = ""
  public var previousWordState: TiengVietState?
  public var wordState = TiengVietState.empty

  /// Track pasteboard change count to detect external paste operations
  private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount

  /// Current sending strategy for the active app
  private var currentStrategy: SendingStrategy = .batch

  /// Track consecutive transformation failures for auto-switching
  private var consecutiveFailures = 0

  /// Maximum failures before auto-switching to step-by-step mode
  private let maxFailuresBeforeSwitch = 3

  /// Track last transformation for failure detection
  private var lastInputChar: Character?
  private var expectedOutput: String?

  init(method: TypingMethods) {
    typingMethod = method
    engine = typingMethod == .Telex ? Telex() : VNI()
  }

  public func changeTypingMethod(newMethod: TypingMethods) {
    typingMethod = newMethod
    engine = typingMethod == .Telex ? Telex() : VNI()
    newWord()
  }

  public func changeActiveApp(_ app: String) {
    activeApp = app
    // Reset strategy to default for the new app
    currentStrategy = EventSimulator.getStrategy(for: app)
    consecutiveFailures = 0
    lastInputChar = nil
    expectedOutput = nil
  }

  /// Detects if a transformation likely failed based on input/output tracking.
  /// Returns true if the transformation appears to have failed.
  func detectTransformationFailure(input: Character, expectedOutput: String, actualContext: String?) -> Bool {
    // Basic heuristic: if we've been seeing the same input multiple times
    // or the output doesn't match what we expect, it might be failing
    if let last = lastInputChar, last == input {
      consecutiveFailures += 1
    } else {
      consecutiveFailures = 1
    }
    lastInputChar = input

    // If we have too many consecutive similar failures, switch strategy
    if consecutiveFailures >= maxFailuresBeforeSwitch {
      return true
    }

    return false
  }

  /// Auto-switches to step-by-step mode if failures are detected.
  func autoSwitchStrategyIfNeeded() {
    // Check if auto-switch is enabled in settings
    guard Defaults[.autoSwitchStrategy] else {
      return
    }

    // Don't auto-switch if already using specialized strategies
    switch currentStrategy {
    case .stepByStep:
      return  // Already using a specialized strategy
    default:
      break
    }

    // Switch to step-by-step for this session
    let oldStrategy = currentStrategy
    currentStrategy = .stepByStep
    consecutiveFailures = 0

    #if DEBUG
    let appName = EventSimulator.getAppName(for: activeApp)
    print("[Caffee] Auto-switched from \(oldStrategy) to step-by-step mode for \(appName) due to failures")
    #endif
  }

  /// Gets the current sending strategy, considering auto-switching for failures.
  func getCurrentStrategy() -> SendingStrategy {
    return currentStrategy
  }

  public func newWord(storePrevious: Bool = false) {
    previousWordState = nil
    if !wordState.isBlank {
      if storePrevious {
        previousWordState = wordState
      }
      wordState = .empty
    }

    keys = []
    stopProcessing = false
    lastTransformed = ""
    transformed = ""
  }

  public func pop() {
    if wordState.isBlank, let prev = previousWordState {
      wordState = prev
      previousWordState = nil
      keys = Array(wordState.chuKhongDau)
      transformed = wordState.transformed
      lastTransformed = transformed
    } else {
      wordState = engine.pop(state: wordState)
      keys = Array(wordState.chuKhongDau)
      transformed = String(transformed.dropLast(1))
    }
  }

  public func push(char: Character) {
    keys.append(char)

    lastTransformed = transformed
    let result = engine.push(char: char, state: wordState)
    wordState = result.state

    // Check if we need to recover original input (invalid Vietnamese syllable)
    if wordState.needsRecovery {
      stopProcessing = true
      // Use keys array which contains ALL typed characters (including tone marks like 's', 'f' etc.)
      transformed = String(keys)
    } else {
      transformed = wordState.transformed
    }

    if engine.shouldStopProcessing(keyStr: String(keys)) {
      stopProcessing = true
      if transformed.count == lastTransformed.count {
        transformed.append(char)
      }
    }
  }

  // Main input handler
  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    // For number keys (used by VNI), only consider actual Shift key, not Capslock
    // For letter keys, consider both Shift and Capslock
    let shifted = flags.contains(.maskShift) || (!keyLayout.isNumberKey(keyCode: keyCode) && flags.contains(.maskAlphaShift))

    // Handle modifier keys (Cmd, Ctrl, Alt) - clear word buffer
    // This also handles Cmd+V (paste) by clearing BEFORE paste content arrives
    if flags.contains(.maskCommand) || flags.contains(.maskControl)
      || flags.contains(.maskAlternate)
    {
      newWord()
      return Unmanaged.passRetained(event)
    }

    // Detect if a paste operation occurred (pasteboard changed externally)
    // This catches paste via menu, right-click, or other non-keyboard methods
    let currentPasteboardCount = NSPasteboard.general.changeCount
    if currentPasteboardCount != lastPasteboardChangeCount {
      lastPasteboardChangeCount = currentPasteboardCount
      newWord()
    }

    if let taskKey = keyLayout.mapTask(keyCode: keyCode) {
      if InputProcessor.NewWordTaskKeys.contains(taskKey) {
        newWord(storePrevious: true)
      } else if taskKey == .Delete {
        pop()
      } else if InputProcessor.JumpTaskKeys.contains(taskKey) {
        newWord()
      }
    } else if stopProcessing {
      return Unmanaged.passRetained(event)
    } else if let newChar = keyLayout.mapText(keyCode: keyCode, withShift: shifted) {
      // Check if this is a word-ending character (punctuation, etc.) BEFORE processing
      // This prevents punctuation from triggering recovery on valid Vietnamese words
      // e.g., "xuất." should remain "xuất." not become "xuaats."
      if let _ = InputProcessor.NewWordKeys.firstIndex(of: newChar) {
        newWord(storePrevious: true)
        return Unmanaged.passRetained(event)  // Let punctuation pass through as-is
      }

      push(char: newChar)
      var (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed)

      if let firstDiffChar = diffChars.first, diffChars.count == 1 && firstDiffChar == newChar {
        return Unmanaged.passRetained(event)
      } else {
        if needToFixAutocomplete() {
          numBackspaces += 1
        }

        // Check for transformation failures and auto-switch if needed
        if detectTransformationFailure(input: newChar, expectedOutput: transformed, actualContext: nil) {
          autoSwitchStrategyIfNeeded()
        }

        // Use strategy-based sending
        let strategy = getCurrentStrategy()
        EventSimulator.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategy
        )
        return nil
      }
    }

    return Unmanaged.passRetained(event)
  }

  func needToFixAutocomplete() -> Bool {
    let idx = InputProcessor.FixAutocompleteApps.first { app in
      return activeApp.hasPrefix(app)
    }
    return idx != nil && Focused.hasHighlightedText()
  }

}
