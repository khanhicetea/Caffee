//
//  AppState.swift
//  Caffee
//
//  Created by KhanhIceTea on 20/02/2024.
//

import Cocoa
import Combine
import Defaults
import Foundation
import KeyboardShortcuts

class AppState: ObservableObject, FileMonitorDelegate {

  private var cancellables = Set<AnyCancellable>()

  @Published public var enabled = false
  @Published public var typingMethod: TypingMethods
  @Published public var allowedZWJF: Bool

  public var inputProcessor: InputProcessor
  public var eventHook: EventHook
  public var appModes: [String: Bool] = [:]
  public var activeAppName = "Unknown"
  public var bundleId: String

  init() {
    bundleId = Bundle.main.bundleIdentifier ?? "com.khanhicetea.Caffee"

    let defaultMethod = Defaults[.typingMethod]
    typingMethod = defaultMethod
    allowedZWJF = Defaults[.allowedZWJF]
    inputProcessor = InputProcessor(method: defaultMethod)
    eventHook = EventHook(inputProcessor: inputProcessor)

    $enabled.sink { newState in
      self.appModes[self.activeAppName] = newState
      self.eventHook.setEnabled(newState)
    }.store(in: &cancellables)

    $typingMethod.sink { newState in
      self.inputProcessor.changeTypingMethod(newMethod: newState)
      Defaults[.typingMethod] = newState
    }.store(in: &cancellables)

    $allowedZWJF.sink { newState in
      if newState {
        TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon + TiengViet.PhuAmDonNuocNgoai
      } else {
        TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon
      }
      print(TiengViet.PhuAmDau)

      Defaults[.allowedZWJF] = newState
    }.store(in: &cancellables)

    KeyboardShortcuts.onKeyUp(for: .toggleInputMode) { [self] in
      self.setEnabled(set: !self.enabled)
    }

    // Register application change observer
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(activeApplicationDidChange),
      name: NSWorkspace.didActivateApplicationNotification, object: nil)
  }

  public func load() {
    // Load something later
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

  public func setEnabled(set state: Bool) {
    enabled = state
  }

  func registerSwitchFileMonitor() {
    let tmpPath = URL(fileURLWithPath: "/tmp/caffee_switch")
    try! "".write(to: tmpPath, atomically: true, encoding: .utf8)
    let fMonitor = try! FileMonitor(url: tmpPath)
    fMonitor.delegate = self
  }

  func didReceive(changes: String) {
    setEnabled(set: changes.trimmingCharacters(in: .whitespacesAndNewlines) == "vi")
  }

  @objc func activeApplicationDidChange(notification: Notification) {
    if let activeApp = NSWorkspace.shared.frontmostApplication,
      let appName = activeApp.bundleIdentifier,
      appName != bundleId
    {
      activeAppName = appName
      inputProcessor.changeActiveApp(activeAppName)

      if let appMode = appModes[activeAppName] {
        setEnabled(set: appMode)
      } else {
        setEnabled(set: enabled)
      }
    }
  }
}
