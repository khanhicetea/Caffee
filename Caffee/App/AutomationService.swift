//
//  AutomationService.swift
//  Caffee
//

import Foundation

/// A scripted request to change how Caffee types.
enum ModeCommand: Equatable {
  case setVietnamese(Bool)
  case toggle
  case setMethod(TypingMethods)

  /// Parses the text of the switch file: `vi`, `en`, `toggle`, `telex` or `vni`.
  static func parse(text: String) -> ModeCommand? {
    switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "vi": return .setVietnamese(true)
    case "en": return .setVietnamese(false)
    case "toggle": return .toggle
    case "telex": return .setMethod(.telex)
    case "vni": return .setMethod(.vni)
    default: return nil
    }
  }

  /// Parses `caffee://mode/vi|en|toggle` and `caffee://method/telex|vni`.
  static func parse(url: URL) -> ModeCommand? {
    guard url.scheme?.lowercased() == AutomationService.urlScheme,
      let kind = url.host?.lowercased()
    else { return nil }
    let value = url.pathComponents.dropFirst().first?.lowercased() ?? ""
    switch kind {
    case "mode" where ["vi", "en", "toggle"].contains(value): return parse(text: value)
    case "method" where ["telex", "vni"].contains(value): return parse(text: value)
    default: return nil
    }
  }
}

/// Something scripts can drive.
@MainActor
protocol ModeControlling: AnyObject {
  func apply(_ command: ModeCommand)
}

/// Entry points for scripting Caffee: the `caffee://` URL scheme and a control file.
///
/// ```
/// open caffee://mode/vi            # also: en, toggle
/// open caffee://method/telex       # also: vni
/// echo vi > ~/Library/Application\ Support/Caffee/switch
/// ```
@MainActor
final class AutomationService: FileMonitorDelegate {
  nonisolated static let urlScheme = "caffee"

  /// Lives in the user's own Application Support folder: unlike `/tmp`, other local users
  /// can neither pre-create nor write to it.
  nonisolated static var defaultSwitchFileURL: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Caffee", isDirectory: true)
      .appendingPathComponent("switch")
  }

  private weak var controller: ModeControlling?
  private let switchFileURL: URL
  private var monitor: FileMonitor?

  init(
    controller: ModeControlling, switchFileURL: URL = AutomationService.defaultSwitchFileURL
  ) {
    self.controller = controller
    self.switchFileURL = switchFileURL
  }

  /// Starts watching the control file (creating it if needed).
  func start() {
    guard monitor == nil else { return }
    let fileManager = FileManager.default
    do {
      try fileManager.createDirectory(
        at: switchFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      if !fileManager.fileExists(atPath: switchFileURL.path) {
        fileManager.createFile(atPath: switchFileURL.path, contents: nil)
      }
      let monitor = try FileMonitor(url: switchFileURL)
      monitor.delegate = self
      self.monitor = monitor
    } catch {
      Log.automation.error(
        "Cannot watch \(self.switchFileURL.path): \(error.localizedDescription)")
    }
  }

  func handle(url: URL) {
    guard let command = ModeCommand.parse(url: url) else {
      Log.automation.notice("Ignored URL \(url.absoluteString)")
      return
    }
    controller?.apply(command)
  }

  // MARK: FileMonitorDelegate

  nonisolated func didReceive(changes: String) {
    MainActor.assumeIsolated {
      guard let command = ModeCommand.parse(text: changes) else {
        Log.automation.notice("Ignored switch file content: \(changes)")
        return
      }
      controller?.apply(command)
    }
  }
}
