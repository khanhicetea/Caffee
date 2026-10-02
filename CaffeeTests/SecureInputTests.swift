//
//  SecureInputTests.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

@MainActor
final class SecureInputTests: XCTestCase {

  func testRapidSecureInputChangesPublishTheLatestStateSynchronously() {
    var secureInput = false
    let state = AppState()
    let hook = EventHook(
      inputProcessor: state.inputProcessor, secureInputChecker: { secureInput })
    hook.appState = state

    secureInput = true
    XCTAssertTrue(hook.refreshSecureInputState())
    XCTAssertTrue(state.secureInputActive)

    secureInput = false
    XCTAssertFalse(hook.refreshSecureInputState())
    XCTAssertFalse(state.secureInputActive)

    // Drain the queue: an older asynchronous true update must not re-lock the UI.
    let drained = expectation(description: "Main queue drained")
    DispatchQueue.main.async {
      XCTAssertFalse(state.secureInputActive)
      drained.fulfill()
    }
    wait(for: [drained], timeout: 2)
  }

  func testMonitorDetectsSecureInputReleaseWithoutKeyboardEvents() {
    var secureInput = true
    let processor = InputProcessor(method: .telex)
    let hook = EventHook(inputProcessor: processor, secureInputChecker: { secureInput })
    defer { hook.destroy() }

    processor.push(char: "a")
    hook.startSecureInputMonitoring()
    XCTAssertTrue(hook.secureInputActive)  // Also sample a lock held before startup.
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)

    secureInput = false
    let released = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in !hook.secureInputActive }, object: nil)
    wait(for: [released], timeout: 3)
    XCTAssertFalse(hook.secureInputActive)
  }

  func testSecureInputTransitionsClearWordAndPreviousWord() {
    var secureInput = false
    let processor = InputProcessor(method: .telex)
    let hook = EventHook(inputProcessor: processor, secureInputChecker: { secureInput })

    processor.push(char: "a")
    processor.newWord(storePrevious: true)
    processor.push(char: "b")
    secureInput = true
    hook.refreshSecureInputState()
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
    XCTAssertNil(processor.wordBuffer.previousWordState)

    processor.push(char: "c")
    secureInput = false
    hook.refreshSecureInputState()
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
    XCTAssertEqual(processor.wordBuffer.transformed, "")
  }

  func testUnchangedSecureInputSamplePreservesCurrentWord() {
    let processor = InputProcessor(method: .telex)
    let hook = EventHook(inputProcessor: processor, secureInputChecker: { false })

    processor.push(char: "a")
    hook.refreshSecureInputState()
    hook.refreshSecureInputState()
    XCTAssertEqual(processor.wordBuffer.keys, ["a"])
    XCTAssertEqual(processor.wordBuffer.transformed, "a")
  }

  func testKeyboardGateUsesFreshSecureInputAndResumesAfterRelease() throws {
    var secureInput = false
    let sender = MockReplacementSender()
    let processor = InputProcessor(
      method: .telex,
      replacementSender: sender,
      selectionDetector: MockSelectionDetector(hasSelection: false)
    )
    let hook = EventHook(inputProcessor: processor, secureInputChecker: { secureInput })
    hook.setEnabled(true)
    hook.refreshSecureInputState()

    // Secure Input changed after the timer's last sample. Do not process this key.
    secureInput = true
    let protectedResult = hook.handleEvent(type: .keyDown, event: try hardwareKey(0))
    XCTAssertNotNil(protectedResult)
    _ = protectedResult?.takeUnretainedValue()
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
    XCTAssertTrue(sender.replacementCalls.isEmpty)
    XCTAssertTrue(hook.processing)  // The user's enabled preference stays unchanged.

    // Release the global lock without an intervening timer tick or app restart.
    secureInput = false
    _ = hook.handleEvent(type: .keyDown, event: try hardwareKey(0))?.takeUnretainedValue()
    XCTAssertNil(hook.handleEvent(type: .keyDown, event: try hardwareKey(1)))
    XCTAssertEqual(processor.wordBuffer.transformed, "á")
    XCTAssertEqual(sender.replacementCalls.count, 1)
  }

  func testSyntheticKeysDoNotEnterTheProcessor() throws {
    let processor = InputProcessor(method: .telex)
    let hook = EventHook(inputProcessor: processor, secureInputChecker: { false })
    hook.setEnabled(true)
    let event = try hardwareKey(0)
    KeyEventPoster.tag(event)

    let result = hook.handleEvent(type: .keyDown, event: event)
    XCTAssertNotNil(result)
    _ = result?.takeUnretainedValue()
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
  }

  func testDestroyStopsSecureInputMonitoring() {
    var samples = 0
    let hook = EventHook(
      inputProcessor: InputProcessor(method: .telex),
      secureInputChecker: {
        samples += 1
        return true
      })
    hook.startSecureInputMonitoring()
    XCTAssertEqual(samples, 1)
    hook.destroy()
    XCTAssertFalse(hook.secureInputActive)

    let elapsed = expectation(description: "Timer interval elapsed")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { elapsed.fulfill() }
    wait(for: [elapsed], timeout: 2)
    XCTAssertEqual(samples, 1)
  }
}
