//
//  Setting.swift
//  Caffee
//
//  Created by KhanhIceTea on 11/3/24.
//

import Defaults
import Foundation
import KeyboardShortcuts

extension Bundle {
  public var appName: String { getInfo("CFBundleName") }
  public var displayName: String { getInfo("CFBundleDisplayName") }
  public var language: String { getInfo("CFBundleDevelopmentRegion") }
  public var identifier: String { getInfo("CFBundleIdentifier") }
  public var copyright: String {
    getInfo("NSHumanReadableCopyright").replacingOccurrences(of: "\\\\n", with: "\n")
  }

  public var appBuild: String { getInfo("CFBundleVersion") }
  public var appVersionLong: String { getInfo("CFBundleShortVersionString") }
  public var appVersionShort: String { getInfo("CFBundleShortVersion") }

  fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}

extension KeyboardShortcuts.Name {
  static let toggleInputMode = Self("toggleInputMode", default: .init(.z, modifiers: [.option]))
}

extension TonePlacement: Defaults.Serializable {}

extension Defaults.Keys {
  static let currentVersion = Key<String>("current-version", default: "0.1")
  static let typingMethod = Key<TypingMethods>("typing-method", default: .telex)
  static let allowedZWJF = Key<Bool>("allowed-zwjf", default: true)
  static let checkForUpdatesAutomatically = Key<Bool>("check-updates-automatically", default: true)
  static let tonePlacement = Key<TonePlacement>("tone-placement", default: .firstVowel)
  static let spellingCheck = Key<Bool>("spelling-check", default: true)
  static let showModeHUD = Key<Bool>("show-mode-hud", default: false)
  /// Remembered Vietnamese on/off state per app (bundle identifier).
  static let appModes = Key<[String: Bool]>("app-modes", default: [:])
  /// Apps pinned to Vietnamese or English instead of remembering the last choice.
  static let appModePreferences = Key<[String: AppModePreference]>(
    "app-mode-preferences", default: [:])
  /// User-chosen way of sending replacements per app (bundle identifier).
  static let appStrategyOverrides = Key<[String: SendingStrategyOverride]>(
    "app-strategy-overrides", default: [:])

  //            ^            ^         ^                ^
  //           Key          Type   UserDefaults name   Default value
}
