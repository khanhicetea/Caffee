//
//  VNI.swift
//
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

  // MARK: - Stopping Patterns

  /// Regex phát hiện khi nào DỪNG xử lý VNI và in ký tự gốc
  ///
  /// Các pattern:
  /// - `11$`, `22$`, `33$`, `44$`, `55$`, `88$`: Gõ đúp phím số → hủy dấu
  /// - `a+[a-zA-Z]*66$`: Gõ 6 lần 2 sau 'a' → hủy dấu mũ
  /// - `o+[a-zA-Z]*66$`: Tương tự cho 'o'
  /// - `e+[a-zA-Z]*66$`: Tương tự cho 'e'
  /// - `d+[a-zA-Z]*99$`: Gõ 9 lần 2 sau 'd' → hủy gạch ngang
  static let StoppingRegex: [String] = [
    "11$", "22$", "33$", "44$", "55$", "88$",
    "a+[a-zA-Z]*66$", "o+[a-zA-Z]*66$", "e+[a-zA-Z]*66$", "d+[a-zA-Z]*99$",
  ]

  // MARK: - TypingMethod Protocol

  /// Kiểm tra có nên dừng xử lý VNI không (dựa trên StoppingRegex)
  public func shouldStopProcessing(keyStr: String) -> Bool {
    let lowerKeyStr = keyStr.lowercased()
    if let _ = VNI.StoppingRegex.firstIndex(where: { str in
      let regex = try? NSRegularExpression(pattern: str)
      let range = NSRange(location: 0, length: lowerKeyStr.utf16.count)
      return regex?.firstMatch(in: lowerKeyStr, options: [], range: range) != nil
    }) {
      return true
    }
    return false
  }

  /// Xử lý ký tự nhập vào theo kiểu gõ VNI
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - word: Đối tượng TiengViet đang xử lý
  /// - Returns: true nếu đã áp dụng dấu, false nếu chỉ thêm ký tự thường
  public func push(char: Character, to word: TiengViet) -> Bool {
    var daApDungDau = false

    // Xử lý d9 → đ (phím 9 sau chữ d)
    if let chuCaiDau = word.chuKhongDau.first,
      (char == "9") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      word.datGachD()
      daApDungDau = true
    }
    // Xử lý các phím số dấu (chỉ khi đã có nguyên âm)
    else if !(word.thanhPhanTieng.nguyenAm.isEmpty) {
      daApDungDau = true
      switch char {
      // Phím dấu thanh: 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng
      case "1":
        word.datDauThanh(dauThanhMoi: .sac)
      case "2":
        word.datDauThanh(dauThanhMoi: .huyen)
      case "3":
        word.datDauThanh(dauThanhMoi: .hoi)
      case "4":
        word.datDauThanh(dauThanhMoi: .nga)
      case "5":
        word.datDauThanh(dauThanhMoi: .nang)

      // Phím 6: dấu mũ (^) cho a, e, o → â, ê, ô
      case "6":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["a", "A", "o", "O", "e", "E"]) {
          word.datMu(dauMuMoi: .muUp)
        } else {
          daApDungDau = false
        }

      // Phím 7: dấu móc (horn) cho u, o → ư, ơ
      case "7":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["u", "o", "U", "O"]) {
          word.datMu(dauMuMoi: .muMoc)
        } else {
          daApDungDau = false
        }

      // Phím 8: dấu trăng (breve) cho a → ă
      case "8":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          word.datMu(dauMuMoi: .muNgua)
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
    return word.pop()
  }
}
