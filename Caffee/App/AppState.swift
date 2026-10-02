//
//  AppState.swift
//  Caffee
//
//  Created by KhanhIceTea on 20/02/2024.
//

import Cocoa
import Defaults
import Foundation
import KeyboardShortcuts
import Observation

/// UI-facing state of the input method. Creating one has no side effects (previews and tests
/// can instantiate it freely); `start()` is what registers the global hotkey and the
/// frontmost-app observer.
@MainActor
@Observable
final class AppState: ModeControlling {

  enum ModeChangeReason {
    case hotkey
    case automation
    case appSwitch
    case menu
  }

  public var enabled = false {
    didSet {
      // "Unknown" is only the placeholder used before the first app activation.
      if activeAppName != AppState.unknownApp {
        store.remember(enabled, in: activeAppName)
        store.save()
      }
      eventHook.setEnabled(enabled)
    }
  }
  public var typingMethod: TypingMethods {
    didSet {
      inputProcessor.changeTypingMethod(newMethod: typingMethod)
      Defaults[.typingMethod] = typingMethod
    }
  }
  public var allowedZWJF: Bool {
    didSet {
      Defaults[.allowedZWJF] = allowedZWJF
      applyEngineConfig()
    }
  }
  public var tonePlacement: TonePlacement {
    didSet {
      Defaults[.tonePlacement] = tonePlacement
      applyEngineConfig()
    }
  }
  public var spellingCheck: Bool {
    didSet {
      Defaults[.spellingCheck] = spellingCheck
      applyEngineConfig()
    }
  }
  public var secureInputActive = false
  public var tapStatus: TapStatus = .inactive
  /// How replacements are sent to the frontmost app (user override of the built-in default).
  public var activeStrategyOverride: SendingStrategyOverride = .automatic

  /// Per-app memory (last mode, pinned mode, sending strategy), persisted in `Defaults`.
  public private(set) var store: AppModeStore

  public var activeAppName = AppState.unknownApp
  public var activeAppDisplayName = ""

  let permission = PermissionMonitor()
  let inputProcessor: InputProcessor
  let eventHook: EventHook
  let bundleId: String

  /// Called when the mode really changed (not for every re-application), e.g. to flash a HUD.
  @ObservationIgnored var onModeChange: ((Bool, ModeChangeReason) -> Void)?

  static let unknownApp = "Unknown"

  @ObservationIgnored private var activationObserver: NSObjectProtocol?

  init() {
    bundleId = Bundle.main.bundleIdentifier ?? "com.khanhicetea.Caffee"

    let method = Defaults[.typingMethod]
    let zwjf = Defaults[.allowedZWJF]
    let placement = Defaults[.tonePlacement]
    let spelling = Defaults[.spellingCheck]
    typingMethod = method
    allowedZWJF = zwjf
    tonePlacement = placement
    spellingCheck = spelling
    store = AppModeStore.load()

    // One poster is shared so real keys can queue behind pending replacements.
    let poster = KeyEventPoster()
    let processor = InputProcessor(
      method: method,
      replacementSender: poster,
      config: EngineConfig(
        allowForeignConsonants: zwjf, tonePlacement: placement, spellingCheck: spelling))
    inputProcessor = processor
    eventHook = EventHook(inputProcessor: processor, poster: poster)
  }

  /// Registers the global hotkey and starts following the frontmost app.
  func start() {
    guard activationObserver == nil else { return }

    KeyboardShortcuts.onKeyUp(for: .toggleInputMode) { [weak self] in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.setEnabled(set: !self.enabled, reason: .hotkey)
      }
    }

    activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.syncFrontmostApp() }
    }
  }

  public var engineConfig: EngineConfig {
    EngineConfig(
      allowForeignConsonants: allowedZWJF, tonePlacement: tonePlacement,
      spellingCheck: spellingCheck)
  }

  private func applyEngineConfig() {
    inputProcessor.changeEngineConfig(engineConfig)
  }

  public func isNewAppVersion() -> Bool {
    let storedVersion = Defaults[.currentVersion]
    return storedVersion != "0.1" && Bundle.main.appVersionLong != storedVersion
  }

  public func storeTrustedAppVersion() {
    Defaults[.currentVersion] = Bundle.main.appVersionLong
  }

  public func setTypingMethod(method: TypingMethods) {
    typingMethod = method
  }

  public func setEnabled(set state: Bool, reason: ModeChangeReason = .menu) {
    let changed = enabled != state
    enabled = state
    if changed { onModeChange?(state, reason) }
  }

  // MARK: ModeControlling

  func apply(_ command: ModeCommand) {
    switch command {
    case .setVietnamese(let on): setEnabled(set: on, reason: .automation)
    case .toggle: setEnabled(set: !enabled, reason: .automation)
    case .setMethod(let method): typingMethod = method
    }
  }

  // MARK: Frontmost app

  /// Adopts the frontmost app: remembered mode and sending strategy.
  func syncFrontmostApp() {
    guard let activeApp = NSWorkspace.shared.frontmostApplication,
      let appName = activeApp.bundleIdentifier,
      appName != bundleId
    else { return }

    activeAppName = appName
    activeAppDisplayName = activeApp.localizedName ?? appName
    applyPerAppSettings()
  }

  /// Re-applies the stored settings of the frontmost app (after a switch or a settings edit).
  private func applyPerAppSettings() {
    activeStrategyOverride = store.strategy(for: activeAppName)
    inputProcessor.changeActiveApp(activeAppName)
    setEnabled(set: store.mode(for: activeAppName) ?? enabled, reason: .appSwitch)
  }

  private func edit(app: String, _ change: (inout AppModeStore) -> Void) {
    change(&store)
    store.save()
    if app == activeAppName { applyPerAppSettings() }
  }

  public func setPreference(_ preference: AppModePreference, for app: String) {
    edit(app: app) { $0.setPreference(preference, for: app) }
  }

  public func setStrategy(_ strategy: SendingStrategyOverride, for app: String) {
    edit(app: app) { $0.setStrategy(strategy, for: app) }
  }

  public func forget(app: String) {
    edit(app: app) { $0.forget(app) }
  }

  /// Sending strategy for the frontmost app (menu bar).
  public func setStrategyOverride(_ choice: SendingStrategyOverride) {
    guard activeAppName != AppState.unknownApp else { return }
    setStrategy(choice, for: activeAppName)
  }
}
