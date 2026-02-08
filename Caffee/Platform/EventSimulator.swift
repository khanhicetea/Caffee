//
//  EventSimulator.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Foundation

/// Strategy for sending keyboard events to replace text.
enum SendingStrategy {
  /// Send all characters in a single batch event (fastest, may fail in some apps).
  case batch
  /// Send each character as individual key events (slowest, most compatible).
  case stepByStep
  /// Send as batch but with delays between backspaces (balanced approach).
  case hybrid(backspaceDelayMicroseconds: UInt32)
}

/// Configuration for per-app event sending strategies.
struct AppSendingConfig {
  /// Bundle ID prefix to match.
  let bundlePrefix: String
  /// Sending strategy for this app.
  let strategy: SendingStrategy
  /// Human-readable name for logging.
  let name: String
}

class EventSimulator {
  /// Per-app sending strategy configuration.
  /// Apps are checked in order - first match wins.
  /// Apps not listed use the default batch strategy.
  static let appStrategies: [AppSendingConfig] = [
    AppSendingConfig(bundlePrefix: "com.microsoft.VSCode", strategy: .stepByStep, name: "VS Code"),
    AppSendingConfig(bundlePrefix: "com.electron", strategy: .stepByStep, name: "Electron Apps"),
    AppSendingConfig(bundlePrefix: "com.hnc.Discord", strategy: .stepByStep, name: "Discord"),
    AppSendingConfig(bundlePrefix: "com.tinyspeck.slackmacgap", strategy: .stepByStep, name: "Slack"),
    AppSendingConfig(bundlePrefix: "com.spotify.client", strategy: .stepByStep, name: "Spotify"),

    AppSendingConfig(bundlePrefix: "com.google.Chrome", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Chrome"),
    AppSendingConfig(bundlePrefix: "org.chromium.Chromium", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Chromium"),
    AppSendingConfig(bundlePrefix: "com.brave.Browser", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Brave"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Edge", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Edge"),
    AppSendingConfig(bundlePrefix: "com.microsoft.edge", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Edge (Legacy)"),
    AppSendingConfig(bundlePrefix: "company.thebrowser.Browser", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Arc"),
    AppSendingConfig(bundlePrefix: "com.vivaldi.Vivaldi", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Vivaldi"),
    AppSendingConfig(bundlePrefix: "com.operasoftware.Opera", strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Opera"),
    AppSendingConfig(bundlePrefix: "org.mozilla.firefox", strategy: .hybrid(backspaceDelayMicroseconds: 600), name: "Firefox"),
    AppSendingConfig(bundlePrefix: "org.mozilla.nightly", strategy: .hybrid(backspaceDelayMicroseconds: 600), name: "Firefox Nightly"),

    AppSendingConfig(bundlePrefix: "com.microsoft.Word", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Word"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Excel", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Excel"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Powerpoint", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "PowerPoint"),
    AppSendingConfig(bundlePrefix: "com.microsoft.Outlook", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Outlook"),
    AppSendingConfig(bundlePrefix: "com.microsoft.onenote.mac", strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "OneNote"),

    AppSendingConfig(bundlePrefix: "com.apple.Terminal", strategy: .stepByStep, name: "Terminal"),
    AppSendingConfig(bundlePrefix: "com.googlecode.iterm2", strategy: .stepByStep, name: "iTerm2"),
    AppSendingConfig(bundlePrefix: "net.kovidgoyal.kitty", strategy: .stepByStep, name: "Kitty"),
    AppSendingConfig(bundlePrefix: "com.mitchellh.ghostty", strategy: .stepByStep, name: "Ghostty"),
    AppSendingConfig(bundlePrefix: "com.warp.Warp", strategy: .stepByStep, name: "Warp"),
    AppSendingConfig(bundlePrefix: "co.zeit.hyper", strategy: .stepByStep, name: "Hyper"),
    AppSendingConfig(bundlePrefix: "org.tabby", strategy: .stepByStep, name: "Tabby"),
    AppSendingConfig(bundlePrefix: "com.electron.alacritty", strategy: .stepByStep, name: "Alacritty"),
  ]

  static func getStrategy(for bundleId: String) -> SendingStrategy {
    appStrategies.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.strategy ?? .batch
  }

  static func getAppName(for bundleId: String) -> String {
    appStrategies.first(where: { bundleId.hasPrefix($0.bundlePrefix) })?.name ?? "Unknown App"
  }

  static func calcKeyStrokes(from: String, to: String) -> (Int, [Character]) {
    let fromChars = Array(from)
    let toChars = Array(to)
    var commonPrefixLength = 0
    let minLength = min(fromChars.count, toChars.count)

    while commonPrefixLength < minLength
      && fromChars[commonPrefixLength] == toChars[commonPrefixLength]
    {
      commonPrefixLength += 1
    }

    let backspaceCount = fromChars.count - commonPrefixLength
    let diffChars = Array(toChars.dropFirst(commonPrefixLength))

    return (backspaceCount, diffChars)
  }

  static func sendBackspace(
    _ count: Int,
    source: CGEventSource? = nil,
    delayMicroseconds: UInt32 = 0
  ) {
    guard count > 0 else { return }

    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

    guard
      let source = eventSource,
      let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
      let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
    else {
      return
    }

    downEvent.flags = .maskNonCoalesced
    upEvent.flags = .maskNonCoalesced

    for index in 0..<count {
      downEvent.post(tap: .cgSessionEventTap)
      upEvent.post(tap: .cgSessionEventTap)

      if delayMicroseconds > 0 && index < count - 1 {
        usleep(delayMicroseconds)
      }
    }
  }

  static func sendString(_ str: String, source: CGEventSource? = nil) {
    guard !str.isEmpty else { return }

    let uniChars = str.utf16.map { UniChar($0) }
    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

    guard
      let source = eventSource,
      let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
      let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
    else {
      return
    }

    downEvent.flags = .maskNonCoalesced
    upEvent.flags = .maskNonCoalesced

    downEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
    upEvent.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)

    downEvent.post(tap: .cgSessionEventTap)
    upEvent.post(tap: .cgSessionEventTap)
  }

  static func sendStringStepByStep(
    _ str: String,
    source: CGEventSource? = nil,
    delayMicroseconds: UInt32 = 500
  ) {
    guard !str.isEmpty else { return }

    let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)
    guard let source = eventSource else {
      sendString(str)
      return
    }

    let chars = Array(str)
    for (index, char) in chars.enumerated() {
      guard let scalar = char.unicodeScalars.first else { continue }
      let uniChar = UniChar(scalar.value)

      if
        let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
        let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
      {
        downEvent.flags = .maskNonCoalesced
        upEvent.flags = .maskNonCoalesced

        downEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])
        upEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])

        downEvent.post(tap: .cgSessionEventTap)
        upEvent.post(tap: .cgSessionEventTap)
      }

      if delayMicroseconds > 0 && index < chars.count - 1 {
        usleep(delayMicroseconds)
      }
    }
  }

  static func sendReplacement(
    backspaceCount: Int,
    diffChars: [Character],
    strategy: SendingStrategy
  ) {
    let source = CGEventSource(stateID: .privateState)

    switch strategy {
    case .batch:
      sendBackspace(backspaceCount, source: source, delayMicroseconds: 0)
      sendString(String(diffChars), source: source)

    case .stepByStep:
      sendBackspace(backspaceCount, source: source, delayMicroseconds: 2000)
      usleep(3000)
      sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
      usleep(3000)

    case .hybrid(let backspaceDelay):
      sendBackspace(backspaceCount, source: source, delayMicroseconds: backspaceDelay)
      sendString(String(diffChars), source: source)

    }
  }
}
