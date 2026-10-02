//
//  TelexTests.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

final class TelexTests: EngineTestCase {

  /// Test paragraph-level transformation with corrected Telex input
  func testExample() throws {
    // Test a simpler sentence with correct Telex sequences
    let sentence = transform_text_telex(for: "xin chaof taats car cacs banj")
    XCTAssertEqual(sentence, "xin chào tất cả các bạn")

    // Test individual common Vietnamese words
    XCTAssertEqual(transform_text_telex(for: "ddieemr"), "điểm")
    XCTAssertEqual(transform_text_telex(for: "phieen"), "phiên")
    XCTAssertEqual(transform_text_telex(for: "ddaauf"), "đầu")
    XCTAssertEqual(transform_text_telex(for: "tieenf"), "tiền")
    XCTAssertEqual(transform_text_telex(for: "ddor"), "đỏ")
    XCTAssertEqual(transform_text_telex(for: "truowcs"), "trước")
    XCTAssertEqual(transform_text_telex(for: "chuwsng"), "chứng")
    XCTAssertEqual(transform_text_telex(for: "khoans"), "khoán")
  }

  /// Test all 5 tone marks with single vowel 'a'
  func testTelexToneMarksOnA() throws {
    XCTAssertEqual(transform_text_telex(for: "as"), "á")  // sắc
    XCTAssertEqual(transform_text_telex(for: "af"), "à")  // huyền
    XCTAssertEqual(transform_text_telex(for: "ar"), "ả")  // hỏi
    XCTAssertEqual(transform_text_telex(for: "ax"), "ã")  // ngã
    XCTAssertEqual(transform_text_telex(for: "aj"), "ạ")  // nặng
  }

  /// Test tone marks with common words
  func testTelexToneMarksInWords() throws {
    XCTAssertEqual(transform_text_telex(for: "mas"), "má")
    XCTAssertEqual(transform_text_telex(for: "maf"), "mà")
    XCTAssertEqual(transform_text_telex(for: "mar"), "mả")
    XCTAssertEqual(transform_text_telex(for: "max"), "mã")
    XCTAssertEqual(transform_text_telex(for: "maj"), "mạ")
  }

  /// Test circumflex (mũ) marks: aa→â, ee→ê, oo→ô
  func testTelexCircumflex() throws {
    XCTAssertEqual(transform_text_telex(for: "caan"), "cân")
    XCTAssertEqual(transform_text_telex(for: "been"), "bên")
    XCTAssertEqual(transform_text_telex(for: "tooi"), "tôi")
  }

  /// Test breve (trăng) mark: aw→ă
  func testTelexBreve() throws {
    XCTAssertEqual(transform_text_telex(for: "awn"), "ăn")
    XCTAssertEqual(transform_text_telex(for: "tawm"), "tăm")  // no tone
    XCTAssertEqual(transform_text_telex(for: "tawms"), "tắm")  // with sắc tone
  }

  /// Test horn (móc) marks: ow→ơ, uw→ư
  func testTelexHorn() throws {
    XCTAssertEqual(transform_text_telex(for: "owi"), "ơi")
    XCTAssertEqual(transform_text_telex(for: "uwa"), "ưa")
    XCTAssertEqual(transform_text_telex(for: "muw"), "mư")
    XCTAssertEqual(transform_text_telex(for: "mow"), "mơ")
  }

  /// Test 'w' key alone (context-dependent)
  func testTelexWKey() throws {
    XCTAssertEqual(transform_text_telex(for: "tuowi"), "tươi")
    XCTAssertEqual(transform_text_telex(for: "nguowif"), "người")
  }

  /// Test dd→đ
  func testTelexStrokedD() throws {
    XCTAssertEqual(transform_text_telex(for: "ddi"), "đi")
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")
    XCTAssertEqual(transform_text_telex(for: "ddangs"), "đáng")
  }

