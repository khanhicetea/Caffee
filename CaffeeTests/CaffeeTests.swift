//
//  CaffeeTests.swift
//  CaffeeTests
//
//  Created by KhanhIceTea on 20/02/2024.
//

import XCTest

@testable import Caffee

final class CaffeeTests: XCTestCase {

  override func setUp() {

  }

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  public func transform_text_telex(for text: String) -> String {
    var p_ret: [String] = []
    let inputProcessor = InputProcessor(method: .Telex)

    for word in text.split(separator: " ") {
      inputProcessor.newWord()
      for c in word {
        inputProcessor.push(char: c)
      }
      p_ret.append(inputProcessor.transformed)
    }

    return p_ret.joined(separator: " ")
  }

  public func transform_text_vni(for text: String) -> String {
    var p_ret: [String] = []
    let inputProcessor = InputProcessor(method: .VNI)

    for word in text.split(separator: " ") {
      inputProcessor.newWord()
      for c in word {
        inputProcessor.push(char: c)
      }
      p_ret.append(inputProcessor.transformed)
    }

    return p_ret.joined(separator: " ")
  }

  func testExample() throws {
    //    var transformed = telex.transform_text(for: "xin chaof tatas car cacs banj")
    //    XCTAssertEqual(transformed, "xin chào tất cả các bạn")
    //
    //    transformed = telex.transform_text(for: "hahaa")
    //    XCTAssertEqual(transformed, "haha")

    let tv1 = self.transform_text_telex(
      for:
        "vn-index giarm gaafn 12 ddieerm trong phieen ddaafu tieen, khi aps lucwj ans tangw votj trong phieen chieeuf eps mootj loatj coor phieeus chuyeern mauf tuwf xanh sang dodr. noios tieeps phieen giarm cuoios tuaafn truocws, chungws khoans mowr cuawr hoom nay trong trangj thais thaanj trongj. vn-index bieens dodongj gaafn tham chieeus truocws khi batja leen gaanf 1.255 diemder. thanh khoangr owr mucws trung binhf, cungf voiws bieen dodoj hepj cuar nhieefu max truj cho thaasy suwj giangwf co cuar thij truongwf. trangj thais nayf duocwjd duy trif cho toiws ddaafu phieen chieefu, truocws khi thij truongwf noior gios. gaafn 14h, aps lucwj bans ra tangw votj owr nhoms vn30 sau ddos lan roongj ra toanf thij truongwf. coor phieeus nhoms ngaan hangf, bans ler bij keos luif saau khieens thij truongwf phas vowx thees giangwf co. sucws eps xar hangf tangw manhj khieens thij truongwf lieen tieeps luif saua, vn-index choots phieen truocws. vn30-index maarts honw 15 ddieerm 91,250, xuoongs 1.235,12 ddieerm. treen sanf haf noioj, hnx-index sutj honw 15."
    )

    XCTAssertEqual(
      tv1,
      "vn-index giảm gần 12 điểm trong phiên đầu tiên, khi áp lực án tăng vọt trong phiên chiều ép một loạt cổ phiếu chuyển màu từ xanh sang đỏ. nối tiếp phiên giảm cuối tuần trước, chứng khoán mở cửa hôm nay trong trạng thái thận trọng. vn-index biến động gần tham chiếu trước khi bật lên gần 1.255 điểm. thanh khoảng ở mức trung bình, cùng với biên độ hẹp của nhiều mã trụ cho thấy sự giằng co của thị trường. trạng thái này được duy trì cho tới đầu phiên chiều, trước khi thị trường nổi gió. gần 14h, áp lực bán ra tăng vọt ở nhóm vn30 sau đó lan rộng ra toàn thị trường. cổ phiếu nhóm ngân hàng, bán lẻ bị kéo lùi sâu khiến thị trường phá vỡ thế giằng co. sức ép xả hàng tăng mạnh khiến thị trường liên tiếp lùi sâu, vn-index chốt phiên trước. vn30-index mất hơn 15 điểm 91,250, xuống 1.235,12 điểm. trên sàn hà nội, hnx-index sụt hơn 15."
    )

  }

  func testPerformance() throws {
    // This is an example of a performance test case.
    //    self.measure {
    //      for _ in 0...1000 {
    //        telex.clear()
    //        let transformed = telex.transform_text(for: "xin chaof tatas car cacs banj")
    //        assert(transformed == "xin chào tất cả các bạn")
    //      }
    //    }
  }

  // MARK: - "gi" Special Case Tests

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

  // MARK: - Functional State Immutability Tests

  /// Test that state mutations return new state without affecting original
  func testImmutability() throws {
    let state1 = TiengVietState.empty.push("a")
    let state2 = state1.withTone(.sac)

    XCTAssertEqual(state1.transformed, "a")   // Original unchanged
    XCTAssertEqual(state2.transformed, "á")   // New state has tone
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

  // MARK: - Vietnamese Text Transformation Tests

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

  /// Test "khong" with Telex
  func testKhongTelex() throws {
    let result = transform_text_telex(for: "khoong")
    XCTAssertEqual(result, "không")
  }

}
