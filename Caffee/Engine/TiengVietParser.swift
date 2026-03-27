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
    // Trong tiếng Việt, "gi" trước nguyên âm khác luôn tách thành phụ âm "g" + "i" thuộc nguyên âm.
    // Ví dụ: "giếng" = g + iê + ng, "gia" = g + ia, "giết" = g + iê + t
    // Nếu không có nguyên âm nào sau "gi", thì "i" chính là nguyên âm: "gì" = g + i
    if result.phuAmDau.count == 2,
       result.phuAmDau[0] == "g" || result.phuAmDau[0] == "G",
       result.phuAmDau[1] == "i" || result.phuAmDau[1] == "I" {
      let iChar = result.phuAmDau[1]
      result.phuAmDau = [result.phuAmDau[0]]

      if result.nguyenAm.isEmpty {
        // "gi" đứng một mình hoặc trước phụ âm: "i" là nguyên âm
        // Ví dụ: "gi", "gin" → g + i, g + i + n
        result.nguyenAm = [iChar]
      } else if !result.phuAmCuoi.isEmpty {
        // "gi" trước nguyên âm + phụ âm cuối: thử ghép "i" vào đầu nguyên âm
        // Ví dụ: "gieng" → g + ie + ng (vì ê+ng không hợp lệ, nhưng iê+ng hợp lệ)
        // Nhưng: "giang" → gi + a + ng (vì ia+ng không hợp lệ, a+ng hợp lệ)
        let savedNguyenAm = result.nguyenAm
        let savedPhuAmCuoi = result.phuAmCuoi
        let savedConLai = result.conLai
        let savedChuaNguyenAmUO = result.chuaNguyenAmUO

        let newRemaining = String([iChar] + savedNguyenAm + savedPhuAmCuoi + savedConLai)
        result.nguyenAm = []
        result.phuAmCuoi = []
        result.conLai = []
        result = finishParsing(result: &result, remaining: newRemaining)

        // Kiểm tra kết quả mới có hợp lệ hơn không
        // Nếu không hợp lệ (ví dụ ia+ng), khôi phục lại gi + vowel + final
        if !result.phuAmCuoi.isEmpty &&
           TiengVietValidator.needsRecovery(result) {
          result.phuAmDau = [result.phuAmDau[0], iChar]
          result.nguyenAm = savedNguyenAm
          result.phuAmCuoi = savedPhuAmCuoi
          result.conLai = savedConLai
          result.chuaNguyenAmUO = savedChuaNguyenAmUO
        }
      } else {
        // "gi" trước nguyên âm mà không có phụ âm cuối: giữ "i" riêng ở phụ âm đầu
        // để đặt dấu thanh đúng vị trí. Ví dụ: "giá" = gi + á (dấu trên 'a')
        result.phuAmDau = [result.phuAmDau[0], iChar]
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
}
