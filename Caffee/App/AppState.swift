//
//  AppState.swift
//  Caffee
//
//  Created by KhanhIceTea on 20/02/2024.
//

import Cocoa
import Observation
import Defaults
import Foundation
import KeyboardShortcuts

@Observable
class AppState: FileMonitorDelegate {

    public var enabled = false {
        didSet {
            self.appModes[self.activeAppName] = enabled
            self.eventHook.setEnabled(enabled)
        }
    }
    public var typingMethod: TypingMethods {
        didSet {
            self.inputProcessor.changeTypingMethod(newMethod: typingMethod)
            Defaults[.typingMethod] = typingMethod
        }
    }
    public var allowedZWJF: Bool {
        didSet {
            if allowedZWJF {
                TiengViet.PhuAmDau =
                    TiengViet.PhuAmGhep + TiengViet.PhuAmDon + TiengViet.PhuAmDonNuocNgoai
            } else {
                TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon
            }
            TiengViet.updatePhuAmDauTrie()

            Defaults[.allowedZWJF] = allowedZWJF
        }
    }
    public var secureInputActive = false

    public var inputProcessor: InputProcessor
    public var eventHook: EventHook
    public var appModes: [String: Bool] = [:]
    public var activeAppName = "Unknown"
    public var bundleId: String

    init() {
        bundleId = Bundle.main.bundleIdentifier ?? "com.khanhicetea.Caffee"

        let defaultMethod = Defaults[.typingMethod]
        // Use direct assignment to avoid didSet during init if not needed, 
        // but here we want to ensure side effects are consistent.
        // Actually, didSet does NOT run in init.
        typingMethod = defaultMethod
        allowedZWJF = Defaults[.allowedZWJF]
        
        let processor = InputProcessor(method: defaultMethod)
        inputProcessor = processor
        eventHook = EventHook(inputProcessor: processor)

        // Initial setup for allowedZWJF side effects since didSet doesn't run in init
        if allowedZWJF {
            TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon + TiengViet.PhuAmDonNuocNgoai
        } else {
            TiengViet.PhuAmDau = TiengViet.PhuAmGhep + TiengViet.PhuAmDon
        }
        TiengViet.updatePhuAmDauTrie()

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
        try? "".write(to: tmpPath, atomically: true, encoding: .utf8)
        let fMonitor = try? FileMonitor(url: tmpPath)
        fMonitor?.delegate = self
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