//
//  AppModeStore.swift
//  Caffee
//

import Defaults
import Foundation

/// Whether Vietnamese typing in an app follows the last choice made there, or is pinned.
enum AppModePreference: String, CaseIterable, Defaults.Serializable {
  case remember
  case alwaysVietnamese
  case alwaysEnglish

  var title: String {
    switch self {
    case .remember: return "Nhớ lựa chọn gần nhất"
    case .alwaysVietnamese: return "Luôn gõ tiếng Việt"
    case .alwaysEnglish: return "Luôn gõ tiếng Anh"
    }
  }
}

/// Per-app memory: last mode, pinned mode and sending-strategy override, keyed by bundle id.
///
/// A plain value type so the rules can be tested without `UserDefaults`; `load()` / `save()`
/// bridge to the persisted `Defaults` keys.
struct AppModeStore: Equatable {
  var remembered: [String: Bool] = [:]
  var preferences: [String: AppModePreference] = [:]
  var strategies: [String: SendingStrategyOverride] = [:]

  static func load() -> AppModeStore {
    AppModeStore(
      remembered: Defaults[.appModes],
      preferences: Defaults[.appModePreferences],
      strategies: Defaults[.appStrategyOverrides])
  }

  func save() {
    Defaults[.appModes] = remembered
    Defaults[.appModePreferences] = preferences
    Defaults[.appStrategyOverrides] = strategies
  }

  func preference(for app: String) -> AppModePreference {
    preferences[app] ?? .remember
  }

  func strategy(for app: String) -> SendingStrategyOverride {
    strategies[app] ?? .automatic
  }

  /// Mode to apply when `app` becomes frontmost; nil keeps whatever mode is active now.
  func mode(for app: String) -> Bool? {
    switch preference(for: app) {
    case .alwaysVietnamese: return true
    case .alwaysEnglish: return false
    case .remember: return remembered[app]
    }
  }

  mutating func remember(_ enabled: Bool, in app: String) {
    remembered[app] = enabled
  }

  mutating func setPreference(_ preference: AppModePreference, for app: String) {
    preferences[app] = preference == .remember ? nil : preference
  }

  mutating func setStrategy(_ strategy: SendingStrategyOverride, for app: String) {
    strategies[app] = strategy == .automatic ? nil : strategy
  }

  /// Forgets everything stored for `app`.
  mutating func forget(_ app: String) {
    remembered[app] = nil
    preferences[app] = nil
    strategies[app] = nil
  }

  /// Apps with any stored setting, sorted for display.
  var knownApps: [String] {
    Set(remembered.keys).union(preferences.keys).union(strategies.keys).sorted()
  }
}
