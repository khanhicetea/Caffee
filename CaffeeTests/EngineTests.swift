//
//  EngineTests.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

final class EngineTests: EngineTestCase {

  /// Test "gi" alone: "gif" -> "gi" (g is consonant, i is vowel with tone)
  func testGiAlone() throws {
    let state = TiengVietState.empty
      .push("g").push("i").withTone(.huyen)
    XCTAssertEqual(state.transformed, "gì")
  }

  /// Test "gi" with following vowel: "gieets" -> "giet" (gi is consonant, e is vowel)
  func testGiWithVowel() throws {
    let state = TiengVietState.empty
      .push("g").push("i").push("e").push("t")
      .withMu(.muUp).withTone(.sac)
    XCTAssertEqual(state.transformed, "giết")
  }

  /// Test "gi" with "a": "gia" -> "gia" (gi is consonant, a is vowel)
  func testGiWithA() throws {
    let state = TiengVietState.empty
      .push("g").push("i").push("a")
    XCTAssertEqual(state.transformed, "gia")
  }

  /// Test detailed parsing of "gi" in various contexts based on TiengVietParser logic
  func testGiDetailedParsing() throws {
    // Case 1: "gi" alone -> g (consonant) + i (vowel)
    let res1 = TiengVietParser.parse(Array("gi"))
    XCTAssertEqual(String(res1.phuAmDau), "g")
    XCTAssertEqual(String(res1.nguyenAm), "i")

    // Case 2: "gi" before consonant: "gin" -> g (consonant) + i (vowel) + n (final)
    let res2 = TiengVietParser.parse(Array("gin"))
    XCTAssertEqual(String(res2.phuAmDau), "g")
    XCTAssertEqual(String(res2.nguyenAm), "i")
    XCTAssertEqual(String(res2.phuAmCuoi), "n")

    // Case 3: "gi" before vowel + final consonant: "gieng" -> g + ieng (merges i into vowel)
    let res3 = TiengVietParser.parse(Array("gieng"))
    XCTAssertEqual(String(res3.phuAmDau), "g")
    XCTAssertEqual(String(res3.nguyenAm), "ie")
    XCTAssertEqual(String(res3.phuAmCuoi), "ng")

    // Case 4: "gi" before vowel + final consonant where "i" + vowel is invalid: "giang" -> gi + ang
    let res4 = TiengVietParser.parse(Array("giang"))
    XCTAssertEqual(String(res4.phuAmDau), "gi")
    XCTAssertEqual(String(res4.nguyenAm), "a")
    XCTAssertEqual(String(res4.phuAmCuoi), "ng")

    // Case 5: "gi" before vowel without final consonant: "gia" -> gi + a (gi as consonant for mark placement)
    let res5 = TiengVietParser.parse(Array("gia"))
    XCTAssertEqual(String(res5.phuAmDau), "gi")
    XCTAssertEqual(String(res5.nguyenAm), "a")
  }

  /// Test Telex outputs for complex "gi" cases
  func testTelexGiDetailed() throws {
    XCTAssertEqual(transform_text_telex(for: "gif"), "gì")
    XCTAssertEqual(transform_text_telex(for: "gin"), "gin")
    XCTAssertEqual(transform_text_telex(for: "gieengs"), "giếng")
    XCTAssertEqual(transform_text_telex(for: "giangs"), "giáng")
    XCTAssertEqual(transform_text_telex(for: "gias"), "giá")
    XCTAssertEqual(transform_text_telex(for: "giuwx"), "giữ")
  }

  /// Test that state mutations return new state without affecting original
  func testImmutability() throws {
    let state1 = TiengVietState.empty.push("a")
    let state2 = state1.withTone(.sac)

    XCTAssertEqual(state1.transformed, "a")  // Original unchanged
    XCTAssertEqual(state2.transformed, "á")  // New state has tone
  }

  /// Test that push returns new state
  func testPushImmutability() throws {
    let state1 = TiengVietState.empty.push("h").push("o")
    let state2 = state1.push("m")

    XCTAssertEqual(state1.transformed, "ho")
    XCTAssertEqual(state2.transformed, "hom")
  }

  /// Test that pop returns new state
  func testPopImmutability() throws {
    let state1 = TiengVietState.empty.push("h").push("o").push("m")
    let state2 = state1.pop()

    XCTAssertEqual(state1.transformed, "hom")
    XCTAssertEqual(state2.transformed, "ho")
  }

