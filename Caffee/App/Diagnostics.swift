//
//  Diagnostics.swift
//  Caffee
//

import Carbon
import Foundation
import OSLog

/// Builds a plain-text report users can attach to a bug report.
@MainActor
enum Diagnostics {
  static func report(for appState: AppState) -> String {
    let info = Bundle.main
    var lines = [
      "Caffee \(info.appVersionLong) (\(info.appBuild))",
      "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "Keyboard layout: \(currentInputSourceID() ?? "unknown")",
      "",
      "Typing method: \(appState.typingMethod.rawValue)",
      "Vietnamese enabled: \(appState.enabled)",
      "Foreign consonants (z, w, j, f): \(appState.allowedZWJF)",
      "Tone placement: \(appState.tonePlacement.rawValue)",
      "Spelling check: \(appState.spellingCheck)",
      "",
      "Accessibility trusted: \(appState.permission.isTrusted)",
      "Event tap: \(appState.tapStatus)",
      "Event tap auto-recoveries: \(appState.eventHook.tapRecoveryCount)",
      "Secure Input active: \(appState.secureInputActive)",
      "",
      "Frontmost app: \(appState.activeAppName)",
      "Sending strategy override: \(appState.activeStrategyOverride.rawValue)",
    ]

    let store = appState.store
    if !store.knownApps.isEmpty {
      lines.append("")
      lines.append("Per-app settings:")
      for app in store.knownApps {
        lines.append(
          "  \(app): mode=\(store.preference(for: app).rawValue)"
            + " remembered=\(store.remembered[app].map(String.init) ?? "-")"
            + " strategy=\(store.strategy(for: app).rawValue)")
      }
    }

    let logs = recentLogs(limit: 100)
    if !logs.isEmpty {
      lines.append("")
      lines.append("Recent log (\(logs.count) entries):")
      lines.append(contentsOf: logs)
    }
    return lines.joined(separator: "\n")
  }

  private static func currentInputSourceID() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
      let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
    else { return nil }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
  }

  private static func recentLogs(limit: Int) -> [String] {
    guard let store = try? OSLogStore(scope: .currentProcessIdentifier),
      let entries = try? store.getEntries(
        matching: NSPredicate(format: "subsystem == %@", Log.subsystem))
    else { return [] }
    let formatter = ISO8601DateFormatter()
    return
      entries
      .compactMap { $0 as? OSLogEntryLog }
      .suffix(limit)
      .map { "\(formatter.string(from: $0.date)) [\($0.category)] \($0.composedMessage)" }
  }
}
