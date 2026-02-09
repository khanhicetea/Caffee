import Cocoa
import Combine
import Defaults
import Foundation
import Sparkle
import SwiftUI
import Observation

// AppDelegate manages the application lifecycle and background services
@Observable
class AppDelegate: NSObject, NSApplicationDelegate {

  var appState = AppState()
  var isTrusted = false

  // Sparkle updater controller for auto-updates
  let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
  )

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