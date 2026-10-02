//
//  TiengVietState.swift
//  Caffee
//
//  Trạng thái bất biến của âm tiết tiếng Việt (Immutable state)
//

import Foundation

/// TiengVietState - Container trạng thái bất biến
///
/// Mọi thay đổi trạng thái đều trả về instance mới, đảm bảo tính nhất quán
/// và dễ debug (có thể so sánh state trước/sau).
///
/// Sử dụng:
/// ```swift
/// let state = TiengVietState.empty
///   .push("t").push("o").push("i")  // "toi"
///   .withTone(.sac)                  // "tói"
///   .withMu(.muUp)                   // "tôi" → "tối"
/// ```
struct TiengVietState {
  /// Chuỗi ký tự gốc chưa có dấu (đầu vào từ bàn phím)
  let chuKhongDau: [Character]
  /// Dấu thanh hiện tại (sắc, huyền, hỏi, ngã, nặng)
  let dauThanh: DauThanh
  /// Dấu mũ hiện tại (mũ, móc, trăng)
  let dauMu: DauMu
  /// Dấu móc đặt cho cả "u" lẫn "o" của nhóm "uo" kể cả khi chưa có phụ âm cuối: người gõ đã
  /// móc "u" trước khi gõ "o" (tuwo → tươ) hoặc móc lần nữa (uwow). Không có cờ này, "uo" mở chỉ
  /// móc "o" (thuở, huơ).
  let mocCaHai: Bool
  /// Có gạch ngang chữ D không (d → đ)
  let gachD: Bool
  /// Cấu hình engine áp dụng cho state này
  let config: EngineConfig
  /// Các thành phần âm tiết đã phân tích (parse một lần cho mỗi state)
  let thanhPhanTieng: ThanhPhanTieng

  /// State rỗng - điểm khởi đầu (cấu hình mặc định)
  static let empty = TiengVietState.empty(config: EngineConfig())

  /// State rỗng với cấu hình chỉ định
  static func empty(config: EngineConfig) -> TiengVietState {
    TiengVietState(
      chuKhongDau: [],
      dauThanh: .bang,
      dauMu: .khongMu,
      mocCaHai: false,
      gachD: false,
      config: config,
      thanhPhanTieng: ThanhPhanTieng()
    )
  }

  private init(
    chuKhongDau: [Character],
    dauThanh: DauThanh,
    dauMu: DauMu,
    mocCaHai: Bool,
    gachD: Bool,
    config: EngineConfig,
    thanhPhanTieng: ThanhPhanTieng
  ) {
    self.chuKhongDau = chuKhongDau
    self.dauThanh = dauThanh
    self.dauMu = dauMu
    self.mocCaHai = mocCaHai
    self.gachD = gachD
    self.config = config
    self.thanhPhanTieng = thanhPhanTieng
  }

  // MARK: - Computed Properties

  /// Chuỗi đã biến đổi với dấu tiếng Việt
  var transformed: String {
    if isBlank { return "" }
    return TiengVietTransformer.transform(
      thanhPhanTieng: thanhPhanTieng,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD,
      mocCaHai: mocCaHai,
      tonePlacement: config.tonePlacement
    )
  }

  /// Kiểm tra state có rỗng không
  var isBlank: Bool { chuKhongDau.isEmpty }

  /// Kiểm tra âm tiết có cần recovery không (không hợp lệ tiếng Việt)
  /// Khi true, nên dùng chuỗi gốc thay vì chuỗi đã biến đổi
  var needsRecovery: Bool {
    config.spellingCheck
      && TiengVietValidator.needsRecovery(
        thanhPhanTieng, dauMu: dauMu, dauThanh: dauThanh, mocCaHai: mocCaHai)
  }
}

// MARK: - State Mutations (trả về state mới)

extension TiengVietState {

  /// Thêm ký tự vào chuỗi đầu vào
  func push(_ letter: Character) -> TiengVietState {
    let newChuKhongDau = chuKhongDau + [letter]
    return TiengVietState(
      chuKhongDau: newChuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu,
      mocCaHai: mocCaHai,
      gachD: gachD,
      config: config,
      thanhPhanTieng: TiengVietParser.parse(newChuKhongDau, config: config)
    )
  }

  /// Xóa ký tự cuối cùng
  func pop() -> TiengVietState {
    guard !chuKhongDau.isEmpty else { return self }

    let newChuKhongDau = Array(chuKhongDau.dropLast())
    let newThanhPhan = TiengVietParser.parse(newChuKhongDau, config: config)

    // Reset dấu nếu không còn nguyên âm
    let conNguyenAm = !newThanhPhan.nguyenAm.isEmpty

    return TiengVietState(
      chuKhongDau: newChuKhongDau,
      dauThanh: conNguyenAm ? dauThanh : .bang,
      dauMu: conNguyenAm ? dauMu : .khongMu,
      mocCaHai: conNguyenAm && mocCaHai,
      gachD: gachD,
      config: config,
      thanhPhanTieng: newThanhPhan
    )
  }

  /// Đặt/xóa dấu thanh (toggle: gõ cùng dấu 2 lần sẽ xóa)
  func withTone(_ tone: DauThanh) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh == tone ? .bang : tone,
      dauMu: dauMu,
      mocCaHai: mocCaHai,
      gachD: gachD,
      config: config,
      thanhPhanTieng: thanhPhanTieng
    )
  }

  /// Đặt/xóa dấu mũ (toggle: gõ cùng dấu 2 lần sẽ xóa)
  /// - Parameter mocCaHai: với dấu móc, có móc cả "u" lẫn "o" của nhóm "uo" không
  func withMu(_ mu: DauMu, mocCaHai: Bool = false) -> TiengVietState {
    let newDauMu: DauMu = dauMu == mu ? .khongMu : mu
    return TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: newDauMu,
      mocCaHai: newDauMu == .muMoc && mocCaHai,
      gachD: gachD,
      config: config,
      thanhPhanTieng: thanhPhanTieng
    )
  }

  /// Giữ dấu móc và móc cả "u" lẫn "o" (phím móc gõ lần nữa trên "uo": uwow, u7o7)
  func withMocCaHai() -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: .muMoc,
      mocCaHai: true,
      gachD: gachD,
      config: config,
      thanhPhanTieng: thanhPhanTieng
    )
  }

  /// Toggle gạch ngang D (d ↔ đ)
  func withGachD() -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu,
      mocCaHai: mocCaHai,
      gachD: !gachD,
      config: config,
      thanhPhanTieng: thanhPhanTieng
    )
  }
}
