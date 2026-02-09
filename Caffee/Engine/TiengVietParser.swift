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
      // Trường hợp đặc biệt: "gi" cần xử lý riêng
      // - "gia", "giet" → "gi" là phụ âm đầu, tiếp tục phân tích nguyên âm
      // - "gi" đứng một mình → "g" là phụ âm đầu, "i" là nguyên âm
      if matched.lowercased() == "gi" {
        let afterGi = String(remaining.dropFirst(2))
        let hasFollowingVowel = TiengViet.NguyenAmTrie.findLongestPrefix(in: afterGi) != nil

        if hasFollowingVowel {
          // "gia", "giet" → "gi" là phụ âm đầu
          result.phuAmDau = Array(matched)
          remaining = afterGi
        } else {
          // "gi" đứng một mình → "g" là phụ âm đầu, "i" là nguyên âm
          result.phuAmDau = [matched.first!]
          result.nguyenAm = [matched.last!]
          remaining = afterGi
          // Bỏ qua bước tách nguyên âm vì đã có, tiếp tục với phụ âm cuối
          return finishParsing(result: &result, remaining: remaining, skipVowel: true)
        }
      } else {
        result.phuAmDau = Array(matched)
        remaining = String(remaining.dropFirst(matched.count))
      }
    }

    // Tiếp tục với nguyên âm, phụ âm cuối, phần dư
    return finishParsing(result: &result, remaining: remaining, skipVowel: false)
  }

  // MARK: - Hàm nội bộ

  /// Tiếp tục phân tích sau khi đã tách phụ âm đầu
  private static func finishParsing(
    result: inout ThanhPhanTieng,
    remaining: String,
    skipVowel: Bool
  ) -> ThanhPhanTieng {
    var remaining = remaining

    // Bước 2: Tách nguyên âm bằng Trie (nếu chưa có từ trường hợp "gi")
    if !skipVowel {
      if let matched = TiengViet.NguyenAmTrie.findLongestPrefix(in: remaining) {
        result.nguyenAm = Array(matched)
        result.chuaNguyenAmUO = TiengViet.NguyenAmUO.contains {
          $0.lowercased() == matched.lowercased()
        }
        remaining = String(remaining.dropFirst(matched.count))
      }
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
}
