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
  case Telex = "Telex"
  case VNI = "VNI"
}

/// TypingMethod - Protocol cho các phương thức gõ tiếng Việt
///
/// Mỗi phương thức gõ (Telex, VNI) cần triển khai protocol này
/// để xử lý ký tự nhập vào và cập nhật trạng thái.
protocol TypingMethod {
  /// Xử lý ký tự nhập vào - trả về ý định rõ ràng để WordBuffer phản ứng.
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - keyStr: Toàn bộ chuỗi phím thô của từ hiện tại
  ///   - state: Trạng thái hiện tại
  func push(char: Character, keyStr: String, state: TiengVietState) -> TypingMethodResult

  /// Xóa ký tự cuối cùng - trả về state mới
  func pop(state: TiengVietState) -> TiengVietState
}

/// Kết quả xử lý của engine cho một phím vừa nhập.
enum TypingMethodResult {
  case insertRaw(TiengVietState)
  case applyMark(TiengVietState)
  case toggleToRaw(TiengVietState)
  case recover(TiengVietState)
  case noChange(TiengVietState)
}
