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

protocol AppCompatibilityPolicy {
  var autoSwitchStrategyEnabled: Bool { get }

  func replacementStrategy(for bundleId: String) -> SendingStrategy
  func appName(for bundleId: String) -> String
  func shouldFixAutocomplete(for bundleId: String) -> Bool
}

struct DefaultAppCompatibilityPolicy: AppCompatibilityPolicy {
  private let autocompleteBundlePrefixes: [String]
  private let sendingConfigs: [AppSendingConfig]
  private let autoSwitchEnabled: () -> Bool

  init(
    autocompleteBundlePrefixes: [String] = Self.autocompleteBundlePrefixes,
    sendingConfigs: [AppSendingConfig] = Self.sendingConfigs,
    autoSwitchEnabled: @escaping () -> Bool = { Defaults[.autoSwitchStrategy] }
  ) {
    self.autocompleteBundlePrefixes = autocompleteBundlePrefixes
    self.sendingConfigs = sendingConfigs
    self.autoSwitchEnabled = autoSwitchEnabled
  }

  var autoSwitchStrategyEnabled: Bool {
    autoSwitchEnabled()
  }

  func replacementStrategy(for bundleId: String) -> SendingStrategy {
    sendingConfigs.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.strategy ?? .batch
  }

  func appName(for bundleId: String) -> String {
    sendingConfigs.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.name ?? "Unknown App"
  }

  func shouldFixAutocomplete(for bundleId: String) -> Bool {
    autocompleteBundlePrefixes.contains { bundleId.hasPrefix($0) }
  }
}

extension DefaultAppCompatibilityPolicy {
  static let autocompleteBundlePrefixes = [
    // Chromium-based
    "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta",
    "org.chromium.Chromium",
    "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
    "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev",
    "com.microsoft.edgemac.Canary",
    "com.vivaldi.Vivaldi", "com.vivaldi.Vivaldi.snapshot",
    "ru.yandex.desktop.yandex-browser", "com.naver.Whale",

    // Opera
    "com.opera.Opera", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
    "com.operasoftware.OperaAir", "com.opera.OperaNext",

    // Firefox-based
    "org.mozilla.firefox", "org.mozilla.nightly", "org.torproject.torbrowser",
    "org.librewolf.LibreWolf",
    "app.zen-browser.zen",

    // Safari & WebKit-based
    "com.apple.Safari", "com.apple.SafariTechnologyPreview",
    "com.apple.Safari.TechnologyPreview",
    "com.kagi.kagimacOS", "com.duckduckgo.mac", "com.duckduckgo.macos.browser",

    // Arc & Others
    "company.thebrowser.Browser", "company.thebrowser.Arc", "company.thebrowser.dia",
    "com.sigmaos.sigmaos", "com.sigmaos.sigmaos.macos",
    "com.pushplaylabs.sidekick", "com.firstversionist.polypane",
    "ai.perplexity.comet", "com.electron.min",

    // Office & Legacy
    "com.microsoft.Excel", "com.microsoft.Office.Excel", "com.microsoft.edge",
    "com.microsoft.Edge",
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

/// TransformationTracker monitors for repeated transformation failures
/// and auto-switches the sending strategy when a pattern is detected.
struct TransformationTracker {
  /// Current sending strategy for the active app
  var currentStrategy: SendingStrategy = .batch

  /// Track consecutive transformation failures for auto-switching
  private var consecutiveFailures = 0

  /// Maximum failures before auto-switching to step-by-step mode
  private let maxFailuresBeforeSwitch = 3

  /// Track last input character for failure detection
  private var lastInputChar: Character?

  mutating func resetForApp(_ bundleId: String, policy: AppCompatibilityPolicy) {
    currentStrategy = policy.replacementStrategy(for: bundleId)
    consecutiveFailures = 0
    lastInputChar = nil
  }

  /// Detects if a transformation likely failed based on input/output tracking.
  /// Returns true if the transformation appears to have failed.
  mutating func detectFailure(input: Character) -> Bool {
    if let last = lastInputChar, last == input {
      consecutiveFailures += 1
    } else {
      consecutiveFailures = 1
    }
    lastInputChar = input

    return consecutiveFailures >= maxFailuresBeforeSwitch
  }

  /// Auto-switches to step-by-step mode if failures are detected.
  mutating func autoSwitchIfNeeded(activeApp: String, policy: AppCompatibilityPolicy) {
    guard policy.autoSwitchStrategyEnabled else { return }

    // Don't auto-switch if already using step-by-step
    if case .stepByStep = currentStrategy { return }

    #if DEBUG
      let appName = policy.appName(for: activeApp)
      print(
        "[Caffee] Auto-switched from \(currentStrategy) to step-by-step mode for \(appName) due to failures"
      )
    #endif

    currentStrategy = .stepByStep
    consecutiveFailures = 0
  }
}
