//
//  RegressionTests.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

final class RegressionTests: EngineTestCase {

  /// Test case: typing common greeting
  func testRegressionXinChao() throws {
    XCTAssertEqual(transform_text_telex(for: "xin chaof"), "xin chào")
    XCTAssertEqual(transform_text_vni(for: "xin cha2o"), "xin chào")
  }

  /// Test case: typing "tất cả"
  func testRegressionTatCa() throws {
    XCTAssertEqual(transform_text_telex(for: "taats car"), "tất cả")
    XCTAssertEqual(transform_text_vni(for: "ta61t ca3"), "tất cả")
  }

  /// Test case: typing "các bạn"
  func testRegressionCacBan() throws {
    XCTAssertEqual(transform_text_telex(for: "cacs banj"), "các bạn")
    XCTAssertEqual(transform_text_vni(for: "ca1c ba5n"), "các bạn")
  }

  /// Test case: typing "không" - multiple valid approaches
  func testRegressionKhong() throws {
    XCTAssertEqual(transform_text_telex(for: "khoong"), "không")  // oo=ô, no tone = ngang
    XCTAssertEqual(transform_text_vni(for: "kho6ng"), "không")
  }

  /// Test case: sentences with mixed content
  func testRegressionMixedSentence() throws {
    let telex = transform_text_telex(for: "toi yeeu vieejt nam")
    XCTAssertEqual(telex, "toi yêu việt nam")

    let vni = transform_text_vni(for: "toi ye6u vie65t nam")
    XCTAssertEqual(vni, "toi yêu việt nam")
  }

  func testBugTesst() throws {
    let inputProcessor = InputProcessor(method: .telex)
    inputProcessor.push(char: "t")
    inputProcessor.push(char: "e")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "té")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "tes")
    XCTAssertTrue(inputProcessor.wordBuffer.stopProcessing)
    inputProcessor.push(char: "t")
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "test")
  }

  func testBugTesstBackspace() throws {
    let inputProcessor = InputProcessor(method: .telex)
    inputProcessor.push(char: "t")
    inputProcessor.push(char: "e")
    inputProcessor.push(char: "s")
    inputProcessor.push(char: "s")
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "tes")
    XCTAssertTrue(inputProcessor.wordBuffer.stopProcessing)
    inputProcessor.push(char: "t")
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "test")

    // Backspace from "test"
    let _ = inputProcessor.pop()
    XCTAssertEqual(inputProcessor.wordBuffer.transformed, "tes")
    XCTAssertTrue(inputProcessor.wordBuffer.stopProcessing)
  }
}
