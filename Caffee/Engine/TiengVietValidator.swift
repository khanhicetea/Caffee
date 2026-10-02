//
//  TiengVietValidator.swift
//  Caffee
//
//  Kiểm tra tính hợp lệ của âm tiết tiếng Việt
//

import Foundation

/// TiengVietValidator - Kiểm tra cấu trúc âm tiết tiếng Việt
///
/// Phát hiện khi đầu vào không thể tạo thành âm tiết tiếng Việt hợp lệ,
/// kích hoạt recovery về chuỗi gốc.
enum TiengVietValidator {

  // MARK: - Bảng kết hợp nguyên âm + phụ âm cuối hợp lệ

  /// Quy tắc kết hợp nguyên âm với phụ âm cuối theo ngữ âm học tiếng Việt
  ///
  /// Key: nguyên âm (chữ thường)
  /// Value: tập hợp phụ âm cuối hợp lệ
  ///
  /// Ghi chú: Hầu hết nguyên âm ghép (ai, ao, au, ay, âu, ây, eo, êu, oi, ôi, ơi, ui, ưi, ưu...)
  /// KHÔNG có phụ âm cuối - chúng là nhân âm tiết hoàn chỉnh.
  static let ValidVowelEndings: [String: Set<String>] = [
    // Nguyên âm đơn - có thể kết hợp với nhiều phụ âm cuối
    "a": ["c", "ch", "m", "n", "ng", "nh", "p", "t"],
    "ă": ["c", "m", "n", "ng", "p", "t"],
    "â": ["c", "m", "n", "ng", "p", "t"],
    "e": ["c", "m", "n", "ng", "p", "t"],  // xẻng, kẻng, leng keng
    "ê": ["c", "ch", "m", "n", "nh", "p", "t"],
    "i": ["c", "ch", "m", "n", "nh", "p", "t"],
    "o": ["c", "m", "n", "ng", "p", "t"],
    "ô": ["c", "m", "n", "ng", "p", "t"],
    "ơ": ["m", "n", "p", "t"],
    "u": ["c", "m", "n", "ng", "p", "t"],
    "ư": ["c", "m", "n", "ng", "p", "t"],
    "y": ["c", "ch", "m", "n", "nh", "p", "t"],

    // Nguyên âm ghép CÓ THỂ có phụ âm cuối
    // iê/ie - tiếng, biết, kiếm, điện...
    "iê": ["c", "m", "n", "ng", "p", "t"],
    "ie": ["c", "m", "n", "ng", "p", "t"],

    // uô - cuốc, muốn, buồng...
    "uô": ["c", "m", "n", "ng", "p", "t"],
    "uo": ["c", "m", "n", "ng", "p", "t"],

    // ươ - lướt, mượn, hương...
    "ươ": ["c", "m", "n", "ng", "p", "t"],

    // oa - hoạch, toàn, khoang, loan...
    "oa": ["c", "ch", "m", "n", "ng", "nh", "p", "t"],

    // oă - xoắn, loắt...
    "oă": ["c", "m", "n", "ng", "p", "t"],

    // oe - hoen, khoét
    "oe": ["n", "t"],

    // oo - boong, xoong, soóc ("n" là bước trung gian của "ng")
    "oo": ["c", "n", "ng"],

    // uâ - luật, xuân, khuâng...
    "uâ": ["n", "ng", "t"],

    // uê - huệch, tuềnh... (hiếm); "ue" là bước trung gian khi gõ dấu mũ sau cùng
    "uê": ["c", "ch", "n", "nh"],
    "ue": ["c", "ch", "n", "nh"],

    // uy - huynh, quýt...
    "uy": ["c", "ch", "n", "nh", "p", "t"],

    // uyê - khuyên, duyệt...
    "uyê": ["n", "t"],
    "uye": ["n", "t"],

    // yê - yến, yêm...
    "yê": ["m", "n", "p", "t"],
    "ye": ["m", "n", "p", "t"],

    // Nguyên âm ghép KHÔNG có phụ âm cuối (tập rỗng)
    // Đây là các nhân âm tiết hoàn chỉnh
    "ai": [],
    "ao": [],
    "au": [],
    "ay": [],
    "âu": [],
    "ây": [],
    "eo": [],
    "eu": [],
    "êu": [],
    "ia": [],
    "io": [],
    "iu": [],
    "oi": [],
    "ôi": [],
    "ơi": [],
    "ua": [],
    "uya": [],
    "uơ": [],
    "ui": [],
    "uu": [],
    "ưa": [],
    "ưi": [],
    "ươi": [],
    "ưu": [],
    "ieu": [], "iêu": [], "yeu": [], "yêu": [],
    "oai": [], "oao": [], "oay": [], "oeo": [],
    "uay": [], "uây": [], "uoi": [], "uôi": [], "uou": [], "ươu": [], "uyu": [],
  ]

