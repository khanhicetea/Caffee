//
//  CorpusTests.swift
//  CaffeeTests
//
//  Round-trip tests over a generated corpus of Vietnamese syllables. An independent model of
//  Vietnamese spelling (onsets, rimes, tone placement) produces every syllable together with the
//  Telex and VNI keystrokes that spell it; typing them must reproduce the syllable exactly.
//

import XCTest

@testable import Caffee

final class CorpusTests: XCTestCase {

  // MARK: - Spelling model

  private struct Tone {
    let combining: String
    let telex: Character
    let vni: Character
    /// Syllables ending in c, ch, p or t only carry sắc or nặng.
    let allowedAfterStop: Bool
  }

  private static let tones: [Tone] = [
    Tone(combining: "", telex: " ", vni: " ", allowedAfterStop: false),  // ngang: no key
    Tone(combining: "\u{0301}", telex: "s", vni: "1", allowedAfterStop: true),
    Tone(combining: "\u{0300}", telex: "f", vni: "2", allowedAfterStop: false),
    Tone(combining: "\u{0309}", telex: "r", vni: "3", allowedAfterStop: false),
    Tone(combining: "\u{0303}", telex: "x", vni: "4", allowedAfterStop: false),
    Tone(combining: "\u{0323}", telex: "j", vni: "5", allowedAfterStop: true),
  ]

  private static let stopCodas: Set<String> = ["c", "ch", "p", "t"]
  private static let allCodas = ["c", "ch", "m", "n", "ng", "nh", "p", "t"]

  /// Nucleus → codas it may take ("" = open syllable).
  private static let plainNuclei: [(nucleus: String, codas: [String])] = [
    ("a", [""] + allCodas),
    ("ă", ["c", "m", "n", "ng", "p", "t"]),
    ("â", ["c", "m", "n", "ng", "p", "t"]),
    ("e", ["", "c", "m", "n", "ng", "p", "t"]),
    ("ê", ["", "ch", "m", "n", "nh", "p", "t"]),
    ("i", ["", "ch", "m", "n", "nh", "p", "t"]),
    ("o", ["", "c", "m", "n", "ng", "p", "t"]),
    ("ô", ["", "c", "m", "n", "ng", "p", "t"]),
    ("ơ", ["", "m", "n", "p", "t"]),
    ("u", ["", "c", "m", "n", "ng", "p", "t"]),
    ("ư", ["", "c", "m", "n", "ng", "t"]),
    ("ai", [""]), ("ao", [""]), ("au", [""]), ("ay", [""]), ("âu", [""]), ("ây", [""]),
    ("eo", [""]), ("êu", [""]), ("ia", [""]), ("iu", [""]), ("oi", [""]), ("ôi", [""]),
    ("ơi", [""]), ("ua", [""]), ("ui", [""]), ("ưa", [""]), ("ưi", [""]), ("ưu", [""]),
    ("iê", ["c", "m", "n", "ng", "p", "t"]),
    ("iêu", [""]),
    ("uô", ["c", "m", "n", "ng", "t"]),
    ("uôi", [""]),
    ("ươ", ["c", "m", "n", "ng", "p", "t"]),
    ("ươi", [""]), ("ươu", [""]),
  ]

  /// Nuclei that begin with a glide (oa, uy, …): only after some onsets.
  private static let glideNuclei: [(nucleus: String, codas: [String])] = [
    ("oa", [""] + allCodas),
    ("oă", ["c", "n", "ng", "t"]),
    ("oe", ["", "n", "t"]),
    ("oeo", [""]),
    ("oai", [""]), ("oay", [""]), ("uây", [""]),
    ("uâ", ["n", "ng", "t"]),
    ("uê", ["nh", "ch"]),
    ("uy", ["", "nh", "ch", "p", "t"]),
    ("uyê", ["n", "t"]),
  ]
  private static let glideOnsets = ["", "h", "kh", "l", "ng", "nh", "th", "t", "x", "ch", "đ", "d"]

  private static let quNuclei: [(nucleus: String, codas: [String])] = [
    ("a", [""] + allCodas), ("ă", ["c", "n", "ng", "t"]), ("â", ["n", "ng", "t"]),
    ("e", ["", "n", "t"]), ("ê", ["", "nh", "ch"]), ("ơ", [""]), ("y", ["", "nh", "t"]),
    ("yê", ["n", "t"]), ("ai", [""]), ("ay", [""]), ("ao", [""]),
  ]

  private static let giNuclei: [(nucleus: String, codas: [String])] = [
    ("a", [""] + allCodas), ("ă", ["c", "m", "n", "ng", "p", "t"]),
    ("â", ["c", "m", "n", "ng", "p", "t"]), ("e", [""]), ("o", [""]), ("ô", ["", "ng"]),
    ("ơ", [""]), ("u", ["", "c", "m", "n", "p"]), ("ư", [""]), ("ai", [""]), ("au", [""]),
    ("ay", [""]),
  ]

