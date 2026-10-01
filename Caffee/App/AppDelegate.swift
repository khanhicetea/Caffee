import Cocoa
import Combine
import Defaults
import Foundation
import Sparkle
import SwiftUI
import Observation

// AppDelegate manages the application lifecycle and background services
@Observable
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {

  var appState = AppState()
  var isTrusted = false
  var updateItem: SUAppcastItem?

  // Sparkle updater controller for auto-updates
  var updaterController: SPUStandardUpdaterController!

  override init() {
    super.init()
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
  }

  private var cancellables = Set<AnyCancellable>()

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

    checkTrustStatus()

    if isTrusted {
      // Set up the event tap if the process is trusted
      appState.storeTrustedAppVersion()
      appState.eventHook.setupEventTap(give: appState)

      appState.load()
      appState.setEnabled(set: true)
      appState.registerSwitchFileMonitor()

    } else if appState.isNewAppVersion() {
      openUpgradeNewVersion()
    } else {
      openGuide()
    }
    
    // Periodically check trust status if not trusted
    if !isTrusted {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            self?.checkTrustStatus()
            if self?.isTrusted == true {
                timer.invalidate()
                self?.setupTrustedSession()
            }
        }
    }
  }
  
  func checkTrustStatus() {
      isTrusted = appState.eventHook.isTrusted(prompt: false)
  }
  
  func setupTrustedSession() {
      appState.storeTrustedAppVersion()
      appState.eventHook.setupEventTap(give: appState)
      appState.load()
      appState.setEnabled(set: true)
      appState.registerSwitchFileMonitor()
  }

  // Opens onboarding guide
  @objc func openGuide() {
    let contentView = OnboardingView().environment(appState)
    let windowController = OnboardingWindowController()
    windowController.contentViewController = NSHostingController(rootView: contentView)
    windowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  // Opens upgrade guide
  @objc func openUpgradeNewVersion() {
    let contentView = UpgradeAppView().environment(appState)
    let windowController = OnboardingWindowController()
    windowController.contentViewController = NSHostingController(rootView: contentView)
    windowController.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  // Opens settings window
  @objc func openSettings() {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.activate(ignoringOtherApps: true)
    }
  }

  // Secure Input belongs to the app that enabled it, not to Caffee.
  func showSecureInputHelp() {
    guard appState.eventHook.refreshSecureInputState() else { return }

    let alert = NSAlert()
    alert.messageText = "macOS đang bật Secure Input"
    alert.informativeText = """
      macOS đang chặn bộ gõ nhận bàn phím để bảo vệ dữ liệu nhạy cảm.

      Hãy đóng ô/hộp thoại nhập mật khẩu. Nếu đã chuyển sang ô văn bản thường mà vẫn bị khóa, hãy thoát và mở lại ứng dụng đã bật Secure Input (ví dụ: trình duyệt, Terminal hoặc ứng dụng quản lý mật khẩu).

      Caffee không thể tắt Secure Input của ứng dụng khác. Thoát và mở lại Caffee sẽ không gỡ được khóa này. Bộ gõ sẽ tự hoạt động lại khi ứng dụng đó nhả khóa.
      """
    alert.addButton(withTitle: "Đã hiểu")
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }

  // Quits the application
  @objc func quitApp() {
    NSApp.terminate(self)
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
  func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
    // This is called when the updater is about to schedule a background update check.
    // By implementing this method, we acknowledge that this is a background app
    // and Sparkle will not log the "gentle reminders" warning.
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    updateItem = item
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    updateItem = nil
  }
}