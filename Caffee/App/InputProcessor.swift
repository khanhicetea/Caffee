//
//  InputProcessor.swift
//  Caffee
//
//  Created by KhanhIceTea on 24/02/2024.
//

import CoreGraphics
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

    if flags.contains(.maskCommand) || flags.contains(.maskControl)
      || flags.contains(.maskAlternate)
    {
      newWord()
    } else if let taskKey = keyLayout.mapTask(keyCode: keyCode) {
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
      push(char: newChar)
      var (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed)

      if let _ = InputProcessor.NewWordKeys.firstIndex(of: newChar) {
        newWord()
      }

      if let firstDiffChar = diffChars.first, diffChars.count == 1 && firstDiffChar == newChar {
        return Unmanaged.passRetained(event)
      } else {
        if needToFixAutocomplete() {
          numBackspaces += 1
        }
        EventSimulator.sendBackspace(numBackspaces)
        EventSimulator.sendString(String(diffChars))
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