  /// Which nuclei an onset accepts (c/k, g/gh, ng/ngh follow the usual spelling rules).
  private static func nuclei(for onset: String) -> [(nucleus: String, codas: [String])] {
    let backVowels: Set<Character> = ["a", "ă", "â", "o", "ô", "ơ", "u", "ư"]
    let frontOnly: Set<Character> = ["e", "ê", "i"]
    func startsWith(_ set: Set<Character>, _ nucleus: String) -> Bool {
      nucleus.first.map(set.contains) ?? false
    }
    switch onset {
    case "c":
      return plainNuclei.filter { startsWith(backVowels, $0.nucleus) }
    case "k":
      return plainNuclei.filter { startsWith(frontOnly, $0.nucleus) || $0.nucleus == "iê" }
    case "g", "ng":
      return plainNuclei.filter {
        startsWith(backVowels, $0.nucleus) && !["ua", "uô", "uôi"].contains($0.nucleus)
      }
    case "gh", "ngh":
      return plainNuclei.filter {
        startsWith(frontOnly, $0.nucleus) || $0.nucleus == "iê"
      }.filter { $0.nucleus != "ia" && $0.nucleus != "iu" }
    case "qu": return quNuclei
    case "gi": return giNuclei
    default: return plainNuclei
    }
  }

  private static let onsets = [
    "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh",
    "nh", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x",
  ]

  /// Position of the tone mark within the nucleus (standard orthography, "hòa/thủy" style).
  private static func toneIndex(of nucleus: [Character], hasCoda: Bool) -> Int {
    let marked = nucleus.indices.filter { "ăâêôơư".contains(nucleus[$0]) }
    if let last = marked.last { return last }  // ươ → ơ, iê → ê, uô → ô
    switch nucleus.count {
    case 1: return 0
    case 2: return hasCoda ? 1 : 0
    default: return 1
    }
  }

  struct Syllable {
    let onset: String
    let nucleus: String
    let coda: String
    let tone: Int

    var plain: String { onset + nucleus + coda }

    var written: String {
      var letters = Array(nucleus)
      let index = CorpusTests.toneIndex(of: letters, hasCoda: !coda.isEmpty)
      letters[index] = Character(
        (String(letters[index]) + CorpusTests.tones[tone].combining)
          .precomposedStringWithCanonicalMapping)
      return (onset + String(letters) + coda).precomposedStringWithCanonicalMapping
    }

    /// Where, within the typed letters, the tone key may go: right after the nucleus.
    var toneKeyAfterNucleusOffset: Int { 0 }
  }

  static let corpus: [Syllable] = {
    var result: [Syllable] = []
    func add(onset: String, nucleus: String, codas: [String]) {
      for coda in codas {
        for tone in tones.indices {
          if stopCodas.contains(coda) && !tones[tone].allowedAfterStop && tone != 0 { continue }
          if stopCodas.contains(coda) && tone == 0 { continue }
          result.append(Syllable(onset: onset, nucleus: nucleus, coda: coda, tone: tone))
        }
      }
    }
    for onset in onsets {
      for (nucleus, codas) in nuclei(for: onset) {
        add(onset: onset, nucleus: nucleus, codas: codas)
      }
    }
    for onset in glideOnsets {
      for (nucleus, codas) in glideNuclei { add(onset: onset, nucleus: nucleus, codas: codas) }
    }
    return result
  }()

  // MARK: - Keystrokes

  private static func telexKeys(_ text: String) -> [String] {
    // One entry per written letter; "ươ" is typed as "uow" (the w marks both vowels).
    var keys: [String] = []
    var letters = Array(text)
    var i = 0
    while i < letters.count {
      let c = letters[i]
      if c == "ư", i + 1 < letters.count, letters[i + 1] == "ơ" {
        keys.append("uo")
        keys.append("w")
        i += 2
        continue
      }
      switch c {
      case "â": keys.append("aa")
      case "ê": keys.append("ee")
      case "ô": keys.append("oo")
      case "ă": keys.append("aw")
      case "ơ": keys.append("ow")
      case "ư": keys.append("uw")
      case "đ": keys.append("dd")
      default: keys.append(String(c))
      }
      i += 1
    }
    letters = []
    return keys
  }

  private static func vniKeys(_ text: String) -> [String] {
    var keys: [String] = []
    let letters = Array(text)
    var i = 0
    while i < letters.count {
      let c = letters[i]
      if c == "ư", i + 1 < letters.count, letters[i + 1] == "ơ" {
        keys.append("uo")
        keys.append("7")
        i += 2
        continue
      }
      switch c {
      case "â": keys.append("a6")
      case "ê": keys.append("e6")
      case "ô": keys.append("o6")
      case "ă": keys.append("a8")
      case "ơ": keys.append("o7")
      case "ư": keys.append("u7")
      case "đ": keys.append("d9")
      default: keys.append(String(c))
      }
      i += 1
    }
    return keys
  }