  /// Test combinations of circumflex + tone
  func testTelexCircumflexWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "caanf"), "cần")
    XCTAssertEqual(transform_text_telex(for: "taats"), "tất")
    XCTAssertEqual(transform_text_telex(for: "beenr"), "bển")
    XCTAssertEqual(transform_text_telex(for: "tooix"), "tỗi")
    XCTAssertEqual(transform_text_telex(for: "tooij"), "tội")
  }

  /// Test combinations of horn + tone
  func testTelexHornWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "mowx"), "mỡ")
    XCTAssertEqual(transform_text_telex(for: "muws"), "mứ")
    XCTAssertEqual(transform_text_telex(for: "tuowis"), "tưới")
  }

  /// Test combinations of breve + tone
  func testTelexBreveWithTone() throws {
    XCTAssertEqual(transform_text_telex(for: "awns"), "ắn")
    XCTAssertEqual(transform_text_telex(for: "tawmf"), "tằm")
    XCTAssertEqual(transform_text_telex(for: "bawngj"), "bặng")
  }

  /// Test "gi" special case - gi alone vs gi+vowel
  func testTelexGiCases() throws {
    // gi alone: tone goes on 'i'
    XCTAssertEqual(transform_text_telex(for: "gis"), "gí")
    XCTAssertEqual(transform_text_telex(for: "gif"), "gì")

    // gi + vowel: gi is consonant, tone on following vowel
    XCTAssertEqual(transform_text_telex(for: "gias"), "giá")
    XCTAssertEqual(transform_text_telex(for: "giaof"), "giào")
  }

  /// Test "qu" consonant cluster
  func testTelexQuCases() throws {
    XCTAssertEqual(transform_text_telex(for: "qua"), "qua")
    XCTAssertEqual(transform_text_telex(for: "quas"), "quá")
    XCTAssertEqual(transform_text_telex(for: "quaans"), "quấn")
    XCTAssertEqual(transform_text_telex(for: "quaans"), "quấn")
  }

  /// Test "ngh" consonant cluster
  func testTelexNghCases() throws {
    XCTAssertEqual(transform_text_telex(for: "nghif"), "nghì")
    XCTAssertEqual(transform_text_telex(for: "ngheef"), "nghề")
    XCTAssertEqual(transform_text_telex(for: "nghieengj"), "nghiệng")
  }

  /// Test other consonant clusters: ch, kh, ng, nh, ph, th, tr
  func testTelexConsonantClusters() throws {
    XCTAssertEqual(transform_text_telex(for: "chas"), "chá")
    XCTAssertEqual(transform_text_telex(for: "khoong"), "không")  // oo=ô, ngang tone
    XCTAssertEqual(transform_text_telex(for: "ngans"), "ngán")
    XCTAssertEqual(transform_text_telex(for: "nhanf"), "nhàn")
    XCTAssertEqual(transform_text_telex(for: "phos"), "phó")
    XCTAssertEqual(transform_text_telex(for: "thaays"), "thấy")
    XCTAssertEqual(transform_text_telex(for: "trongs"), "tróng")
  }

  /// Test frequently used Vietnamese words
  func testTelexCommonWords() throws {
    XCTAssertEqual(transform_text_telex(for: "xin"), "xin")
    XCTAssertEqual(transform_text_telex(for: "chaof"), "chào")
    XCTAssertEqual(transform_text_telex(for: "camr"), "cảm")
    XCTAssertEqual(transform_text_telex(for: "own"), "ơn")
    XCTAssertEqual(transform_text_telex(for: "vieejt"), "việt")
    XCTAssertEqual(transform_text_telex(for: "nam"), "nam")
    XCTAssertEqual(transform_text_telex(for: "hanhj"), "hạnh")
    XCTAssertEqual(transform_text_telex(for: "phucs"), "phúc")
  }

  /// Test more complex words
  func testTelexComplexWords() throws {
    XCTAssertEqual(transform_text_telex(for: "nguoiwf"), "người")
    XCTAssertEqual(transform_text_telex(for: "dduowngf"), "đường")
    XCTAssertEqual(transform_text_telex(for: "chuowng"), "chương")
    XCTAssertEqual(transform_text_telex(for: "trinhf"), "trình")
  }

  /// Test tone toggle (typing same tone twice removes it)
  func testTelexToneToggle() throws {
    // Typing 's' twice should remove the tone and output 'as'
    XCTAssertEqual(transform_text_telex(for: "ass"), "as")
    XCTAssertEqual(transform_text_telex(for: "aff"), "af")
    XCTAssertEqual(transform_text_telex(for: "arr"), "ar")
    XCTAssertEqual(transform_text_telex(for: "axx"), "ax")
    XCTAssertEqual(transform_text_telex(for: "ajj"), "aj")
  }

  /// Test diacritical mark toggle
  func testTelexDiacriticToggle() throws {
    // Triple 'a' should result in 'aa' (â toggle off + a)
    XCTAssertEqual(transform_text_telex(for: "aaa"), "aa")
    XCTAssertEqual(transform_text_telex(for: "ooo"), "oo")
    XCTAssertEqual(transform_text_telex(for: "eee"), "ee")
  }

  /// Test 'w' toggle
  func testTelexWToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "aww"), "aw")
    XCTAssertEqual(transform_text_telex(for: "oww"), "ow")
    XCTAssertEqual(transform_text_telex(for: "uww"), "uw")
  }

  /// Test 'dd' toggle (triple d)
  func testTelexDToggle() throws {
    XCTAssertEqual(transform_text_telex(for: "ddd"), "dd")
  }

  /// Test invalid vowel combinations trigger recovery
  func testTelexInvalidVowelRecovery() throws {
    XCTAssertEqual(transform_text_telex(for: "aes"), "aes")
    XCTAssertEqual(transform_text_telex(for: "eas"), "eas")
    XCTAssertEqual(transform_text_telex(for: "yis"), "yis")
  }

  /// Test invalid final consonant triggers recovery
  func testTelexInvalidFinalConsonantRecovery() throws {
    // "ai" cannot have final consonants
    XCTAssertEqual(transform_text_telex(for: "aims"), "aims")
    XCTAssertEqual(transform_text_telex(for: "aotn"), "aotn")
  }

  /// Test foreign/loanwords that bypass Vietnamese rules
  func testTelexForeignWords() throws {
    // Words starting with non-Vietnamese patterns
    XCTAssertEqual(transform_text_telex(for: "macro"), "macro")
    XCTAssertEqual(transform_text_telex(for: "wifi"), "wifi")
  }

  /// Test single vowels with tone
  func testTelexSingleVowels() throws {
    XCTAssertEqual(transform_text_telex(for: "as"), "á")
    XCTAssertEqual(transform_text_telex(for: "es"), "é")
    XCTAssertEqual(transform_text_telex(for: "is"), "í")
    XCTAssertEqual(transform_text_telex(for: "os"), "ó")
    XCTAssertEqual(transform_text_telex(for: "us"), "ú")
    XCTAssertEqual(transform_text_telex(for: "ys"), "ý")
  }

  /// Test words ending with valid consonants
  func testTelexValidFinalConsonants() throws {
    XCTAssertEqual(transform_text_telex(for: "acs"), "ác")  // -c
    XCTAssertEqual(transform_text_telex(for: "achj"), "ạch")  // -ch
    XCTAssertEqual(transform_text_telex(for: "ams"), "ám")  // -m
    XCTAssertEqual(transform_text_telex(for: "anf"), "àn")  // -n
    XCTAssertEqual(transform_text_telex(for: "angf"), "àng")  // -ng
    XCTAssertEqual(transform_text_telex(for: "anhf"), "ành")  // -nh
    XCTAssertEqual(transform_text_telex(for: "aps"), "áp")  // -p
    XCTAssertEqual(transform_text_telex(for: "ats"), "át")  // -t
  }

  /// Test uppercase handling
  func testTelexUppercase() throws {
    XCTAssertEqual(transform_text_telex(for: "VIEEJT"), "VIỆT")
    XCTAssertEqual(transform_text_telex(for: "NAM"), "NAM")
    XCTAssertEqual(transform_text_telex(for: "DDUOWNGF"), "ĐƯỜNG")
  }

  /// Test mixed case
  func testTelexMixedCase() throws {
    XCTAssertEqual(transform_text_telex(for: "Vieejt"), "Việt")
    XCTAssertEqual(transform_text_telex(for: "DDuowngf"), "Đường")
  }

  /// Test "xuất" and similar words
  func testTelexXuatFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "xuaats"), "xuất")
    XCTAssertEqual(transform_text_telex(for: "xuaan"), "xuân")
    XCTAssertEqual(transform_text_telex(for: "luaatj"), "luật")
    XCTAssertEqual(transform_text_telex(for: "tuaans"), "tuấn")
  }

  /// Test "được" and similar words
  func testTelexDuocFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "dduowcj"), "được")
    XCTAssertEqual(transform_text_telex(for: "muownj"), "mượn")
    XCTAssertEqual(transform_text_telex(for: "luowts"), "lướt")
    XCTAssertEqual(transform_text_telex(for: "huowng"), "hương")
  }

  /// Test words with "iê"
  func testTelexIeFamily() throws {
    XCTAssertEqual(transform_text_telex(for: "tieengs"), "tiếng")
    XCTAssertEqual(transform_text_telex(for: "bieets"), "biết")
    XCTAssertEqual(transform_text_telex(for: "kieems"), "kiếm")
    XCTAssertEqual(transform_text_telex(for: "ddieenj"), "điện")
  }

  /// "eng" is a real rime (xẻng, kẻng) and "oe" + "o" spells "oeo", not a circumflex.
  func testEngRimeAndOeoTriphthong() {
    XCTAssertEqual(transform_text_telex(for: "xenrg"), "xẻng")
    XCTAssertEqual(transform_text_telex(for: "xengr"), "xẻng")
    XCTAssertEqual(transform_text_telex(for: "kengr"), "kẻng")
    XCTAssertEqual(transform_text_telex(for: "ngoeof"), "ngoèo")
    XCTAssertEqual(transform_text_telex(for: "khoeo"), "khoeo")
    XCTAssertEqual(transform_text_telex(for: "khuaang"), "khuâng")
  }
}
