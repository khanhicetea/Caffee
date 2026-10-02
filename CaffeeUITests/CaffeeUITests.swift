//
//  CaffeeUITests.swift
//  CaffeeUITests
//
//  Created by KhanhIceTea on 20/02/2024.
//

import XCTest

final class CaffeeUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  /// Caffee is a menu bar app: it must launch and keep running without a Dock presence.
  @MainActor
  func testAppLaunchesAndStaysRunning() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.state == .runningForeground)
    app.terminate()
  }
}