  private func typed(_ keys: String, method: TypingMethods) -> String {
    let processor = InputProcessor(method: method)
    keys.forEach { processor.push(char: $0) }
    return processor.wordBuffer.transformed
  }

  /// Keystrokes with the tone key placed at the end, or right after the nucleus.
  private func keystrokes(for syllable: Syllable, method: TypingMethod2, toneAfterNucleus: Bool)
    -> String
  {
    let tone = Self.tones[syllable.tone]
    let toneKey: String =
      syllable.tone == 0 ? "" : String(method == .telex ? tone.telex : tone.vni)
    let encode = method == .telex ? Self.telexKeys : Self.vniKeys
    let onset = encode(syllable.onset).joined()
    let nucleus = encode(syllable.nucleus).joined()
    let coda = syllable.coda
    return toneAfterNucleus
      ? onset + nucleus + toneKey + coda : onset + nucleus + coda + toneKey
  }

  enum TypingMethod2 { case telex, vni }

  // MARK: - Tests

  func testCorpusIsLargeEnoughToMatter() {
    XCTAssertGreaterThan(Self.corpus.count, 8_000)
  }

  private func runCorpus(method: TypingMethod2, toneAfterNucleus: Bool, capitalize: Bool = false)
    -> [String]
  {
    var failures: [String] = []
    for (index, syllable) in Self.corpus.enumerated() {
      if toneAfterNucleus && syllable.coda.isEmpty { continue }
      if capitalize && index % 5 != 0 { continue }
      var keys = keystrokes(for: syllable, method: method, toneAfterNucleus: toneAfterNucleus)
      var expected = syllable.written
      if capitalize {
        keys = keys.prefix(1).uppercased() + keys.dropFirst()
        expected = expected.prefix(1).uppercased() + expected.dropFirst()
      }
      let actual = typed(keys, method: method == .telex ? .telex : .vni)
      if actual != expected { failures.append("\(keys) → \(actual) (expected \(expected))") }
    }
    return failures
  }

  private func assertNoFailures(_ failures: [String], _ label: String) {
    XCTAssertTrue(
      failures.isEmpty,
      "\(label): \(failures.count) failures, e.g.\n" + failures.prefix(40).joined(separator: "\n"))
  }

  func testTelexRoundTripToneAtEnd() {
    assertNoFailures(runCorpus(method: .telex, toneAfterNucleus: false), "telex/end")
  }

  func testTelexRoundTripToneAfterNucleus() {
    assertNoFailures(runCorpus(method: .telex, toneAfterNucleus: true), "telex/nucleus")
  }

  func testTelexRoundTripCapitalised() {
    assertNoFailures(
      runCorpus(method: .telex, toneAfterNucleus: false, capitalize: true), "telex/caps")
  }

  func testVNIRoundTripToneAtEnd() {
    assertNoFailures(runCorpus(method: .vni, toneAfterNucleus: false), "vni/end")
  }

  func testVNIRoundTripToneAfterNucleus() {
    assertNoFailures(runCorpus(method: .vni, toneAfterNucleus: true), "vni/nucleus")
  }

  // MARK: - English and code words must pass through untouched

  /// Words that look like Telex input but are not Vietnamese: the engine must hand them back
  /// exactly as typed (the recovery mechanism), with and without foreign consonants enabled.
  ///
  /// Not listed because Telex itself is ambiguous there, exactly as in other Vietnamese IMEs:
  /// a doubled tone key cancels the tone and prints one letter (boss → bos, pass → pas), and
  /// x/r/s/f/j after a vowel are tone keys that form a valid syllable (text → tẽt, box → bõ,
  /// user → ủe, data → dât).
  private static let englishWords = [
    "class", "classes", "press", "dress", "glass", "grass", "cross", "access", "process",
    "success", "address", "window", "windows", "file", "json", "const", "string", "print",
    "email", "server", "exit", "index", "float", "return", "import", "export", "function",
    "package", "version", "name", "type", "object", "public", "private", "static", "while",
    "stuff", "http", "https", "github", "swift", "xcode", "macos", "linux", "docker",
  ]

  func testEnglishWordsAreRecoveredUnchanged() {
    var failures: [String] = []
    for allowForeign in [false, true] {
      let config = EngineConfig(allowForeignConsonants: allowForeign)
      for word in Self.englishWords {
        let processor = InputProcessor(method: .telex, config: config)
        word.forEach { processor.push(char: $0) }
        let actual = processor.wordBuffer.transformed
        if actual != word { failures.append("\(word) → \(actual) (foreign: \(allowForeign))") }
      }
    }
    XCTAssertTrue(failures.isEmpty, "Not recovered:\n" + failures.joined(separator: "\n"))
  }
}
