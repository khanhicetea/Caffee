//
//  TestSupport.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

/// The event tap callback returns the system-owned event unretained, so tests must keep every
/// event they feed to `EventHook` alive for as long as they inspect the returned value.
@MainActor private var retainedTestEvents: [CGEvent] = []

@MainActor func hardwareKey(_ keyCode: CGKeyCode) throws -> CGEvent {
  let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true))
  event.setIntegerValueField(.eventSourceStateID, value: 1)
  retainedTestEvents.append(event)
  return event
}

/// Base class with helpers that type whole words through an `InputProcessor`.
class EngineTestCase: XCTestCase {

  public func transform_text_telex(for text: String) -> String {
    var p_ret: [String] = []
    let inputProcessor = InputProcessor(method: .telex)

    for word in text.split(separator: " ") {
      inputProcessor.newWord()
      for c in word {
        inputProcessor.push(char: c)
      }
      p_ret.append(inputProcessor.wordBuffer.transformed)
    }

    return p_ret.joined(separator: " ")
  }

  public func transform_text_vni(for text: String) -> String {
    var p_ret: [String] = []
    let inputProcessor = InputProcessor(method: .vni)

    for word in text.split(separator: " ") {
      inputProcessor.newWord()
      for c in word {
        inputProcessor.push(char: c)
      }
      p_ret.append(inputProcessor.wordBuffer.transformed)
    }

    return p_ret.joined(separator: " ")
  }
}

final class MockReplacementSender: ReplacementSender {
  struct Call: Equatable {
    let backspaceCount: Int
    let diffChars: [Character]
    let strategy: SendingStrategy
  }

  var replacementCalls: [Call] = []
  var selectAndReplaceCalls: [Call] = []

  func sendReplacement(_ replacement: Replacement, strategy: SendingStrategy) {
    replacementCalls.append(
      Call(
        backspaceCount: replacement.deleteCount, diffChars: replacement.insert,
        strategy: strategy))
  }

  func sendSelectAndReplace(_ replacement: Replacement, strategy: SendingStrategy) {
    selectAndReplaceCalls.append(
      Call(
        backspaceCount: replacement.deleteCount, diffChars: replacement.insert,
        strategy: strategy))
  }
}

final class MockSelectionDetector: SelectionDetector {
  private let hasSelection: Bool

  init(hasSelection: Bool) {
    self.hasSelection = hasSelection
  }

  func hasHighlightedText() -> Bool {
    hasSelection
  }

  func invalidateCache() {}
}

extension KeyboardInputEvent {
  static func keyCode(
    _ keyCode: Int64,
    shifted: Bool = false,
    commandPressed: Bool = false,
    controlPressed: Bool = false,
    optionPressed: Bool = false
  ) -> KeyboardInputEvent {
    KeyboardInputEvent(
      keyCode: keyCode,
      shifted: shifted,
      commandPressed: commandPressed,
      controlPressed: controlPressed,
      optionPressed: optionPressed
    )
  }
}
