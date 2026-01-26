//
//  TiengVietState.swift
//  Caffee
//
//  Immutable Vietnamese syllable state
//

import Foundation

/// TiengVietState - Immutable Vietnamese syllable state
/// All mutations return a new state instance, ensuring consistency
struct TiengVietState {
  /// Raw characters without diacritics (input from keyboard)
  let chuKhongDau: [Character]
  /// Current tone mark
  let dauThanh: DauThanh
  /// Current diacritical mark (circumflex, horn, breve)
  let dauMu: DauMu
  /// Whether to apply stroke to 'd'
  let gachD: Bool

  /// Empty state singleton
  static let empty = TiengVietState(
    chuKhongDau: [],
    dauThanh: .bang,
    dauMu: .khongMu,
    gachD: false
  )

  /// Computed - always consistent, no manual parse() needed
  var thanhPhanTieng: ThanhPhanTieng {
    TiengVietParser.parse(chuKhongDau)
  }

  /// Computed - transformed string with diacritics
  var transformed: String {
    if isBlank { return "" }
    return TiengVietTransformer.transform(
      thanhPhanTieng: thanhPhanTieng,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD
    )
  }

  /// Check if state is empty
  var isBlank: Bool { chuKhongDau.isEmpty }

  /// Check if state needs recovery (invalid Vietnamese syllable)
  /// When true, the original input should be used instead of transformed text
  var needsRecovery: Bool {
    TiengVietValidator.needsRecovery(thanhPhanTieng, dauMu: dauMu)
  }

  /// The original input string (for recovery when Vietnamese is invalid)
  var originalInput: String {
    String(chuKhongDau)
  }
}

// MARK: - State Mutations (return new state)

extension TiengVietState {

  /// Add a character to the input
  func push(_ letter: Character) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau + [letter],
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: gachD
    )
  }

  /// Remove the last character
  func pop() -> TiengVietState {
    guard !chuKhongDau.isEmpty else { return self }

    let newChuKhongDau = Array(chuKhongDau.dropLast())
    let newThanhPhan = TiengVietParser.parse(newChuKhongDau)

    // Reset diacritics if vowel position is now invalid
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

  /// Set/toggle tone mark (toggle: applying same tone twice removes it)
  func withTone(_ tone: DauThanh) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh == tone ? .bang : tone,
      dauMu: dauMu,
      gachD: gachD
    )
  }

  /// Set/toggle diacritical mark (toggle: applying same mark twice removes it)
  func withMu(_ mu: DauMu) -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu == mu ? .khongMu : mu,
      gachD: gachD
    )
  }

  /// Toggle stroke on 'd' (d <-> d)
  func withGachD() -> TiengVietState {
    TiengVietState(
      chuKhongDau: chuKhongDau,
      dauThanh: dauThanh,
      dauMu: dauMu,
      gachD: !gachD
    )
  }
}
