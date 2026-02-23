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
    // Nếu phụ âm đầu là "gi" mà không tìm thấy nguyên âm (ví dụ: "gi", "gin"),
    // thì "i" trong "gi" chính là nguyên âm.
    // Chuyển "gi" -> phụ âm "g" + nguyên âm "i".
    if result.phuAmDau.count == 2,
       result.phuAmDau[0] == "g" || result.phuAmDau[0] == "G",
       result.phuAmDau[1] == "i" || result.phuAmDau[1] == "I",
       result.nguyenAm.isEmpty {
      let iChar = result.phuAmDau[1]
      result.phuAmDau = [result.phuAmDau[0]]
      result.nguyenAm = [iChar]
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
}
