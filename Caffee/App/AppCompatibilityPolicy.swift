//
//  AppCompatibilityPolicy.swift
//  Caffee
//

import Defaults
import Foundation

struct AppSendingConfig {
  /// Bundle ID prefix to match.
  let bundlePrefix: String
  /// Sending strategy for this app.
  let strategy: SendingStrategy
  /// Human-readable name for logging.
  let name: String
}

/// User-selectable way to deliver replacements to one app.
enum SendingStrategyOverride: String, CaseIterable, Defaults.Serializable {
  case automatic
  case fast
  case balanced
  case stepByStep

  var title: String {
    switch self {
    case .automatic: return "Tự động"
    case .fast: return "Nhanh"
    case .balanced: return "Cân bằng"
    case .stepByStep: return "Từng ký tự (chậm, tương thích nhất)"
    }
  }

  /// nil means "use the built-in default for this app".
  var strategy: SendingStrategy? {
    switch self {
    case .automatic: return nil
    case .fast: return .batch
    case .balanced: return .hybrid(backspaceDelayMicroseconds: 1000)
    case .stepByStep: return .stepByStep
    }
  }
}

protocol AppCompatibilityPolicy {
  func replacementStrategy(for bundleId: String) -> SendingStrategy
  func shouldFixAutocomplete(for bundleId: String) -> Bool
}

struct DefaultAppCompatibilityPolicy: AppCompatibilityPolicy {
  private let autocompleteBundlePrefixes: [String]
  private let sendingConfigs: [AppSendingConfig]
  private let overrides: () -> [String: SendingStrategyOverride]

  init(
    autocompleteBundlePrefixes: [String] = Self.autocompleteBundlePrefixes,
    sendingConfigs: [AppSendingConfig] = Self.sendingConfigs,
    overrides: @escaping () -> [String: SendingStrategyOverride] = {
      Defaults[.appStrategyOverrides]
    }
  ) {
    self.autocompleteBundlePrefixes = autocompleteBundlePrefixes
    self.sendingConfigs = sendingConfigs
    self.overrides = overrides
  }

  func replacementStrategy(for bundleId: String) -> SendingStrategy {
    if let userChoice = overrides()[bundleId]?.strategy {
      return userChoice
    }
    return sendingConfigs.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.strategy ?? .batch
  }

  func shouldFixAutocomplete(for bundleId: String) -> Bool {
    autocompleteBundlePrefixes.contains { bundleId.hasPrefix($0) }
  }
}

extension DefaultAppCompatibilityPolicy {
  /// Matched with `hasPrefix`, so one entry also covers its beta/canary/nightly/snapshot variants.
  static let autocompleteBundlePrefixes = [
    // Chromium-based
    "com.google.Chrome", "org.chromium.Chromium", "com.brave.Browser",
    "com.microsoft.edge", "com.microsoft.Edge",
    "com.vivaldi.Vivaldi", "ru.yandex.desktop.yandex-browser", "com.naver.Whale",

    // Opera (com.opera.Opera also covers OperaNext; com.operasoftware.Opera covers GX/Air)
    "com.opera.Opera", "com.operasoftware.Opera",

    // Firefox-based
    "org.mozilla.firefox", "org.mozilla.nightly", "org.torproject.torbrowser",
    "org.librewolf.LibreWolf", "app.zen-browser.zen",

    // Safari & WebKit-based
    "com.apple.Safari", "com.kagi.kagimacOS", "com.duckduckgo.mac",

    // Arc & others
    "company.thebrowser.Browser", "company.thebrowser.Arc", "company.thebrowser.dia",
    "com.sigmaos.sigmaos", "com.pushplaylabs.sidekick", "com.firstversionist.polypane",
    "ai.perplexity.comet", "com.electron.min",

    // Office
    "com.microsoft.Excel", "com.microsoft.Office.Excel",
  ]

  static let sendingConfigs: [AppSendingConfig] = [
    AppSendingConfig(
      bundlePrefix: "com.microsoft.Word",
      strategy: .hybrid(backspaceDelayMicroseconds: 1000),
      name: "Word"
    ),
    AppSendingConfig(
      bundlePrefix: "com.microsoft.Excel",
      strategy: .hybrid(backspaceDelayMicroseconds: 1000),
      name: "Excel"
    ),
    AppSendingConfig(
      bundlePrefix: "com.microsoft.Powerpoint",
      strategy: .hybrid(backspaceDelayMicroseconds: 1000),
      name: "PowerPoint"
    ),
    AppSendingConfig(
      bundlePrefix: "com.microsoft.Outlook",
      strategy: .hybrid(backspaceDelayMicroseconds: 1000),
      name: "Outlook"
    ),
    AppSendingConfig(
      bundlePrefix: "com.microsoft.onenote.mac",
      strategy: .hybrid(backspaceDelayMicroseconds: 1000),
      name: "OneNote"
    ),

    AppSendingConfig(bundlePrefix: "com.apple.Terminal", strategy: .stepByStep, name: "Terminal"),
    AppSendingConfig(bundlePrefix: "com.googlecode.iterm2", strategy: .stepByStep, name: "iTerm2"),
    AppSendingConfig(bundlePrefix: "net.kovidgoyal.kitty", strategy: .stepByStep, name: "Kitty"),
    AppSendingConfig(bundlePrefix: "com.mitchellh.ghostty", strategy: .stepByStep, name: "Ghostty"),
    AppSendingConfig(bundlePrefix: "com.warp.Warp", strategy: .stepByStep, name: "Warp"),
    AppSendingConfig(bundlePrefix: "co.zeit.hyper", strategy: .stepByStep, name: "Hyper"),
    AppSendingConfig(bundlePrefix: "org.tabby", strategy: .stepByStep, name: "Tabby"),
    AppSendingConfig(bundlePrefix: "io.alacritty", strategy: .stepByStep, name: "Alacritty"),
  ]
}
