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
  /// Có gạch ngang chữ D không (d → đ)
  let gachD: Bool

  /// State rỗng - điểm khởi đầu
  static let empty = TiengVietState(
    chuKhongDau: [],
    dauThanh: .bang,
    dauMu: .khongMu,
    gachD: false
  )

  // MARK: - Computed Properties

  /// Các thành phần âm tiết đã phân tích - luôn nhất quán, không cần gọi parse() thủ công
  var thanhPhanTieng: ThanhPhanTieng {
    TiengVietParser.parse(chuKhongDau)
  }

  /// Chuỗi đã biến đổi với dấu tiếng Việt
  var transformed: String {
    if isBlank { return "" }
    return TiengVietTransformer.transform(
      thanhPhanTieng: thanhPhanTieng,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD
    )
  }

  /// Kiểm tra state có rỗng không
  var isBlank: Bool { chuKhongDau.isEmpty }

  /// Kiểm tra âm tiết có cần recovery không (không hợp lệ tiếng Việt)
  /// Khi true, nên dùng chuỗi gốc thay vì chuỗi đã biến đổi
  var needsRecovery: Bool {
    TiengVietValidator.needsRecovery(thanhPhanTieng, dauMu: dauMu)
  }

  /// Chuỗi gốc (dùng khi cần recovery)
  var originalInput: String {
    String(chuKhongDau)
  }
}

// MARK: - State Mutations (trả về state mới)

extension TiengVietState {

  /// Thêm ký tự vào chuỗi đầu vào
  func push(_ letter: Character) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau + [letter],
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD
    )
  }

  /// Xóa ký tự cuối cùng
  func pop() -> TiengVietState {
    guard !chuKhongDau.isEmpty else { return self }

    let newChuKhongDau = Array(chuKhongDau.dropLast())
    let newThanhPhan = TiengVietParser.parse(newChuKhongDau)

    // Reset dấu nếu không còn nguyên âm
    var newDauMu = dauMu
    var newDauThanh = dauThanh

    if newThanhPhan.nguyenAm.isEmpty {
      newDauMu = .khongMu
      newDauThanh = .bang
    }

    return TiengVietState(
      chuKhongDau: newChuKhongDau,
      dauThanh: newDauThanh,
      dauMu: newDauMu,
      gachD: gachD
    )
  }

  /// Đặt/xóa dấu thanh (toggle: gõ cùng dấu 2 lần sẽ xóa)
  func withTone(_ tone: DauThanh) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh == tone ? .bang : tone,
      dauMu: dauMu,
      gachD: gachD
    )
  }

  /// Đặt/xóa dấu mũ (toggle: gõ cùng dấu 2 lần sẽ xóa)
  func withMu(_ mu: DauMu) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu == mu ? .khongMu : mu,
      gachD: gachD
    )
  }

  /// Toggle gạch ngang D (d ↔ đ)
  func withGachD() -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: !gachD
    )
  }
}
