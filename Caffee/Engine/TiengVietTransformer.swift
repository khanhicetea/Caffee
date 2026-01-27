//
//  TiengVietTransformer.swift
//  Caffee
//
//  Hàm thuần biến đổi âm tiết tiếng Việt (Pure transformation functions)
//

import Foundation

/// TiengVietTransformer - Hàm thuần biến đổi
///
/// Chuyển đổi ThanhPhanTieng thành chuỗi tiếng Việt có dấu
/// Quy trình: Gạch D → Dấu mũ → Dấu thanh → Ghép chuỗi
enum TiengVietTransformer {

  // MARK: - API chính

  /// Biến đổi các thành phần âm tiết thành chuỗi tiếng Việt có dấu
  /// - Parameters:
  ///   - thanhPhanTieng: Các thành phần âm tiết đã phân tích
  ///   - dauThanh: Dấu thanh cần đặt (sắc, huyền, hỏi, ngã, nặng)
  ///   - dauMu: Dấu mũ cần đặt (mũ, móc, trăng)
  ///   - gachD: Có gạch ngang chữ D không (d → đ)
  /// - Returns: Chuỗi tiếng Việt đã biến đổi với dấu
  static func transform(
    thanhPhanTieng: ThanhPhanTieng,
    dauThanh: DauThanh,
    dauMu: DauMu,
    gachD: Bool
  ) -> String {
    // Clone để không thay đổi bản gốc
    var tieng = thanhPhanTieng
    let countNguyenAm = tieng.nguyenAm.count

    // Kiểm tra chuỗi rỗng
    if tieng.phuAmDau.isEmpty && tieng.nguyenAm.isEmpty
      && tieng.phuAmCuoi.isEmpty && tieng.conLai.isEmpty
    {
      return ""
    }

    // Bước 1: Áp dụng gạch ngang D (d → đ)
    apDungGachD(vaoTieng: &tieng, gachD: gachD)

    // Bước 2: Áp dụng dấu mũ
    apDungDauMu(vaoTieng: &tieng, dauMu: dauMu, soNguyenAm: countNguyenAm)

    // Bước 3: Áp dụng dấu thanh
    apDungDauThanh(vaoTieng: &tieng, dauThanh: dauThanh, soNguyenAm: countNguyenAm)

    // Ghép các thành phần thành chuỗi kết quả
    return String(tieng.phuAmDau + tieng.nguyenAm + tieng.phuAmCuoi + tieng.conLai)
  }

  // MARK: - Áp dụng gạch ngang D

  /// Chuyển d → đ nếu có cờ gachD
  private static func apDungGachD(vaoTieng tieng: inout ThanhPhanTieng, gachD: Bool) {
    if gachD,
      let kyTuPhuAmDau = tieng.phuAmDau.first,
      let kyTuMoi = chuyenKyTu(kytu: kyTuPhuAmDau, quyTac: TiengViet.QuyTacGachD)
    {
      tieng.phuAmDau[0] = kyTuMoi
    }
  }

  // MARK: - Áp dụng dấu mũ

  /// Áp dụng dấu mũ (^, móc, trăng) vào nguyên âm theo quy tắc
  ///
  /// Quy tắc đặt dấu mũ:
  /// - Trường hợp đặc biệt "uo" + dấu móc → "ươ" (cả 2 nguyên âm đều có dấu)
  /// - Có 3 nguyên âm hoặc 2 nguyên âm + phụ âm cuối: đặt ở nguyên âm thứ 2
  /// - Còn lại: đặt ở nguyên âm đầu tiên có thể nhận dấu
  private static func apDungDauMu(
    vaoTieng tieng: inout ThanhPhanTieng,
    dauMu: DauMu,
    soNguyenAm: Int
  ) {
    guard let quyTac = TiengViet.QuyTacDatMu[dauMu], !quyTac.isEmpty else { return }

    // Hàm nội bộ: thử đặt dấu mũ tại vị trí idx
    func thuDatDauMu(_ idx: Int) -> Bool {
      if let kyTuMoi = chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
        tieng.nguyenAm[idx] = kyTuMoi
        tieng.viTriDauMu = idx
        return true
      }
      return false
    }

