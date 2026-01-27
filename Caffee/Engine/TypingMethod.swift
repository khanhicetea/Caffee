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
  /// Kiểm tra có nên dừng xử lý không (ví dụ: gõ đúp để hủy dấu)
  func shouldStopProcessing(keyStr: String) -> Bool

  /// Xử lý ký tự nhập vào - trả về state mới thay vì mutate
  /// - Parameters:
  ///   - char: Ký tự vừa gõ
  ///   - state: Trạng thái hiện tại
  /// - Returns: Tuple (state mới, có áp dụng dấu không)
  func push(char: Character, state: TiengVietState) -> (state: TiengVietState, appliedMark: Bool)

  /// Xóa ký tự cuối cùng - trả về state mới
  func pop(state: TiengVietState) -> TiengVietState
}