  /// Tổ hợp nguyên âm không tồn tại trong tiếng Việt
  /// Các chuỗi này cần recovery ngay lập tức
  static let InvalidVowelCombinations: Set<String> = [
    "ae", "ea", "ey", "iy", "yi", "yo", "yu",
  ]

  /// Mọi nguyên âm có dấu mũ/móc/trăng xuất hiện trong âm tiết tiếng Việt, kể cả các bước trung
  /// gian khi gõ (uâ trước khi có "n", ươ trước khi có "i"...). Dấu đặt vào nguyên âm khác
  /// (hôa, ôe, ưy...) là không hợp lệ.
  static let ValidNguyenAmCoMu: Set<String> = [
    "ă", "â", "ê", "ô", "ơ", "ư",
    "âu", "ây", "êu", "ôi", "ơi", "ưa", "ưi", "ưu",
    "iê", "yê", "uô", "ươ", "uơ", "oă", "uâ", "uê",
    "iêu", "yêu", "uôi", "ươi", "ươu", "uây", "uyê",
  ]

  /// Phụ âm cuối tắc: âm tiết kết thúc bằng các phụ âm này chỉ mang thanh sắc hoặc nặng
  static let PhuAmCuoiTac: Set<String> = ["c", "ch", "p", "t"]

  // MARK: - Phương thức kiểm tra

  /// Kiểm tra âm tiết có cần recovery không (không hợp lệ tiếng Việt)
  /// - Parameters:
  ///   - thanhPhan: Các thành phần âm tiết đã phân tích
  ///   - dauMu: Dấu mũ hiện tại (mũ, móc, trăng)
  ///   - dauThanh: Dấu thanh hiện tại
  ///   - mocCaHai: Móc cả "u" lẫn "o" của nhóm "uo"
  /// - Returns: true nếu âm tiết không hợp lệ và cần recovery
  static func needsRecovery(
    _ thanhPhan: ThanhPhanTieng,
    dauMu: DauMu = .khongMu,
    dauThanh: DauThanh = .bang,
    mocCaHai: Bool = false
  ) -> Bool {
    // Trường hợp 1: Có ký tự thừa (conLai) không khớp mẫu tiếng Việt
    if !thanhPhan.conLai.isEmpty {
      return true
    }

    // Trường hợp 2: Tổ hợp nguyên âm không hợp lệ
    let nguyenAm = String(thanhPhan.nguyenAm).lowercased()
    if InvalidVowelCombinations.contains(nguyenAm) {
      return true
    }

    // Trường hợp 3: Phụ âm đầu không đi với nguyên âm ("q" luôn đi với "u"; "gh", "ngh" chỉ
    // đứng trước e, ê, i). Không kiểm tra "k" vì có địa danh như Bắc Kạn, Kon Tum.
    if let dauNguyenAm = nguyenAm.first {
      switch String(thanhPhan.phuAmDau).lowercased() {
      case "q":
        return true
      case "gh", "ngh":
        if dauNguyenAm != "e" && dauNguyenAm != "i" { return true }
      default:
        break
      }
    }

    // Trường hợp 4: Nguyên âm sau khi đặt dấu mũ (đúng như người dùng sẽ thấy) phải tồn tại
    var coMu = thanhPhan
    TiengVietTransformer.apDungDauMu(vaoTieng: &coMu, dauMu: dauMu, mocCaHai: mocCaHai)
    let nguyenAmCoMu = String(coMu.nguyenAm).lowercased()
    if nguyenAmCoMu != nguyenAm && !ValidNguyenAmCoMu.contains(nguyenAmCoMu) {
      return true
    }

    // Trường hợp 5: Kiểm tra kết hợp nguyên âm + phụ âm cuối
    if !thanhPhan.phuAmCuoi.isEmpty {
      let phuAmCuoi = String(thanhPhan.phuAmCuoi).lowercased()

      // Phụ âm cuối tắc không mang thanh huyền, hỏi, ngã (text → tẽt là sai).
      // Thanh ngang vẫn hợp lệ vì đó là bước trung gian (tet → tết).
      if PhuAmCuoiTac.contains(phuAmCuoi), [.huyen, .hoi, .nga].contains(dauThanh) {
        return true
      }

      // Ưu tiên quy tắc của nguyên âm đã có dấu mũ ("ua" không có phụ âm cuối, "uâ" thì có),
      // sau đó tới nguyên âm gốc. Phụ âm cuối luôn hợp lệ vì được tách bằng trie.
      if let validEndings = ValidVowelEndings[nguyenAmCoMu] ?? ValidVowelEndings[nguyenAm],
        !validEndings.contains(phuAmCuoi)
      {
        return true
      }
    }

    return false
  }
}
