//
//  EngineConfig.swift
//  Caffee
//
//  Cấu hình bất biến của engine (thay cho biến toàn cục)
//

/// Vị trí đặt dấu thanh trên các cặp nguyên âm "oa", "oe", "uy" không có phụ âm cuối.
enum TonePlacement: String, CaseIterable {
  /// Dấu ở nguyên âm đầu: hòa, thủy, khỏe
  case firstVowel
  /// Dấu ở nguyên âm sau: hoà, thuỷ, khoẻ
  case secondVowel
}

/// Tùy chọn của engine. Mỗi `TiengVietState` mang theo cấu hình của nó, nên không cần
/// biến toàn cục có thể bị thay đổi giữa chừng.
struct EngineConfig: Equatable {
  /// Cho phép phụ âm đầu ngoại lai z, w, j, f (zalo, wifi, jack, fan).
  var allowForeignConsonants = false
  var tonePlacement: TonePlacement = .firstVowel
  /// Khi tắt, dấu luôn được áp dụng, kể cả với âm tiết không hợp lệ tiếng Việt.
  var spellingCheck = true
}
