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

extension Defaults.Keys {
  static let currentVersion = Key<String>("current-version", default: "0.1")
  static let typingMethod = Key<TypingMethods>("typing-method", default: .Telex)
  static let allowedZWJF = Key<Bool>("allowed-zwjf", default: true)
  static let token = Key<String>("token", default: "")

  //            ^            ^         ^                ^
  //           Key          Type   UserDefaults name   Default value
}
