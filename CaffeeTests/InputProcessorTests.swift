//
//  InputProcessorTests.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

@MainActor
final class InputProcessorTests: XCTestCase {

  func testRealKeysQueueBehindPendingSyntheticOutput() throws {
    var busy = true
    var reposted: [Int64] = []
    let processor = InputProcessor(
      method: .telex,
      replacementSender: MockReplacementSender(),
      selectionDetector: MockSelectionDetector(hasSelection: false)
    )
    let hook = EventHook(
      inputProcessor: processor,
      secureInputChecker: { false },
      isOutputBusy: { busy },
      repostEvent: { reposted.append($0.getIntegerValueField(.keyboardEventKeycode)) }
    )
    hook.setEnabled(true)

    // While a replacement is still being typed out, a plain letter must be swallowed and
    // re-posted behind it rather than overtaking it.
    XCTAssertNil(hook.handleEvent(type: .keyDown, event: try hardwareKey(0)))
    XCTAssertEqual(reposted, [0])

    // Once the queue is empty, keys pass straight through again.
    busy = false
    let direct = hook.handleEvent(type: .keyDown, event: try hardwareKey(11))
    XCTAssertNotNil(direct)
    XCTAssertEqual(reposted, [0])
  }

  func testSyntheticEventTagIsRecognised() throws {
    let event = try hardwareKey(0)
    XCTAssertFalse(KeyEventPoster.isSynthetic(event))
    KeyEventPoster.tag(event)
    XCTAssertTrue(KeyEventPoster.isSynthetic(event))
  }

  func testUnicodeChunksNeverExceedLimitAndKeepCharacters() {
    let text = String(repeating: "ế", count: 45)
    let chunks = KeyEventPoster.unicodeChunks(of: text, limit: 20)
    XCTAssertEqual(chunks.map(\.count), [20, 20, 5])
    XCTAssertEqual(String(utf16CodeUnits: chunks.flatMap { $0 }, count: 45), text)
  }

  func testNonTextKeysResetTheCurrentWord() {
    for code: Int64 in [53 /* Esc */, 116 /* PgUp */, 117 /* Fwd Delete */, 122 /* F1 */] {
      let processor = InputProcessor(
        method: .telex,
        replacementSender: MockReplacementSender(),
        selectionDetector: MockSelectionDetector(hasSelection: false)
      )
      processor.push(char: "v")
      processor.push(char: "i")
      XCTAssertEqual(processor.handleInputEvent(.keyCode(code)), .passThrough)
      XCTAssertTrue(processor.wordBuffer.keys.isEmpty, "key \(code) should reset the word")
    }
  }

  func testSystemResolvedCharacterOverridesUSKeyMap() {
    let sender = MockReplacementSender()
    let processor = InputProcessor(
      method: .telex,
      replacementSender: sender,
      selectionDetector: MockSelectionDetector(hasSelection: false)
    )
    // Dvorak: the physical "S" key (code 1) types "o".
    var event = KeyboardInputEvent.keyCode(1)
    event.character = "o"
    event.resolvedFromSystem = true
    _ = processor.handleInputEvent(event)
    XCTAssertEqual(processor.wordBuffer.keys, ["o"])

    // A non-Latin layout produces no ASCII character: never guess one from the US map.
    var cyrillic = KeyboardInputEvent.keyCode(0)
    cyrillic.resolvedFromSystem = true
    XCTAssertEqual(processor.handleInputEvent(cyrillic), .passThrough)
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
  }

  func testInputProcessorRecoveryRollback() throws {
    let inputProcessor = InputProcessor(method: .telex)

    // Type "hồ" (hoof)
    inputProcessor.push(char: "h")
    inputProcessor.push(char: "o")
    inputProcessor.push(char: "o")
    inputProcessor.push(char: "f")
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "hồ")
    XCTAssertFalse(inputProcessor.wordBuffer.stopProcessing)

