//
//  VNI.swift
//  Caffee
//
//  Created by KhanhIceTea on 17/02/2024.
//

/// VNI - Kiểu gõ tiếng Việt sử dụng phím số
///
/// Bảng phím VNI:
/// ┌─────────────────────────────────────────────────────────┐
/// │ Phím số đặt dấu thanh (Tone marks):                     │
/// │   1 = sắc (´)  - ma1 → má                               │
/// │   2 = huyền (`) - ma2 → mà                              │
/// │   3 = hỏi (ˀ)  - ma3 → mả                               │
/// │   4 = ngã (~)  - ma4 → mã                               │
/// │   5 = nặng (.) - ma5 → mạ                               │
/// ├─────────────────────────────────────────────────────────┤
/// │ Phím số đặt dấu mũ (Diacritical marks):                 │
/// │   6 = mũ (^) cho a, e, o → â, ê, ô                      │
/// │       Ví dụ: a6 → â, e6 → ê, o6 → ô                     │
/// │   7 = móc (horn) cho u, o → ư, ơ                        │
/// │       Ví dụ: u7 → ư, o7 → ơ                             │
/// │   8 = trăng (breve) cho a → ă                           │
/// │       Ví dụ: a8 → ă                                     │
/// ├─────────────────────────────────────────────────────────┤
/// │ Phím đặc biệt:                                          │
/// │   9 = gạch ngang (stroke) cho d → đ                     │
/// │       Ví dụ: d9i → đi                                   │
/// └─────────────────────────────────────────────────────────┘
///
/// Quy tắc hủy dấu (gõ đúp):
/// - Gõ đúp phím số (11, 22, 33, 44, 55, 88) → hủy dấu, in số
/// - a66, o66, e66 → hủy dấu mũ, in số 6
/// - d99 → hủy gạch ngang, in số 9

import Foundation

class VNI: TypingMethod {

  // MARK: - TypingMethod Protocol

  /// Xử lý ký tự nhập vào theo kiểu gõ VNI
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - keyStr: Toàn bộ chuỗi phím thô của từ hiện tại
  ///   - state: Trạng thái TiengVietState hiện tại
  /// - Returns: Kết quả xử lý với ý định rõ ràng
  public func push(char: Character, keyStr: String, state: TiengVietState) -> TypingMethodResult {
    let thanhPhan = state.thanhPhanTieng

    // Xử lý d9 → đ (phím 9 sau chữ d)
    if let chuCaiDau = state.chuKhongDau.first,
      (char == "9") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      return markResult(state.withGachD(), char: char, keyStr: keyStr)
    }

    // Xử lý các phím số dấu (chỉ khi đã có nguyên âm)
    if !thanhPhan.nguyenAm.isEmpty {
      switch char {
      // Phím dấu thanh: 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng
      case "1":
        return markResult(state.withTone(.sac), char: char, keyStr: keyStr)
      case "2":
        return markResult(state.withTone(.huyen), char: char, keyStr: keyStr)
      case "3":
        return markResult(state.withTone(.hoi), char: char, keyStr: keyStr)
      case "4":
        return markResult(state.withTone(.nga), char: char, keyStr: keyStr)
      case "5":
        return markResult(state.withTone(.nang), char: char, keyStr: keyStr)

      // Phím 6: dấu mũ (^) cho a, e, o → â, ê, ô
      case "6":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A", "o", "O", "e", "E"]) {
          return markResult(state.withMu(.muUp), char: char, keyStr: keyStr)
        }

      // Phím 7: dấu móc (horn) cho u, o → ư, ơ
      case "7":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["u", "o", "U", "O"]) {
          return markResult(state.withMu(.muMoc), char: char, keyStr: keyStr)
        }

      // Phím 8: dấu trăng (breve) cho a → ă
      case "8":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          return markResult(state.withMu(.muNgua), char: char, keyStr: keyStr)
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
    return state.pop()
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

  /// Kiểm tra có nên chuyển sang chuỗi thô VNI không.
  private func shouldToggleToRaw(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()

    // 1. Check simple suffixes (double tap tone marks)
    let simpleSuffixes = ["11", "22", "33", "44", "55", "77", "88"]
    if simpleSuffixes.contains(where: { lowerKeyStr.hasSuffix($0) }) {
      return true
    }

    // 2. Check complex cases (double tap vowel/d when it already exists)
    // "66", "99" -> Cancel mark if the character exists before

    // Check "66" suffix: requires 'a', 'e', or 'o' to exist previously (circumflex)
    if lowerKeyStr.hasSuffix("66") {
      return lowerKeyStr.contains("a") || lowerKeyStr.contains("e") || lowerKeyStr.contains("o")
    }

    // Check "99" suffix: requires 'd' to exist previously (stroked d)
    if lowerKeyStr.hasSuffix("99") {
      return lowerKeyStr.hasPrefix("d")
    }

    return false
  }
}
