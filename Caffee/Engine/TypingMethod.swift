//
//  TypingMethod.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/02/2024.
//

import Defaults
import Foundation

/// TypingMethods - Các kiểu gõ tiếng Việt được hỗ trợ
enum TypingMethods: String, CaseIterable, Defaults.Serializable {
  case telex = "Telex"
  case vni = "VNI"
}

/// TypingMethod - Protocol cho các phương thức gõ tiếng Việt
///
/// Mỗi phương thức gõ (Telex, VNI) cần triển khai protocol này
/// để xử lý ký tự nhập vào và cập nhật trạng thái.
protocol TypingMethod: Sendable {
  /// Xử lý ký tự nhập vào - trả về ý định rõ ràng để WordBuffer phản ứng.
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - keyStr: Toàn bộ chuỗi phím thô của từ hiện tại
  ///   - state: Trạng thái hiện tại
  func push(char: Character, keyStr: String, state: TiengVietState) -> TypingMethodResult

  /// Xóa ký tự cuối cùng - trả về state mới
  func pop(state: TiengVietState) -> TiengVietState

  /// Chuỗi phím thô có đang "hủy dấu" (gõ đúp phím dấu, ...) nên phải trả về chuỗi gốc không.
  func shouldToggleToRaw(keyStr: String) -> Bool
}

extension TypingMethod {
  /// Thêm ký tự như bình thường (không áp dụng dấu).
  func rawResult(_ newState: TiengVietState, keyStr: String) -> TypingMethodResult {
    if newState.needsRecovery {
      return .recover(newState)
    }

    if shouldToggleToRaw(keyStr: keyStr) {
      return .toggleToRaw(newState)
    }

    return .insertRaw(newState)
  }

  /// Áp dụng dấu (thanh, mũ, gạch D); gõ đúp sẽ hủy dấu và in phím thô.
  func markResult(
    _ newState: TiengVietState,
    char: Character,
    keyStr: String
  ) -> TypingMethodResult {
    if shouldToggleToRaw(keyStr: keyStr) {
      return .toggleToRaw(newState.push(char))
    }

    if newState.needsRecovery {
      return .recover(newState)
    }

    return .applyMark(newState)
  }
}

/// Kết quả xử lý của engine cho một phím vừa nhập.
enum TypingMethodResult {
  case insertRaw(TiengVietState)
  case applyMark(TiengVietState)
  case toggleToRaw(TiengVietState)
  case recover(TiengVietState)
  case noChange(TiengVietState)
}
