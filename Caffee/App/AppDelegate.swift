import Cocoa
import Combine
import Defaults
import Foundation
import Observation
import Sparkle
import SwiftUI

// AppDelegate manages the application lifecycle and composes the background services once.
@MainActor
@Observable
final class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {

  var appState = AppState()
  var updateItem: SUAppcastItem?

  /// Whether macOS has granted Accessibility to Caffee.
  var isTrusted: Bool { appState.permission.isTrusted }

  // Sparkle updater controller for auto-updates
  var updaterController: SPUStandardUpdaterController!

  @ObservationIgnored private lazy var automation = AutomationService(controller: appState)
  @ObservationIgnored private let secureInputHelp = SecureInputHelpPanel()
  @ObservationIgnored private var onboardingWindowController: OnboardingWindowController?
  @ObservationIgnored private var upgradeWindowController: OnboardingWindowController?
  @ObservationIgnored private var cancellables = Set<AnyCancellable>()

  override init() {
    super.init()
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hide dock icon since we use MenuBarExtra
    NSApp.setActivationPolicy(.accessory)

    // Sync Sparkle auto-update setting with user preference
    updaterController.updater.automaticallyChecksForUpdates =
      Defaults[.checkForUpdatesAutomatically]

    // Observe changes to the setting
    Defaults.publisher(.checkForUpdatesAutomatically)
      .sink { [weak self] change in
        self?.updaterController.updater.automaticallyChecksForUpdates = change.newValue
      }
      .store(in: &cancellables)

    appState.start()
    appState.onModeChange = { enabled, reason in
      // The menu already shows its own checkmark.
      guard reason != .menu, Defaults[.showModeHUD] else { return }
      ModeHUD.shared.show(vietnamese: enabled)
    }

    // Typing support starts as soon as Accessibility is granted, with no relaunch.
    appState.permission.onChange = { [weak self] trusted in
      if trusted { self?.setupTrustedSession() }
    }

    if appState.permission.refresh() {
      setupTrustedSession()
    } else {
      handleMissingPermission()
    }
  }

  private func handleMissingPermission() {
    appState.permission.start()

    guard appState.isNewAppVersion() else {
      openGuide()
      return
    }
    // The grant normally survives an update (stable signing identity), so give macOS a moment
    // before asking the user to toggle it again.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let self, !self.appState.permission.refresh() else { return }
      self.openUpgradeNewVersion()
    }
  }

  func setupTrustedSession() {
    appState.permission.stop()
    appState.storeTrustedAppVersion()
    appState.eventHook.setupEventTap(give: appState)
    appState.setEnabled(set: true, reason: .menu)
    automation.start()
    appState.syncFrontmostApp()
  }

  /// Retries creating the event tap after a failure (menu "Thử lại").
  func retryEventTap() {
    guard appState.permission.refresh() else { return }
    appState.eventHook.setupEventTap(give: appState)
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    urls.forEach(automation.handle(url:))
  }

  // Opens onboarding guide
  @objc func openGuide() {
    if !appState.permission.refresh() {
      appState.permission.start()
    }
    if let existing = onboardingWindowController, existing.window?.isVisible == true {
      existing.showWindow(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }
    let windowController = OnboardingWindowController()
    windowController.onClose = { [weak self] in
      self?.onboardingWindowController = nil
    }
    let contentView = OnboardingView { [weak self] in
      self?.closeOnboarding()
    }.environment(appState)
    windowController.contentViewController = NSHostingController(rootView: contentView)
    onboardingWindowController = windowController
    windowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func closeOnboarding() {
    let controller = onboardingWindowController
    onboardingWindowController = nil
    controller?.close()
  }

  // Opens upgrade guide
  @objc func openUpgradeNewVersion() {
    if !appState.permission.refresh() {
      appState.permission.start()
    }
    if let existing = upgradeWindowController, existing.window?.isVisible == true {
      existing.showWindow(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }
    let windowController = OnboardingWindowController(
      title: "Caffee - Cập Nhật",
      frameAutosaveName: "Upgrade Window",
      contentSize: NSSize(width: 520, height: 480)
    )
    windowController.onClose = { [weak self] in
      self?.upgradeWindowController = nil
    }
    let contentView = UpgradeAppView { [weak self] in
      self?.closeUpgradeWindow()
    }.environment(appState)
    windowController.contentViewController = NSHostingController(rootView: contentView)
    upgradeWindowController = windowController
    windowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func closeUpgradeWindow() {
    let controller = upgradeWindowController
    upgradeWindowController = nil
    controller?.close()
  }

  // Secure Input belongs to the app that enabled it, not to Caffee.
  func showSecureInputHelp() {
    guard appState.eventHook.refreshSecureInputState() else { return }
    secureInputHelp.show(holder: SecureInputInfo.holder())
  }

  // Returns true to opt-in to secure coding for state restoration
  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Cleans up before the application terminates
  func applicationWillTerminate(_ aNotification: Notification) {
    appState.eventHook.destroy()
  }
}

extension AppDelegate {
  nonisolated func updater(
    _ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval
  ) {
    // This is called when the updater is about to schedule a background update check.
    // By implementing this method, we acknowledge that this is a background app
    // and Sparkle will not log the "gentle reminders" warning.
  }

  nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    // Sparkle calls its delegate on the main thread.
    nonisolated(unsafe) let item = item
    MainActor.assumeIsolated { updateItem = item }
  }

  nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    MainActor.assumeIsolated { updateItem = nil }
  }
}