  /// Test toggle behavior for tone marks
  func testToneToggle() throws {
    let state1 = TiengVietState.empty.push("a")
    let state2 = state1.withTone(.sac)
    let state3 = state2.withTone(.sac)  // Toggle off

    XCTAssertEqual(state1.transformed, "a")
    XCTAssertEqual(state2.transformed, "á")
    XCTAssertEqual(state3.transformed, "a")  // Tone removed
  }

  /// Test toggle behavior for diacritical marks
  func testMuToggle() throws {
    let state1 = TiengVietState.empty.push("a")
    let state2 = state1.withMu(.muUp)
    let state3 = state2.withMu(.muUp)  // Toggle off

    XCTAssertEqual(state1.transformed, "a")
    XCTAssertEqual(state2.transformed, "â")
    XCTAssertEqual(state3.transformed, "a")  // Mark removed
  }

  /// Test basic Telex input
  func testBasicTelex() throws {
    let result = transform_text_telex(for: "xin chaof")
    XCTAssertEqual(result, "xin chào")
  }

  /// Test VNI input
  func testBasicVNI() throws {
    let result = transform_text_vni(for: "xin cha2o")
    XCTAssertEqual(result, "xin chào")
  }

  func testInputProcessorHandlesKeyboardEventsWithoutCGEvent() throws {
    let sender = MockReplacementSender()
    let processor = InputProcessor(
      method: .telex,
      replacementSender: sender,
      selectionDetector: MockSelectionDetector(hasSelection: false),
      compatibilityPolicy: DefaultAppCompatibilityPolicy(overrides: { [:] })
    )

    XCTAssertEqual(processor.handleInputEvent(.keyCode(0)), .passThrough)  // a
    XCTAssertEqual(processor.handleInputEvent(.keyCode(1)), .handled)  // s

    XCTAssertEqual(processor.wordBuffer.transformed, "á")
    XCTAssertEqual(sender.replacementCalls.count, 1)
    XCTAssertEqual(sender.replacementCalls.first?.backspaceCount, 1)
    XCTAssertEqual(sender.replacementCalls.first?.diffChars, ["á"])
  }

  func testAutocompletePolicyUsesSelectAndReplaceWhenSelectionExists() throws {
    let sender = MockReplacementSender()
    let processor = InputProcessor(
      method: .telex,
      replacementSender: sender,
      selectionDetector: MockSelectionDetector(hasSelection: true),
      compatibilityPolicy: DefaultAppCompatibilityPolicy(overrides: { [:] })
    )
    processor.changeActiveApp("com.google.Chrome")

    _ = processor.handleInputEvent(.keyCode(0))  // a
    XCTAssertEqual(processor.handleInputEvent(.keyCode(1)), .handled)  // s

    XCTAssertTrue(sender.replacementCalls.isEmpty)
    XCTAssertEqual(sender.selectAndReplaceCalls.count, 1)
    XCTAssertEqual(sender.selectAndReplaceCalls.first?.backspaceCount, 1)
    XCTAssertEqual(sender.selectAndReplaceCalls.first?.diffChars, ["á"])
  }

  /// Test "khong" with Telex
  func testKhongTelex() throws {
    let result = transform_text_telex(for: "khoong")
    XCTAssertEqual(result, "không")
  }

  /// Test that invalid vowel combination triggers recovery
  func testInvalidVowelRecovery() throws {
    // "ae" is not a valid Vietnamese vowel combination
    let result = transform_text_telex(for: "aes")
    // Should recover to original input since "ae" + tone doesn't make sense
    XCTAssertEqual(result, "aes")
  }

  /// Test that invalid final consonant triggers recovery
  func testInvalidFinalConsonantRecovery() throws {
    // "ai" cannot take final consonant "m" - "aim" is invalid
    let result = transform_text_telex(for: "aimf")
    // Should recover to original input
    XCTAssertEqual(result, "aimf")
  }

  /// Test valid Vietnamese still works correctly
  func testValidVietnameseNoRecovery() throws {
    // "tiếng" is valid Vietnamese
    let result = transform_text_telex(for: "tieengs")
    XCTAssertEqual(result, "tiếng")
  }

  /// Test needsRecovery property directly
  func testNeedsRecoveryProperty() throws {
    // Invalid: "ae" vowel combination
    let invalidState = TiengVietState.empty.push("a").push("e")
    XCTAssertTrue(invalidState.needsRecovery)

    // Valid: "a" simple vowel
    let validState = TiengVietState.empty.push("a")
    XCTAssertFalse(validState.needsRecovery)
  }

  /// Test originalInput property
  func testOriginalInputProperty() throws {
    let state = TiengVietState.empty.push("t").push("h").push("a").push("e")
    XCTAssertEqual(state.originalInput, "thae")
  }

