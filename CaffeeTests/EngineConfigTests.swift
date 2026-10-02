//
//  EngineConfigTests.swift
//  CaffeeTests
//

import XCTest

@testable import Caffee

final class EngineConfigTests: XCTestCase {

  /// Types `keys` as one word and returns the on-screen text.
  private func type(_ keys: String, method: TypingMethods = .telex, config: EngineConfig)
    -> String
  {
    let processor = InputProcessor(method: method, config: config)
    keys.forEach { processor.push(char: $0) }
    return processor.wordBuffer.transformed
  }

  // MARK: - Foreign consonants

  func testForeignConsonantsFollowTheConfig() {
    let off = EngineConfig(allowForeignConsonants: false)
    let on = EngineConfig(allowForeignConsonants: true)
    XCTAssertEqual(type("zas", config: off), "zas")
    XCTAssertEqual(type("fair", config: off), "fair")
    XCTAssertEqual(type("zas", config: on), "zá")
    XCTAssertEqual(type("fair", config: on), "fải")
  }

  func testTwoConfigsCoexist() {
    // Regression for the old global `PhuAmDau`: one process, two different configs.
    let a = InputProcessor(method: .telex, config: EngineConfig(allowForeignConsonants: true))
    let b = InputProcessor(method: .telex, config: EngineConfig(allowForeignConsonants: false))
    "zas".forEach {
      a.push(char: $0)
      b.push(char: $0)
    }
    XCTAssertEqual(a.wordBuffer.transformed, "zá")
    XCTAssertEqual(b.wordBuffer.transformed, "zas")
  }

  func testChangingConfigStartsAFreshWord() {
    let processor = InputProcessor(method: .telex)
    "vie".forEach { processor.push(char: $0) }
    processor.changeEngineConfig(EngineConfig(tonePlacement: .secondVowel))
    XCTAssertTrue(processor.wordBuffer.keys.isEmpty)
    XCTAssertEqual(processor.wordBuffer.wordState.config.tonePlacement, .secondVowel)
  }

  // MARK: - Tone placement

  func testTonePlacementOnOpenGlides() {
    let first = EngineConfig(tonePlacement: .firstVowel)
    let second = EngineConfig(tonePlacement: .secondVowel)
    let cases: [(keys: String, first: String, second: String)] = [
      ("hoaf", "hòa", "hoà"),
      ("thuyr", "thủy", "thuỷ"),
      ("khoer", "khỏe", "khoẻ"),
      ("hoas", "hóa", "hoá"),
      ("tuyf", "tùy", "tuỳ"),
    ]
    for item in cases {
      XCTAssertEqual(type(item.keys, config: first), item.first, item.keys)
      XCTAssertEqual(type(item.keys, config: second), item.second, item.keys)
    }
  }

  func testTonePlacementDoesNotAffectOtherSyllables() {
    // Closed syllables, marked vowels, diphthongs and triphthongs are the same in both styles.
    for keys in ["hoanf", "toans", "tieengs", "maij", "meof", "ngoaif", "quys", "muaf", "dduwowcj"]
    {
      XCTAssertEqual(
        type(keys, config: EngineConfig(tonePlacement: .firstVowel)),
        type(keys, config: EngineConfig(tonePlacement: .secondVowel)),
        keys)
    }
  }

  // MARK: - Spelling check

  func testSpellingCheckOffAlwaysAppliesMarks() {
    let checked = EngineConfig(spellingCheck: true)
    let unchecked = EngineConfig(spellingCheck: false)
    // "ai" cannot take a final "m": with checking the word comes back unchanged.
    XCTAssertEqual(type("aims", config: checked), "aims")
    // Without the check the tone key is applied anyway.
    XCTAssertNotEqual(type("aims", config: unchecked), "aims")
    // Valid Vietnamese is unaffected by the switch.
    XCTAssertEqual(type("tieengs", config: unchecked), "tiếng")
  }

  // MARK: - Generated case variants

  func testGeneratedCaseVariantsCoverEveryCasing() {
    XCTAssertEqual(TiengViet.PhuAmGhep.count, 48)
    XCTAssertEqual(TiengViet.PhuAmCuoi.count, 22)
    XCTAssertEqual(TiengViet.NguyenAmGhep.count, 180)
    XCTAssertEqual(TiengViet.NguyenAmUO.count, 20)
    XCTAssertTrue(TiengViet.PhuAmGhep.contains("nGH"))
    XCTAssertTrue(TiengViet.NguyenAmGhep.contains("uOI"))
  }

  func testCaseVariantsAreSortedLongestFirst() {
    let lengths = TiengViet.NguyenAmGhep.map(\.count)
    XCTAssertEqual(lengths, lengths.sorted(by: >))
    XCTAssertEqual(caseVariants(of: ["ng"]), ["NG", "Ng", "nG", "ng"])
  }

  func testMixedCaseSyllablesStillParse() {
    let config = EngineConfig()
    XCTAssertEqual(type("NGHIEEMJ", config: config), "NGHIỆM")
    XCTAssertEqual(type("TrUOWNGf", config: config), "TrƯỜNG")
  }
}