    let datDauMocUO = (dauMu == .muMoc) && tieng.chuaNguyenAmUO

    // Trường hợp đặc biệt: "uo" + dấu móc → "ươ"
    if datDauMocUO && thuDatDauMu(1) {
      // Nếu có 3 nguyên âm hoặc có phụ âm cuối, đặt dấu cho cả nguyên âm đầu
      if soNguyenAm == 3 || !tieng.phuAmCuoi.isEmpty,
        let dauU = chuyenKyTu(kytu: tieng.nguyenAm[0], quyTac: quyTac)
      {
        tieng.nguyenAm[0] = dauU
      }
    } else if (soNguyenAm == 3 || (soNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty))
      && thuDatDauMu(1)
    {
      // Đặt ở nguyên âm thứ 2 thành công
    } else {
      // Tìm nguyên âm đầu tiên có thể nhận dấu
      for i in 0..<soNguyenAm {
        if thuDatDauMu(i) { break }
      }
    }
  }

  // MARK: - Áp dụng dấu thanh

  /// Áp dụng dấu thanh (sắc, huyền, hỏi, ngã, nặng) vào nguyên âm theo quy tắc
  ///
  /// Quy tắc đặt dấu thanh:
  /// - Ưu tiên 1: Đặt trên nguyên âm đã có dấu mũ (nếu có)
  /// - Ưu tiên 2: Có 3 nguyên âm hoặc 2 nguyên âm + phụ âm cuối → đặt ở nguyên âm thứ 2
  /// - Còn lại: Đặt ở nguyên âm đầu tiên có thể nhận dấu
  private static func apDungDauThanh(
    vaoTieng tieng: inout ThanhPhanTieng,
    dauThanh: DauThanh,
    soNguyenAm: Int
  ) {
    guard let quyTac = TiengViet.QuyTacDatDau[dauThanh], !quyTac.isEmpty else { return }

    // Hàm nội bộ: thử đặt dấu thanh tại vị trí idx
    func thuDatDauThanh(_ idx: Int) -> Bool {
      if let kyTuMoi = chuyenKyTu(kytu: tieng.nguyenAm[idx], quyTac: quyTac) {
        tieng.nguyenAm[idx] = kyTuMoi
        tieng.viTriDauThanh = idx
        return true
      }
      return false
    }

    // Ưu tiên 1: Đặt trên nguyên âm đã có dấu mũ
    if tieng.viTriDauMu > -1 && thuDatDauThanh(tieng.viTriDauMu) {
      return
    }

    // Ưu tiên 2: Có 3 nguyên âm hoặc 2 nguyên âm + phụ âm cuối → đặt ở nguyên âm thứ 2
    if (soNguyenAm == 3 || (soNguyenAm == 2 && !tieng.phuAmCuoi.isEmpty))
      && thuDatDauThanh(1)
    {
      return
    }

    // Tìm nguyên âm đầu tiên có thể nhận dấu
    for i in 0..<soNguyenAm {
      if thuDatDauThanh(i) { break }
    }
  }

  // MARK: - Tiện ích

  /// Chuyển đổi ký tự theo bảng quy tắc
  /// - Parameters:
  ///   - kytu: Ký tự cần chuyển đổi
  ///   - quyTac: Bảng ánh xạ (ký tự gốc, ký tự mới)
  /// - Returns: Ký tự mới nếu tìm thấy, nil nếu không
  private static func chuyenKyTu(kytu: Character, quyTac: [(Character, Character)]) -> Character? {
    for (match, to) in quyTac {
      if match == kytu {
        return to
      }
    }
    return nil
  }
}
