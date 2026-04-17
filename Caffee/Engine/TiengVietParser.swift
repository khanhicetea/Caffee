//
//  TiengVietParser.swift
//  Caffee
//
//  Hàm thuần phân tích âm tiết tiếng Việt (Pure parsing functions)
//

import Foundation

/// TiengVietParser - Hàm thuần phân tích, không có side effects
///
/// Chuyển đổi mảng ký tự chưa có dấu thành cấu trúc ThanhPhanTieng
/// Quy trình: Phụ âm đầu → Nguyên âm → Phụ âm cuối → Phần dư
enum TiengVietParser {

  // MARK: - API chính

  /// Phân tích chuỗi ký tự thành các thành phần âm tiết tiếng Việt
  /// - Parameter chuKhongDau: Mảng ký tự chưa có dấu (từ bàn phím)
  /// - Returns: ThanhPhanTieng với các thành phần đã phân tích
  static func parse(_ chuKhongDau: [Character]) -> ThanhPhanTieng {
    var result = ThanhPhanTieng()
    var remaining = String(chuKhongDau)

    guard !remaining.isEmpty else { return result }

    // Bước 1: Tách phụ âm đầu bằng Trie
    if let matched = TiengViet.PhuAmDauTrie.findLongestPrefix(in: remaining) {
      result.phuAmDau = Array(matched)
      remaining = String(remaining.dropFirst(matched.count))
    }

    // Tiếp tục với nguyên âm, phụ âm cuối, phần dư
    result = finishParsing(result: &result, remaining: remaining)

    // Xử lý đặc biệt cho "gi":
    // Trie ban đầu match "gi" như phụ âm ghép, nhưng trong tiếng Việt "gi" có ngữ nghĩa kép:
    // - Phụ âm "gi": gia, giá, giáng, giữ (gi + nguyên âm)
    // - Phụ âm "g" + nguyên âm "i": gì, gin, giếng, giết (g + i...)
    // Dùng classifyGi() để quyết định cách tách.
    if result.phuAmDau.count == 2,
       result.phuAmDau[0].lowercased() == "g",
       result.phuAmDau[1].lowercased() == "i" {
      let iChar = result.phuAmDau[1]

      switch classifyGi(
        iChar: iChar,
        originalVowel: result.nguyenAm,
        originalFinal: result.phuAmCuoi,
        originalLeftover: result.conLai
      ) {
      case .splitG:
        // "g" là phụ âm, "i" ghép vào nhóm nguyên âm
        result.phuAmDau = [result.phuAmDau[0]]
        if result.nguyenAm.isEmpty {
          // "gi", "gin" → g + i, g + i + n
          result.nguyenAm = [iChar]
        } else {
          // "giếng" → g + iê + ng, "giết" → g + iê + t
          let newRemaining = String([iChar] + result.nguyenAm + result.phuAmCuoi + result.conLai)
          result.nguyenAm = []
          result.phuAmCuoi = []
          result.conLai = []
          result = finishParsing(result: &result, remaining: newRemaining)
        }

      case .keepGi:
        // "gi" giữ nguyên là phụ âm ghép
        // "gia" → gi + a, "giáng" → gi + a + ng, "giữ" → gi + ư
        break
      }
    }

    return result
  }

  // MARK: - Hàm nội bộ

  /// Tiếp tục phân tích sau khi đã tách phụ âm đầu
  private static func finishParsing(
    result: inout ThanhPhanTieng,
    remaining: String
  ) -> ThanhPhanTieng {
    var remaining = remaining

    // Bước 2: Tách nguyên âm bằng Trie
    if let matched = TiengViet.NguyenAmTrie.findLongestPrefix(in: remaining) {
      result.nguyenAm = Array(matched)
      result.chuaNguyenAmUO = TiengViet.NguyenAmUO.contains {
        $0.lowercased() == matched.lowercased()
      }
      remaining = String(remaining.dropFirst(matched.count))
    }

    // Bước 3: Tách phụ âm cuối bằng Trie
    if let matched = TiengViet.PhuAmCuoiTrie.findLongestPrefix(in: remaining) {
      result.phuAmCuoi = Array(matched)
      remaining = String(remaining.dropFirst(matched.count))
    }

    // Bước 4: Phần còn lại (không thuộc âm tiết tiếng Việt hợp lệ)
    result.conLai = Array(remaining)
    return result
  }

  // MARK: - Phân loại "gi"

  /// Kết quả phân loại cách xử lý "gi"
  private enum GiClassification {
    /// "g" là phụ âm đầu, "i" ghép vào nhóm nguyên âm
    /// Ví dụ: gi → g+i, gin → g+i+n, giếng → g+iê+ng, giết → g+iê+t
    case splitG

    /// "gi" giữ nguyên là phụ âm ghép, phần sau là nguyên âm
    /// Ví dụ: gia → gi+a, giáng → gi+a+ng, giữ → gi+ư
    case keepGi
  }

  /// Quyết định cách xử lý "gi" dựa trên ngữ cảnh phía sau
  ///
  /// Quy tắc:
  /// 1. Không có nguyên âm sau → tách "g" + "i" (i là nguyên âm duy nhất)
  /// 2. Có nguyên âm nhưng không có phụ âm cuối → giữ "gi" (để đặt dấu đúng)
  /// 3. Có nguyên âm + phụ âm cuối → thử ghép "i" vào nguyên âm:
  ///    - Nếu kết quả hợp lệ (ie+ng) → tách "g"
  ///    - Nếu không hợp lệ (ia+ng) → giữ "gi"
  private static func classifyGi(
    iChar: Character,
    originalVowel: [Character],
    originalFinal: [Character],
    originalLeftover: [Character]
  ) -> GiClassification {
    // Trường hợp 1: Không có nguyên âm sau "gi" → "i" phải là nguyên âm
    // Ví dụ: "gi" → g+i, "gin" → g+i+n
    if originalVowel.isEmpty {
      return .splitG
    }

    // Trường hợp 2: Có nguyên âm nhưng không có phụ âm cuối → giữ "gi"
    // Để đặt dấu thanh đúng vị trí. Ví dụ: "giá" = gi+á (dấu trên 'a')
    if originalFinal.isEmpty {
      return .keepGi
    }

    // Trường hợp 3: Có nguyên âm + phụ âm cuối → thử ghép "i" vào nguyên âm
    // Dùng probe riêng để kiểm tra, không ảnh hưởng kết quả gốc
    let candidate = String([iChar] + originalVowel + originalFinal + originalLeftover)
    var probe = ThanhPhanTieng()
    probe = finishParsing(result: &probe, remaining: candidate)

    // Nếu kết quả hợp lệ (ví dụ ie+ng), tách "g"
    // Nếu không hợp lệ (ví dụ ia+ng), giữ "gi"
    if !probe.phuAmCuoi.isEmpty && !TiengVietValidator.needsRecovery(probe) {
      return .splitG
    }

    return .keepGi
  }
}
