//
//  VNI.swift
//
//
//  Created by KhanhIceTea on 17/02/2024.
//

import Foundation

class VNI: TypingMethod {
  static let StoppingRegex: [String] = [
    "11$", "22$", "33$", "44$", "55$", "88$",
    "a+[a-zA-Z]*66$", "o+[a-zA-Z]*66$", "e+[a-zA-Z]*66$", "d+[a-zA-Z]*99$",
  ]

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

  public func push(char: Character, to word: TiengViet) -> Bool {
    var daDatDau = false

    if let chuCaiDau = word.chuKhongDau.first,
      (char == "9") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      word.datGachD()
      daDatDau = true
    } else if !(word.thanhPhanTieng.nguyenAm.isEmpty) {
      daDatDau = true
      switch char {
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
      case "6":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["a", "A", "o", "O", "e", "E"]) {
          word.datMu(dauMuMoi: .muUp)
        } else {
          daDatDau = false
        }
      case "7":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["u", "o", "U", "O"]) {
          word.datMu(dauMuMoi: .muMoc)
        } else {
          daDatDau = false
        }
      case "8":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          word.datMu(dauMuMoi: .muNgua)
        } else {
          daDatDau = false
        }
      default:
        daDatDau = false
      }
    }

    if !daDatDau {
      word.push(letter: char)
    }

    return daDatDau
  }

  public func pop(from word: TiengViet) -> Character? {
    return word.pop()
  }
}
