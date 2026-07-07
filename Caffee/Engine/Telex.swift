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

  /// Xử lý ký tự nhập vào theo kiểu gõ Telex
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - keyStr: Toàn bộ chuỗi phím thô của từ hiện tại
  ///   - state: Trạng thái TiengVietState hiện tại
  /// - Returns: Kết quả xử lý với ý định rõ ràng
  public func push(char: Character, keyStr: String, state: TiengVietState) -> TypingMethodResult {
    let thanhPhan = state.thanhPhanTieng

    // Bỏ qua nếu từ có phần không hợp lệ (conLai)
    if !thanhPhan.conLai.isEmpty {
      return rawResult(state.push(char), keyStr: keyStr)
    }

    // Xử lý dd → đ (phím d gõ 2 lần)
    if let chuCaiDau = state.chuKhongDau.first,
      (char == "d" || char == "D") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      return markResult(state.withGachD(), char: char, keyStr: keyStr)
    }

    // Xử lý các phím dấu (chỉ khi đã có nguyên âm)
    if !thanhPhan.nguyenAm.isEmpty {
      switch char {
      // Phím dấu thanh: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng
      case "s", "S":
        return markResult(state.withTone(.sac), char: char, keyStr: keyStr)
      case "f", "F":
        return markResult(state.withTone(.huyen), char: char, keyStr: keyStr)
      case "r", "R":
        return markResult(state.withTone(.hoi), char: char, keyStr: keyStr)
      case "x", "X":
        return markResult(state.withTone(.nga), char: char, keyStr: keyStr)
      case "j", "J":
        return markResult(state.withTone(.nang), char: char, keyStr: keyStr)

      // Phím dấu mũ: aa=â, ee=ê, oo=ô (gõ đúp nguyên âm)
      case "a", "o", "e", "A", "O", "E":
        if thanhPhan.nguyenAmChua(char: char)
          || thanhPhan.nguyenAmChua(char: char.uppercased().first!)
        {
          return markResult(state.withMu(.muUp), char: char, keyStr: keyStr)
        }

      // Phím w: dấu móc (ơ, ư) hoặc dấu trăng (ă) tùy nguyên âm
      case "w", "W":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["u", "U"]) {
          // uw → ư (móc)
          return markResult(state.withMu(.muMoc), char: char, keyStr: keyStr)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          // aw → ă (trăng)
          return markResult(state.withMu(.muNgua), char: char, keyStr: keyStr)
        } else if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["o", "O"]) {
          // ow → ơ (móc)
          return markResult(state.withMu(.muMoc), char: char, keyStr: keyStr)
        }

      default:
        break
      }
    }

    // Không áp dụng dấu, thêm ký tự như bình thường
    return rawResult(state.push(char), keyStr: keyStr)
  }

  /// Xóa ký tự cuối cùng
  public func pop(state: TiengVietState) -> TiengVietState {
    state.pop()
  }

  // MARK: - Private Helpers

  private func rawResult(_ newState: TiengVietState, keyStr: String) -> TypingMethodResult {
    if newState.needsRecovery {
      return .recover(newState)
    }

    if shouldToggleToRaw(keyStr: keyStr) {
      return .toggleToRaw(newState)
    }

    return .insertRaw(newState)
  }

  private func markResult(
    _ newState: TiengVietState,
    char: Character,
    keyStr: String
  ) -> TypingMethodResult {
    if shouldToggleToRaw(keyStr: keyStr) {
      return .toggleToRaw(newState.push(char))
    }

    if newState.needsRecovery {
      return .recover(newState)
    }

    return .applyMark(newState)
  }

  /// Kiểm tra có nên chuyển sang chuỗi thô Telex không.
  private func shouldToggleToRaw(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()

    // 1. Check simple suffixes (double tap tone marks or w)
    if lowerKeyStr.hasSuffix("ss") || lowerKeyStr.hasSuffix("ff") ||
      lowerKeyStr.hasSuffix("rr") || lowerKeyStr.hasSuffix("xx") ||
      lowerKeyStr.hasSuffix("jj") || lowerKeyStr.hasSuffix("ww")
    {
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
}
