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

  func testAppSwitchDoesNotPolluteKnownAppsOrOverwritePinnedRememberedMode() {
    let originalModes = Defaults[.appModes]
    let originalPrefs = Defaults[.appModePreferences]
    let originalStrategies = Defaults[.appStrategyOverrides]
    defer {
      Defaults[.appModes] = originalModes
      Defaults[.appModePreferences] = originalPrefs
      Defaults[.appStrategyOverrides] = originalStrategies
    }

    Defaults[.appModes] = [:]
    Defaults[.appModePreferences] = [:]
    Defaults[.appStrategyOverrides] = [:]

    let state = AppState()
    state.setEnabled(set: true, reason: .menu)

    // Switching to an unseen app must not add it to knownApps.
    state.activeAppName = "com.example.unseen"
    state.applyPerAppSettings()
    XCTAssertFalse(state.store.knownApps.contains("com.example.unseen"))
    XCTAssertTrue(state.enabled)

    // Explicitly toggling in a .remember app persists the choice.
    state.setEnabled(set: false, reason: .hotkey)
    XCTAssertEqual(state.store.remembered["com.example.unseen"], false)

    // Pinning an app that already has a remembered mode must not erase its remembered value on switch.
    state.activeAppName = "com.example.pinned"
    state.applyPerAppSettings()
    state.setEnabled(set: true, reason: .hotkey)
    XCTAssertEqual(state.store.remembered["com.example.pinned"], true)

    state.setPreference(.alwaysEnglish, for: "com.example.pinned")
    XCTAssertFalse(state.enabled)
    XCTAssertEqual(state.store.remembered["com.example.pinned"], true)

    // Switching back to .remember restores the preserved remembered mode.
    state.setPreference(.remember, for: "com.example.pinned")
    XCTAssertTrue(state.enabled)
  }
}
