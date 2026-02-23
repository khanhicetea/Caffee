//
//  Telex.swift
//  Caffee
//
//  Created by KhanhIceTea on 17/02/2024.
//

/// Telex - Kiểu gõ tiếng Việt phổ biến nhất
///
/// Bảng phím Telex:
/// ┌─────────────────────────────────────────────────────────┐
/// │ Phím dấu thanh (Tone marks):                            │
/// │   s = sắc (´)  - má                                     │
/// │   f = huyền (`) - mà                                    │
/// │   r = hỏi (ˀ)  - mả                                     │
/// │   x = ngã (~)  - mã                                     │
/// │   j = nặng (.) - mạ                                     │
/// ├─────────────────────────────────────────────────────────┤
/// │ Phím dấu mũ (Diacritical marks):                        │
/// │   aa = â (mũ)         - cân                             │
/// │   ee = ê (mũ)         - bên                             │
/// │   oo = ô (mũ)         - tôi                             │
/// │   aw = ă (trăng)      - ăn                              │
/// │   ow = ơ (móc)        - ơi                              │
/// │   uw = ư (móc)        - ưa                              │
/// │   w  = ơ/ư tùy ngữ cảnh - tươi = tuowi                  │
/// ├─────────────────────────────────────────────────────────┤
/// │ Phím đặc biệt:                                          │
/// │   dd = đ (gạch ngang) - đi                              │
/// └─────────────────────────────────────────────────────────┘
///
/// Quy tắc hủy dấu (gõ đúp):
/// - Gõ đúp phím dấu thanh (ss, ff, rr, xx, jj) → hủy dấu, in ký tự gốc
/// - Gõ đúp nguyên âm sau khi đã có (aaa, ooo, eee) → in nguyên âm thường
/// - Gõ ww → hủy dấu móc/trăng

import Foundation

class Telex: TypingMethod {

  // MARK: - TypingMethod Protocol

  /// Kiểm tra có nên dừng xử lý Telex không
  public func shouldStopProcessing(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()

    // 1. Check simple suffixes (double tap tone marks or w)
    if lowerKeyStr.hasSuffix("ss") || lowerKeyStr.hasSuffix("ff") ||
       lowerKeyStr.hasSuffix("rr") || lowerKeyStr.hasSuffix("xx") ||
       lowerKeyStr.hasSuffix("jj") || lowerKeyStr.hasSuffix("ww") {
      return true
    }

    // 2. Check digit suffix
    if let lastChar = lowerKeyStr.last, lastChar.isNumber {
      return true
    }
      
    // 3. Check complex cases (double tap vowel/d when it already exists)
    // "aa", "oo", "ee", "dd" -> Cancel mark if the character exists before
    
    // Check "aa" suffix: requires 'a' to exist previously
    if lowerKeyStr.hasSuffix("aa") {
      // Check content before suffix for 'a'
      return lowerKeyStr.dropLast(2).contains("a")
    }
    
    // Check "oo" suffix: requires 'o' to exist previously
    if lowerKeyStr.hasSuffix("oo") {
      return lowerKeyStr.dropLast(2).contains("o")
    }
    
    // Check "ee" suffix: requires 'e' to exist previously
    if lowerKeyStr.hasSuffix("ee") {
      return lowerKeyStr.dropLast(2).contains("e")
    }
    
    // Check "dd" suffix: requires 'd' to exist previously at the start of the word
    if lowerKeyStr.hasSuffix("dd") {
      return lowerKeyStr.dropLast(2).hasPrefix("d")
    }

    return false
  }

  /// Xử lý ký tự nhập vào theo kiểu gõ Telex
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - state: Trạng thái TiengVietState hiện tại
  /// - Returns: Tuple (state mới, có áp dụng dấu không)
  public func push(char: Character, state: TiengVietState) -> (state: TiengVietState, appliedMark: Bool) {
    let thanhPhan = state.thanhPhanTieng

    // Bỏ qua nếu từ có phần không hợp lệ (conLai)
    if !thanhPhan.conLai.isEmpty {
      return (state.push(char), false)
    }

    // Xử lý dd → đ (phím d gõ 2 lần)
    if let chuCaiDau = state.chuKhongDau.first,
      (char == "d" || char == "D") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      return (state.withGachD(), true)
    }

    // Xử lý các phím dấu (chỉ khi đã có nguyên âm)
    if !thanhPhan.nguyenAm.isEmpty {
      switch char {
      // Phím dấu thanh: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng
      case "s", "S":
        return (state.withTone(.sac), true)
      case "f", "F":
        return (state.withTone(.huyen), true)
      case "r", "R":
        return (state.withTone(.hoi), true)
      case "x", "X":
        return (state.withTone(.nga), true)
      case "j", "J":
        return (state.withTone(.nang), true)

      // Phím dấu mũ: aa=â, ee=ê, oo=ô (gõ đúp nguyên âm)
      case "a", "o", "e", "A", "O", "E":
        if thanhPhan.nguyenAmChua(char: char)
          || thanhPhan.nguyenAmChua(char: char.uppercased().first!)
        {
          return (state.withMu(.muUp), true)
        }

      // Phím w: dấu móc (ơ, ư) hoặc dấu trăng (ă) tùy nguyên âm
      case "w", "W":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["u", "U"]) {
          // uw → ư (móc)
          return (state.withMu(.muMoc), true)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          // aw → ă (trăng)
          return (state.withMu(.muNgua), true)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["o", "O"]) {
          // ow → ơ (móc)
          return (state.withMu(.muMoc), true)
        }

      default:
        break
      }
    }

    // Không áp dụng dấu, thêm ký tự như bình thường
    return (state.push(char), false)
  }

  /// Xóa ký tự cuối cùng
  public func pop(state: TiengVietState) -> TiengVietState {
    state.pop()
  }
}
