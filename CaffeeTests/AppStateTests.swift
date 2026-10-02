//
//  AppStateTests.swift
//  CaffeeTests
//

import Defaults
import XCTest

@testable import Caffee

@MainActor
final class AppStateTests: XCTestCase {

  func testModeChangeCallbackFiresOnlyForRealChanges() {
    let state = AppState()
    var changes: [(Bool, AppState.ModeChangeReason)] = []
    state.onModeChange = { changes.append(($0, $1)) }

    state.setEnabled(set: true, reason: .hotkey)
    state.setEnabled(set: true, reason: .hotkey)  // no change: no HUD
    state.setEnabled(set: false, reason: .automation)

    XCTAssertEqual(changes.count, 2)
    XCTAssertEqual(changes[0].0, true)
    XCTAssertEqual(changes[0].1, .hotkey)
    XCTAssertEqual(changes[1].0, false)
    XCTAssertEqual(changes[1].1, .automation)
  }

  func testCommandsDriveTheMode() {
    let state = AppState()
    state.apply(.setVietnamese(true))
    XCTAssertTrue(state.enabled)
    state.apply(.toggle)
    XCTAssertFalse(state.enabled)
    state.apply(.toggle)
    XCTAssertTrue(state.enabled)
  }

  func testMethodCommandSwitchesTheEngine() {
    let original = Defaults[.typingMethod]
    defer { Defaults[.typingMethod] = original }

    let state = AppState()
    state.apply(.setMethod(.vni))
    XCTAssertEqual(state.typingMethod, .vni)
    XCTAssertEqual(state.inputProcessor.typingMethod, .vni)
    state.apply(.setMethod(.telex))
    XCTAssertEqual(state.inputProcessor.typingMethod, .telex)
  }

  func testEngineOptionsReachTheInputProcessor() {
    let originals = (Defaults[.allowedZWJF], Defaults[.tonePlacement], Defaults[.spellingCheck])
    defer {
      Defaults[.allowedZWJF] = originals.0
      Defaults[.tonePlacement] = originals.1
      Defaults[.spellingCheck] = originals.2
    }

    let state = AppState()
    state.allowedZWJF = true
    state.tonePlacement = .secondVowel
    state.spellingCheck = false
    XCTAssertEqual(
      state.inputProcessor.wordBuffer.config,
      EngineConfig(
        allowForeignConsonants: true, tonePlacement: .secondVowel, spellingCheck: false))
  }
}
