//
//  AutomationTests.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

@MainActor
final class AutomationTests: XCTestCase {

  func testFileMonitorHandlesRepeatedTruncatingWrites() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("caffee-switch-\(UUID().uuidString)")
    FileManager.default.createFile(atPath: url.path, contents: nil)
    defer { try? FileManager.default.removeItem(at: url) }

    final class Recorder: FileMonitorDelegate {
      var received: [String] = []
      func didReceive(changes: String) { received.append(changes) }
    }
    let recorder = Recorder()
    let monitor = try FileMonitor(url: url)
    monitor.delegate = recorder

    for value in ["vi", "en", "vi"] {
      try value.write(to: url, atomically: false, encoding: .utf8)  // truncate + write
      let settled = expectation(description: "received \(value)")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
      wait(for: [settled], timeout: 2)
      XCTAssertEqual(recorder.received.last, value)
    }
    XCTAssertFalse(recorder.received.contains(""))
    withExtendedLifetime(monitor) {}
  }
}

// MARK: - Commands, per-app rules, permission

@MainActor
final class ModeCommandTests: XCTestCase {

  func testParsesSwitchFileText() {
    XCTAssertEqual(ModeCommand.parse(text: "vi\n"), .setVietnamese(true))
    XCTAssertEqual(ModeCommand.parse(text: " EN "), .setVietnamese(false))
    XCTAssertEqual(ModeCommand.parse(text: "toggle"), .toggle)
    XCTAssertEqual(ModeCommand.parse(text: "vni"), .setMethod(.vni))
    XCTAssertEqual(ModeCommand.parse(text: "telex"), .setMethod(.telex))
    // Unknown text must never flip the mode (it used to mean "disable").
    XCTAssertNil(ModeCommand.parse(text: "banana"))
    XCTAssertNil(ModeCommand.parse(text: ""))
  }

  func testParsesURLs() throws {
    func parse(_ string: String) throws -> ModeCommand? {
      ModeCommand.parse(url: try XCTUnwrap(URL(string: string)))
    }
    XCTAssertEqual(try parse("caffee://mode/vi"), .setVietnamese(true))
    XCTAssertEqual(try parse("caffee://mode/en"), .setVietnamese(false))
    XCTAssertEqual(try parse("caffee://mode/toggle"), .toggle)
    XCTAssertEqual(try parse("caffee://method/vni"), .setMethod(.vni))
    XCTAssertNil(try parse("caffee://mode/other"))
    XCTAssertNil(try parse("caffee://method/vi"))
    XCTAssertNil(try parse("caffee://unknown/vi"))
    XCTAssertNil(try parse("https://mode/vi"))
  }

  func testServiceForwardsCommandsFromURLsAndFile() throws {
    final class Recorder: ModeControlling {
      var commands: [ModeCommand] = []
      func apply(_ command: ModeCommand) { commands.append(command) }
    }
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("caffee-auto-\(UUID().uuidString)")
    let file = directory.appendingPathComponent("switch")
    defer { try? FileManager.default.removeItem(at: directory) }

    let recorder = Recorder()
    let service = AutomationService(controller: recorder, switchFileURL: file)
    service.start()
    // The control file lives in a directory only the user can write to.
    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

    service.handle(url: try XCTUnwrap(URL(string: "caffee://mode/vi")))
    XCTAssertEqual(recorder.commands, [.setVietnamese(true)])

    try "toggle".write(to: file, atomically: false, encoding: .utf8)
    let settled = expectation(description: "file change delivered")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { settled.fulfill() }
    wait(for: [settled], timeout: 2)
    XCTAssertEqual(recorder.commands.last, .toggle)

    service.handle(url: try XCTUnwrap(URL(string: "caffee://nonsense/x")))
    XCTAssertEqual(recorder.commands.count, 2)
  }
}

final class AppModeStoreTests: XCTestCase {

  func testRememberedModeIsReplayedForThatAppOnly() {
    var store = AppModeStore()
    store.remember(false, in: "com.apple.Terminal")
    store.remember(true, in: "com.apple.Notes")
    XCTAssertEqual(store.mode(for: "com.apple.Terminal"), false)
    XCTAssertEqual(store.mode(for: "com.apple.Notes"), true)
    XCTAssertNil(store.mode(for: "com.example.new"))
  }

  func testPinnedModeBeatsRememberedMode() {
    var store = AppModeStore()
    store.remember(false, in: "com.example.app")
    store.setPreference(.alwaysVietnamese, for: "com.example.app")
    XCTAssertEqual(store.mode(for: "com.example.app"), true)
    store.setPreference(.alwaysEnglish, for: "com.example.app")
    XCTAssertEqual(store.mode(for: "com.example.app"), false)
    store.setPreference(.remember, for: "com.example.app")
    XCTAssertEqual(store.mode(for: "com.example.app"), false)  // back to the remembered value
    XCTAssertTrue(store.preferences.isEmpty)  // defaults are not stored
  }

  func testStrategyOverridesAndForget() {
    var store = AppModeStore()
    store.setStrategy(.stepByStep, for: "a")
    store.setStrategy(.fast, for: "b")
    store.remember(true, in: "c")
    XCTAssertEqual(store.knownApps, ["a", "b", "c"])
    XCTAssertEqual(store.strategy(for: "a"), .stepByStep)
    XCTAssertEqual(store.strategy(for: "zzz"), .automatic)

    store.setStrategy(.automatic, for: "a")
    XCTAssertTrue(store.strategies["a"] == nil)
    store.forget("b")
    store.forget("c")
    XCTAssertTrue(store.knownApps.isEmpty)
  }
}

@MainActor
final class PermissionMonitorTests: XCTestCase {

  func testReportsOnlyRealChanges() {
    var granted = false
    let monitor = PermissionMonitor(check: { granted })
    var changes: [Bool] = []
    monitor.onChange = { changes.append($0) }

    XCTAssertFalse(monitor.isTrusted)
    XCTAssertFalse(monitor.refresh())
    XCTAssertEqual(changes, [])

    granted = true
    XCTAssertTrue(monitor.refresh())
    XCTAssertTrue(monitor.refresh())
    XCTAssertEqual(changes, [true])

    granted = false
    monitor.refresh()
    XCTAssertEqual(changes, [true, false])
  }

  func testPollingPicksUpTheGrant() {
    var granted = false
    let monitor = PermissionMonitor(check: { granted })
    monitor.start(interval: 0.05)
    defer { monitor.stop() }

    granted = true
    let picked = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in monitor.isTrusted }, object: nil)
    wait(for: [picked], timeout: 2)
    XCTAssertTrue(monitor.isTrusted)
  }
}

final class ReplacementTests: XCTestCase {

  func testDiffKeepsTheCommonPrefix() {
    XCTAssertEqual(
      Replacement.diff(from: "tieng", to: "tiếng"),
      Replacement(deleteCount: 3, insert: Array("ếng")))
    XCTAssertEqual(
      Replacement.diff(from: "ca", to: "cas"), Replacement(deleteCount: 0, insert: ["s"]))
    XCTAssertEqual(Replacement.diff(from: "abc", to: "abc"), .none)
    XCTAssertEqual(
      Replacement.diff(from: "abc", to: "ab"), Replacement(deleteCount: 1, insert: []))
  }
}