    // Type "z" -> triggers recovery
    inputProcessor.push(char: "z")
    XCTAssertTrue(inputProcessor.wordBuffer.stopProcessing)
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "hoofz")

    // Backspace
    let replacement = inputProcessor.pop()
    let numBackspaces = replacement.deleteCount
    let diffChars = replacement.insert

    // "hoofz" and "hồ" share "h"
    // "hoofz" is ["h", "o", "o", "f", "z"] (5 chars)
    // "hồ" is ["h", "ồ"] (2 chars)
    // Common prefix "h" (1 char)
    // Backspaces: 5 - 1 = 4
    XCTAssertEqual(numBackspaces, 4, "numBackspaces should be 4")
    XCTAssertEqual(String(diffChars), "ồ", "diffChars should be ồ")
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "hồ", "transformed should be hồ")
    XCTAssertFalse(inputProcessor.wordBuffer.stopProcessing, "stopProcessing should be false")
  }

  func testMouseDownAndFlagsChangedQueueBehindPendingOutput() throws {
    var busy = true
    var repostedTypes: [CGEventType] = []
    let processor = InputProcessor(
      method: .telex,
      replacementSender: MockReplacementSender(),
      selectionDetector: MockSelectionDetector(hasSelection: false)
    )
    let hook = EventHook(
      inputProcessor: processor,
      secureInputChecker: { false },
      isOutputBusy: { busy },
      repostEvent: { repostedTypes.append($0.type) }
    )
    hook.setEnabled(true)
    processor.push(char: "a")

    let mouseDown = try XCTUnwrap(
      CGEvent(
        mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero,
        mouseButton: .left))
    let flagsChanged = try XCTUnwrap(CGEvent(source: nil))
    flagsChanged.type = .flagsChanged

    XCTAssertNil(hook.handleEvent(type: .leftMouseDown, event: mouseDown))
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
    XCTAssertNil(hook.handleEvent(type: .flagsChanged, event: flagsChanged))
    XCTAssertEqual(repostedTypes, [.leftMouseDown, .flagsChanged])

    busy = false
    XCTAssertNotNil(hook.handleEvent(type: .leftMouseDown, event: mouseDown))
    XCTAssertNotNil(hook.handleEvent(type: .flagsChanged, event: flagsChanged))
    withExtendedLifetime((mouseDown, flagsChanged)) {}
  }

  func testEmptyReplacementShortCircuitsWithoutSelectionCheckOrSend() {
    final class CountingSelectionDetector: SelectionDetector {
      var calls = 0
      func hasHighlightedText() -> Bool {
        calls += 1
        return true
      }
      func invalidateCache() {}
    }

    let sender = MockReplacementSender()
    let detector = CountingSelectionDetector()
    let processor = InputProcessor(
      method: .telex,
      replacementSender: sender,
      selectionDetector: detector
    )
    // Chrome enables fixesAutocomplete; typing "tuwow" produces an empty replacement on the 2nd "w".
    processor.changeActiveApp("com.google.Chrome")
    for ch in Array("tuwo") {
      var ev = KeyboardInputEvent.keyCode(0)
      ev.resolvedFromSystem = true
      ev.character = ch
      _ = processor.handleInputEvent(ev)
    }
    let callsBefore = detector.calls
    let sendsBefore = sender.replacementCalls.count + sender.selectAndReplaceCalls.count

    var secondW = KeyboardInputEvent.keyCode(13)
    secondW.resolvedFromSystem = true
    secondW.character = "w"
    XCTAssertEqual(processor.handleInputEvent(secondW), .handled)
    XCTAssertEqual(processor.wordBuffer.transformed, "tươ")
    XCTAssertEqual(detector.calls, callsBefore)
    XCTAssertEqual(sender.replacementCalls.count + sender.selectAndReplaceCalls.count, sendsBefore)
  }

  func testDeadKeyCGEventDoesNotFallBackToUSMap() throws {
    let processor = InputProcessor(
      method: .telex,
      replacementSender: MockReplacementSender(),
      selectionDetector: MockSelectionDetector(hasSelection: false)
    )
    processor.push(char: "a")

    // Simulate a dead key: keyCode 0 ("a" on US layout) with 0-length Unicode string from the system.
    let deadKey = try XCTUnwrap(CGEvent(source: nil))
    deadKey.type = .keyDown
    deadKey.setIntegerValueField(.keyboardEventKeycode, value: 0)

    let inputEvent = KeyboardInputEvent(event: deadKey, keyboardLayout: KeyboardUS())
    XCTAssertTrue(inputEvent.resolvedFromSystem)
    XCTAssertNil(inputEvent.character)

    XCTAssertEqual(processor.handleInputEvent(inputEvent), .passThrough)
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
    withExtendedLifetime(deadKey) {}
  }

  func testChangeActiveAppResetsWordBuffer() {
    let processor = InputProcessor(method: .telex)
    processor.push(char: "v")
    processor.push(char: "i")
    processor.changeActiveApp("com.apple.Notes")
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
  }
}
