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

  // MARK: - Regex phát hiện dừng xử lý

  /// Các pattern regex phát hiện khi nào DỪNG xử lý VNI và in ký tự gốc
  ///
  /// - `11$`, `22$`, `33$`, `44$`, `55$`, `88$`: Gõ đúp phím số → hủy dấu
  /// - `a+[a-zA-Z]*66$`: Gõ 6 lần 2 sau 'a' → hủy dấu mũ
  /// - `o+[a-zA-Z]*66$`: Tương tự cho 'o'
  /// - `e+[a-zA-Z]*66$`: Tương tự cho 'e'
  /// - `d+[a-zA-Z]*99$`: Gõ 9 lần 2 sau 'd' → hủy gạch ngang
  ///
  /// Pre-compiled for performance (avoid creating regex on every keystroke)
  private static let compiledStoppingRegex: [NSRegularExpression] = {
    let patterns = [
      "11$", "22$", "33$", "44$", "55$", "88$",
      "a+[a-zA-Z]*66$", "o+[a-zA-Z]*66$", "e+[a-zA-Z]*66$", "d+[a-zA-Z]*99$",
    ]
    return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
  }()

  // MARK: - TypingMethod Protocol

  /// Kiểm tra có nên dừng xử lý VNI không (dựa trên StoppingRegex)
  public func shouldStopProcessing(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()
    let range = NSRange(location: 0, length: lowerKeyStr.utf16.count)
    return VNI.compiledStoppingRegex.contains { regex in
      regex.firstMatch(in: lowerKeyStr, options: [], range: range) != nil
    }
  }

  /// Xử lý ký tự nhập vào theo kiểu gõ VNI
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - state: Trạng thái TiengVietState hiện tại
  /// - Returns: Tuple (state mới, có áp dụng dấu không)
  public func push(char: Character, state: TiengVietState) -> (state: TiengVietState, appliedMark: Bool) {
    let thanhPhan = state.thanhPhanTieng

    // Xử lý d9 → đ (phím 9 sau chữ d)
    if let chuCaiDau = state.chuKhongDau.first,
      (char == "9") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      return (state.withGachD(), true)
    }

    // Xử lý các phím số dấu (chỉ khi đã có nguyên âm)
    if !thanhPhan.nguyenAm.isEmpty {
      switch char {
      // Phím dấu thanh: 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng
      case "1":
        return (state.withTone(.sac), true)
      case "2":
        return (state.withTone(.huyen), true)
      case "3":
        return (state.withTone(.hoi), true)
      case "4":
        return (state.withTone(.nga), true)
      case "5":
        return (state.withTone(.nang), true)

      // Phím 6: dấu mũ (^) cho a, e, o → â, ê, ô
      case "6":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A", "o", "O", "e", "E"]) {
          return (state.withMu(.muUp), true)
        }

      // Phím 7: dấu móc (horn) cho u, o → ư, ơ
      case "7":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["u", "o", "U", "O"]) {
          return (state.withMu(.muMoc), true)
        }

      // Phím 8: dấu trăng (breve) cho a → ă
      case "8":
        if thanhPhan.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          return (state.withMu(.muNgua), true)
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
    return state.pop()
  }
}