  /// Test "xuất" - the vowel "ua" with circumflex becomes "uâ" which CAN take "t"
  func testXuatWithCircumflex() throws {
    let result = transform_text_telex(for: "xuaats")
    XCTAssertEqual(result, "xuất")
  }

  /// Test "xuân" - the vowel "ua" with circumflex becomes "uâ" which CAN take "n"
  func testXuanWithCircumflex() throws {
    let result = transform_text_telex(for: "xuaan")
    XCTAssertEqual(result, "xuân")
  }

  /// Test "luật" - similar case with "uâ" + "t"
  func testLuatWithCircumflex() throws {
    let result = transform_text_telex(for: "luaatj")
    XCTAssertEqual(result, "luật")
  }

  /// Test "được" - the vowel "uo" with horn becomes "ươ" which CAN take "c"
  func testDuocWithHorn() throws {
    let result = transform_text_telex(for: "dduowcj")
    XCTAssertEqual(result, "được")
  }

  /// Test "mượn" - the vowel "uo" with horn becomes "ươ" which CAN take "n"
  func testMuonWithHorn() throws {
    let result = transform_text_telex(for: "muownj")
    XCTAssertEqual(result, "mượn")
  }

  /// Test that base "ua" without diacritics still cannot take final consonants
  func testUaWithoutDiacriticRecovery() throws {
    // "uat" with no circumflex should trigger recovery since "ua" can't take "t"
    // (This tests the correct behavior - ua alone cannot have final consonant)
    let state = TiengVietState.empty.push("u").push("a").push("t")
    XCTAssertTrue(state.needsRecovery)
  }

  /// Test that "uâ" with circumflex CAN take final consonants
  func testUaWithCircumflexValid() throws {
    // "uât" with circumflex should be valid since "uâ" can take "t"
    let state = TiengVietState.empty.push("u").push("a").push("t").withMu(.muUp).withTone(.sac)
    XCTAssertFalse(state.needsRecovery)
    XCTAssertEqual(state.transformed, "uất")
  }

  /// Test parsing of syllable components
  func testStateParsing() throws {
    // Test initial consonant parsing
    let state1 = TiengVietState.empty.push("t").push("h").push("a")
    XCTAssertEqual(String(state1.thanhPhanTieng.phuAmDau), "th")
    XCTAssertEqual(String(state1.thanhPhanTieng.nguyenAm), "a")

    // Test final consonant parsing
    let state2 = TiengVietState.empty.push("a").push("n").push("h")
    XCTAssertEqual(String(state2.thanhPhanTieng.nguyenAm), "a")
    XCTAssertEqual(String(state2.thanhPhanTieng.phuAmCuoi), "nh")

    // Test complex syllable
    let state3 = TiengVietState.empty.push("n").push("g").push("h").push("i").push("e").push("n")
      .push("g")
    XCTAssertEqual(String(state3.thanhPhanTieng.phuAmDau), "ngh")
    XCTAssertEqual(String(state3.thanhPhanTieng.nguyenAm), "ie")
    XCTAssertEqual(String(state3.thanhPhanTieng.phuAmCuoi), "ng")
  }

  /// Test tone mark placement
  func testStateTonePlacement() throws {
    // Single vowel: tone on that vowel
    let state1 = TiengVietState.empty.push("m").push("a").withTone(.sac)
    XCTAssertEqual(state1.transformed, "má")

    // Multiple vowels: tone on correct position
    let state2 = TiengVietState.empty.push("t").push("o").push("a").push("n").withTone(.sac)
    XCTAssertEqual(state2.transformed, "toán")

    // ươ combination
    let state3 = TiengVietState.empty.push("t").push("u").push("o").push("i").withMu(.muMoc)
      .withTone(.sac)
    XCTAssertEqual(state3.transformed, "tưới")
  }

  /// Test chaining multiple state operations
  func testStateChaining() throws {
    let state = TiengVietState.empty
      .push("t").push("i").push("e").push("n").push("g")
      .withMu(.muUp)
      .withTone(.sac)
    XCTAssertEqual(state.transformed, "tiếng")
  }

  /// Test pop operation resets correctly
  func testStatePopReset() throws {
    let state1 = TiengVietState.empty.push("m").push("a").withTone(.sac)
    let state2 = state1.pop()  // remove 'a'
    XCTAssertEqual(state2.transformed, "m")
    XCTAssertEqual(state2.dauThanh, .bang)  // tone should be reset when vowel removed
  }
}
