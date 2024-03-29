//
//  Telex.swift
//
//
//  Created by KhanhIceTea on 17/02/2024.
//

import Foundation

class Telex: TypingMethod {

  static let StoppingRegex: [String] = [
    "ss$", "ff$", "rr$", "xx$", "jj$", "ww$", "[0-9]$",
    "a+[a-zA-Z]*aa$", "o+[a-zA-Z]*oo$", "e+[a-zA-Z]*ee$", "d+[a-zA-Z]*dd$",
  ]

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

  public func push(char: Character, to word: TiengViet) -> Bool {
    var daDatDau = false

    if !word.thanhPhanTieng.conLai.isEmpty {

    } else if let chuCaiDau = word.chuKhongDau.first,
      (char == "d" || char == "D") && (chuCaiDau == "d" || chuCaiDau == "D")
    {
      word.datGachD()
      daDatDau = true
    } else if !(word.thanhPhanTieng.nguyenAm.isEmpty) {
      daDatDau = true
      switch char {
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
      case "a", "o", "e", "A", "O", "E":
        if word.thanhPhanTieng.nguyenAmChua(char: char)
          || word.thanhPhanTieng.nguyenAmChua(char: char.uppercased().first!)
        {
          word.datMu(dauMuMoi: .muUp)
        } else {
          daDatDau = false
        }
      case "w", "W":
        if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["u", "U"]) {
          word.datMu(dauMuMoi: .muMoc)
        } else if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["a", "A"]) {
          word.datMu(dauMuMoi: .muNgua)
        } else if word.thanhPhanTieng.nguyenAmChua1KyTu(mangKyTu: ["o", "O"]) {
          word.datMu(dauMuMoi: .muMoc)
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
    word.pop()
  }

}
