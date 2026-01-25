//
//  TiengVietTransformer.swift
//  Caffee
//
//  Pure transformation functions for Vietnamese syllables
//

import Foundation

/// TiengVietTransformer - Pure transformation functions
enum TiengVietTransformer {

  /// Transform parsed syllable components into Vietnamese text with diacritics
  /// - Parameters:
  ///   - thanhPhanTieng: The parsed syllable components
  ///   - dauThanh: The tone mark to apply
  ///   - dauMu: The diacritical mark to apply
  ///   - gachD: Whether to apply the stroke to 'd'
  /// - Returns: Transformed string with diacritics
  static func transform(
    thanhPhanTieng: ThanhPhanTieng,
    dauThanh: DauThanh,
    dauMu: DauMu,
    gachD: Bool
  ) -> String {
    // Clone to avoid mutating original
    var tieng = thanhPhanTieng
    let countNguyenAm = tieng.nguyenAm.count

    if tieng.phuAmDau.isEmpty && tieng.nguyenAm.isEmpty && tieng.phuAmCuoi.isEmpty && tieng.conLai.isEmpty {
      return ""
    }

    // Step 1: Apply stroke to D (d -> d)
    apDungGachD(vaoTieng: &tieng, gachD: gachD)

    // Step 2: Apply diacritical mark
    apDungDauMu(vaoTieng: &tieng, dauMu: dauMu, soNguyenAm: countNguyenAm)

    // Step 3: Apply tone mark
    apDungDauThanh(vaoTieng: &tieng, dauThanh: dauThanh, soNguyenAm: countNguyenAm)

    return String(tieng.phuAmDau + tieng.nguyenAm + tieng.phuAmCuoi + tieng.conLai)
  }

  /// Apply stroke to D (d -> d)
  private static func apDungGachD(vaoTieng tieng: inout ThanhPhanTieng, gachD: Bool) {
    if gachD,
       let kyTuPhuAmDau = tieng.phuAmDau.first,
       let kyTuMoi = chuyenKyTu(kytu: kyTuPhuAmDau, quyTac: TiengViet.QuyTacGachD)
    {
      tieng.phuAmDau[0] = kyTuMoi
    }
  }

  /// Apply diacritical mark (circumflex, horn, breve)
  private static func apDungDauMu(vaoTieng tieng: inout ThanhPhanTieng, dauMu: DauMu, soNguyenAm: Int) {
    guard let quyTac = TiengViet.QuyTacDatMu[dauMu], !quyTac.isEmpty else { return }

    func thuDatDauMu(_ idx: Int) -> Bool {
      if let kyTuMoi = chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
        tieng.nguyenAm[idx] = kyTuMoi
        tieng.viTriDauMu = idx
        return true
      }
      return false
    }

    let datDauMocUO = (dauMu == .muMoc) && tieng.chuaNguyenAmUO

    if datDauMocUO && thuDatDauMu(1) {
      if soNguyenAm == 3 || !tieng.phuAmCuoi.isEmpty,
         let dauU = chuyenKyTu(kytu: tieng.nguyenAm[0], quyTac: quyTac)
      {
        tieng.nguyenAm[0] = dauU
      }
    } else if (soNguyenAm == 3 || (soNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty)) && thuDatDauMu(1) {
      // Success - placed on second vowel
    } else {
      for i in 0..<soNguyenAm {
        if thuDatDauMu(i) { break }
      }
    }
  }

  /// Apply tone mark
  private static func apDungDauThanh(vaoTieng tieng: inout ThanhPhanTieng, dauThanh: DauThanh, soNguyenAm: Int) {
    guard let quyTac = TiengViet.QuyTacDatDau[dauThanh], !quyTac.isEmpty else { return }

    func thuDatDauThanh(_ idx: Int) -> Bool {
      if let kyTuMoi = chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
        tieng.nguyenAm[idx] = kyTuMoi
        tieng.viTriDauThanh = idx
        return true
      }
      return false
    }

    if tieng.viTriDauMu > -1 && thuDatDauThanh(tieng.viTriDauMu) {
      return
    }
    if (soNguyenAm == 3 || (soNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty)) && thuDatDauThanh(1) {
      return
    }
    for i in 0..<soNguyenAm {
      if thuDatDauThanh(i) { break }
    }
  }

  /// Convert character according to transformation rules
  private static func chuyenKyTu(kytu: Character, quyTac: [(Character, Character)]) -> Character? {
    for (match, to) in quyTac {
      if match == kytu {
        return to
      }
    }
    return nil
  }
}
