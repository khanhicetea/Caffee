//
//  Telex.swift
//
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
/// │   aa = â (circumflex)   - cân                           │
/// │   ee = ê (circumflex)   - bên                           │
/// │   oo = ô (circumflex)   - tôi                           │
/// │   aw = ă (breve)        - ăn                            │
/// │   ow = ơ (horn)         - ơi                            │
/// │   uw = ư (horn)         - ưa                            │
/// │   w  = ơ/ư tùy ngữ cảnh - tươi = tuowi                  │
/// ├─────────────────────────────────────────────────────────┤
/// │ Phím đặc biệt:                                          │
/// │   dd = đ (stroke)       - đi                            │
/// └─────────────────────────────────────────────────────────┘
///
/// Quy tắc hủy dấu (gõ đúp):
/// - Gõ đúp phím dấu thanh (ss, ff, rr, xx, jj) → hủy dấu, in ký tự gốc
/// - Gõ đúp nguyên âm sau khi đã có (aaa, ooo, eee) → in nguyên âm thường
/// - Gõ ww → hủy dấu móc/trăng

import Foundation

class Telex: TypingMethod {

  // MARK: - Stopping Patterns

  /// Regex phát hiện khi nào DỪNG xử lý Telex và in ký tự gốc
  ///
  /// Các pattern:
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
  ///   - word: Đối tượng TiengViet đang xử lý
  /// - Returns: true nếu đã áp dụng dấu, false nếu chỉ thêm ký tự thường
  public func push(char: Character, to word: TiengViet) -> Bool {
    var daApDungDau = false

    // Bỏ qua nếu từ có phần không hợp lệ (conLai)
    if !word.thanhPhanTieng.conLai.isEmpty {
      // Không xử lý, để thêm ký tự thường
    }
    // Xử lý dd → đ (phím d gõ 2 lần)
    else if let chuCaiDau = word.chuKhongDau.first,
      (char == "d" || char == "D") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      word.datGachD()
      daApDungDau = true
    }
    // Xử lý các phím dấu (chỉ khi đã có nguyên âm)
    else if !(word.thanhPhanTieng.nguyenAm.isEmpty) {
      daApDungDau = true
      switch char {
      // Phím dấu thanh: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng
      case "s", "S":
        word.datDauThanh(dauThanhMoi: .sac)
      case "f", "F":
        word.datDauThanh(dauThanhMoi: .huyen)
      case "r", "R":
        word.datDauThanh(dauThanhMoi: .hoi)
      case "x", "X":
        word.datDauThanh(dauThanhMoi: .nga)
      case "j", "J":
        word.datDauThanh(dauThanhMoi: .nang)

      // Phím dấu mũ: aa=â, ee=ê, oo=ô (gõ đúp nguyên âm)
      case "a", "o", "e", "A", "O", "E":
        if word.thanhPhanTieng.nguyenAmChua(char: char)
          || word.thanhPhanTieng.nguyenAmChua(char: char.uppercased().first!)
        {
          word.datMu(dauMuMoi: .muUp)
        } else {
          daApDungDau = false
        }

      // Phím w: dấu móc (ơ, ư) hoặc dấu trăng (ă) tùy nguyên âm
      case "w", "W":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["u", "U"]) {
          // uw → ư (horn)
          word.datMu(dauMuMoi: .muMoc)
        } else if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          // aw → ă (breve)
          word.datMu(dauMuMoi: .muNgua)
        } else if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["o", "O"]) {
          // ow → ơ (horn)
          word.datMu(dauMuMoi: .muMoc)
        } else {
          daApDungDau = false
        }

      default:
        daApDungDau = false
      }
    }

    // Nếu không áp dụng dấu, thêm ký tự như bình thường
    if !daApDungDau {
      word.push(letter: char)
    }

    return daApDungDau
  }

  /// Xóa ký tự cuối cùng
  public func pop(from word: TiengViet) -> Character? {
    word.pop()
  }

}
