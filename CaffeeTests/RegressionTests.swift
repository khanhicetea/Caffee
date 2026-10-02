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

  // MARK: - review-engine.md

  /// Horning u and o separately must keep both horns (#1), and a horn typed on u stays visible
  /// once o follows (#9).
  func testHornOnEachVowel() {
    for (keys, expected) in [
      ("dduwowcj", "được"), ("nguwowif", "người"), ("thuwowngr", "thưởng"),
      ("chuwowng", "chương"), ("ruwowuj", "rượu"), ("tuwo", "tươ"), ("tuwowi", "tươi"),
      // Without a horn on u, an open "uo" only horns the o, and ww still cancels.
      ("thuowr", "thuở"), ("huow", "huơ"), ("huoww", "huow"),
    ] {
      XCTAssertEqual(typeOnScreen(keys, method: .telex), expected, keys)
    }
    for (keys, expected) in [
      ("u7o7ng", "ương"), ("d9u7o7c5", "được"), ("tu7o", "tươ"), ("thuo73", "thuở"),
    ] {
      XCTAssertEqual(typeOnScreen(keys, method: .vni), expected, keys)
    }
  }

  /// Backspace in a recovered word removes exactly one character (#2, #5).
  func testBackspaceInRecoveredWord() {
    for (keys, expected) in [
      ("texting<", "textin"), ("based<", "base"), ("based<<", "bas"), ("based<<<<<", ""),
      ("tieenss<", "tiên"), ("tesst<", "tes"),
      // Recovery caused by the last key still rolls back to the Vietnamese word.
      ("base<", "bá"),
    ] {
      XCTAssertEqual(typeOnScreen(keys, method: .telex), expected, keys)
    }
    XCTAssertEqual(typeOnScreen("a1b<", method: .vni), "á")
  }

  /// Cancelling one mark with a double key keeps every other mark (#3).
  func testCancellingOneMarkKeepsTheOthers() {
    for (keys, expected) in [
      ("tieenss", "tiêns"), ("tieengss", "tiêngs"), ("dduowngff", "đươngf"),
      ("ddaayss", "đâys"), ("aaa", "aa"), ("ddd", "dd"), ("uww", "uw"),
    ] {
      XCTAssertEqual(typeOnScreen(keys, method: .telex), expected, keys)
    }
    for (keys, expected) in [
      ("d9uo7ng22", "đương2"), ("tie6ng11", "tiêng1"), ("a66", "a6"), ("d99", "d9"),
    ] {
      XCTAssertEqual(typeOnScreen(keys, method: .vni), expected, keys)
    }
  }

  /// Syllables ending in c, ch, p, t only take sắc or nặng (#4).
  func testStopFinalOnlyTakesSacOrNang() {
    for keys in ["text", "next", "texts", "hocf", "matr"] {
      XCTAssertEqual(typeOnScreen(keys, method: .telex), keys, keys)
    }
    XCTAssertEqual(typeOnScreen("hocj", method: .telex), "học")
    XCTAssertEqual(typeOnScreen("tieets", method: .telex), "tiết")
    XCTAssertEqual(typeOnScreen("ho2c", method: .vni), "ho2c")
  }

  /// A doubled vowel after a lowercase one still makes a circumflex (#7).
  func testMixedCaseDoubleVowel() {
    XCTAssertEqual(typeOnScreen("aA", method: .telex), "â")
    XCTAssertEqual(typeOnScreen("Aa", method: .telex), "Â")
  }

  /// Marks that land on a vowel no Vietnamese syllable has, and onsets that cannot precede the
  /// vowel, recover to the raw keys (#8, #10).
  func testInvalidMarkedNucleiAndOnsetsRecover() {
    for keys in ["hoaa", "oee", "chaoo", "qas", "ghas", "nghoj", "auw", "huyw"] {
      XCTAssertEqual(typeOnScreen(keys, method: .telex), keys, keys)
    }
    // Place names spelled with k before a/o keep working.
    XCTAssertEqual(typeOnScreen("Kanj", method: .telex), "Kạn")
    XCTAssertEqual(typeOnScreen("ghes", method: .telex), "ghé")
    XCTAssertEqual(typeOnScreen("nghix", method: .telex), "nghĩ")
    XCTAssertEqual(typeOnScreen("gio6ng1", method: .vni), "giống")
  }
}
