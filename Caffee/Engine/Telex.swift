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

  // MARK: - Regex phát hiện dừng xử lý

  /// Các pattern regex phát hiện khi nào DỪNG xử lý Telex và in ký tự gốc
  ///
  /// - `ss$`, `ff$`, `rr$`, `xx$`, `jj$`, `ww$`: Gõ đúp phím dấu → hủy dấu
  /// - `[0-9]$`: Gõ số → dừng xử lý tiếng Việt
  /// - `a+[a-zA-Z]*aa$`: Gõ 'a' thứ 3 sau khi đã có 'â' → in 'a' thường
  /// - `o+[a-zA-Z]*oo$`: Tương tự cho 'o'
  /// - `e+[a-zA-Z]*ee$`: Tương tự cho 'e'
  /// - `d+[a-zA-Z]*dd$`: Gõ 'd' thứ 3 → hủy 'đ', in 'd' thường
  static let StoppingRegex: [String] = [
    "ss$", "ff$", "rr$", "xx$", "jj$", "ww$", "[0-9]$",
    "a+[a-zA-Z]*aa$", "o+[a-zA-Z]*oo$", "e+[a-zA-Z]*ee$", "d+[a-zA-Z]*dd$",
  ]

  // MARK: - TypingMethod Protocol

  /// Kiểm tra có nên dừng xử lý Telex không (dựa trên StoppingRegex)
  public func shouldStopProcessing(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()
    if let _ = Telex.StoppingRegex.firstIndex(where: { str in
      let regex = try? NSRegularExpression(pattern: str)
      let range = NSRange(location: 0, length: lowerKeyStr.utf16.count)
      return regex?.firstMatch(in: lowerKeyStr, options: [], range: range) != nil
    }) {
      return true
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
