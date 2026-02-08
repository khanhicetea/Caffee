//
//  EventSimulator.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Foundation

/// Strategy for sending keyboard events to replace text
enum SendingStrategy {
    /// Send all characters in a single batch event (fastest, may fail in some apps)
    case batch
    /// Send each character as individual key events (slowest, most compatible)
    case stepByStep
    /// Send as batch but with delays between backspaces (balanced approach)
    case hybrid(backspaceDelayMicroseconds: UInt32)
    /// Use arrow keys to navigate, type chars, then navigate back and delete (for terminal apps)
    /// Moves cursor left N times, types new chars, moves right N times, then N backspaces
    case arrowsMoving
}

/// Configuration for per-app event sending strategies
struct AppSendingConfig {
    /// Bundle ID prefix to match
    let bundlePrefix: String
    /// Sending strategy for this app
    let strategy: SendingStrategy
    /// Human-readable name for logging
    let name: String
}

class EventSimulator {
    /// Per-app sending strategy configuration.
    /// Apps are checked in order - first match wins.
    /// Apps not listed use the default batch strategy.
    static let AppStrategies: [AppSendingConfig] = [
        // Electron-based apps - need step-by-step for reliability
        AppSendingConfig(
            bundlePrefix: "com.microsoft.VSCode", strategy: .stepByStep, name: "VS Code"),
        AppSendingConfig(
            bundlePrefix: "com.electron", strategy: .stepByStep, name: "Electron Apps"),
        AppSendingConfig(bundlePrefix: "com.hnc.Discord", strategy: .stepByStep, name: "Discord"),
        AppSendingConfig(
            bundlePrefix: "com.tinyspeck.slackmacgap", strategy: .stepByStep, name: "Slack"),
        AppSendingConfig(
            bundlePrefix: "com.spotify.client", strategy: .stepByStep, name: "Spotify"),

        // Browsers - use hybrid with moderate delay
        AppSendingConfig(
            bundlePrefix: "com.google.Chrome", strategy: .hybrid(backspaceDelayMicroseconds: 800),
            name: "Chrome"),
        AppSendingConfig(
            bundlePrefix: "org.chromium.Chromium",
            strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Chromium"),
        AppSendingConfig(
            bundlePrefix: "com.brave.Browser", strategy: .hybrid(backspaceDelayMicroseconds: 800),
            name: "Brave"),
        AppSendingConfig(
            bundlePrefix: "com.microsoft.Edge", strategy: .hybrid(backspaceDelayMicroseconds: 800),
            name: "Edge"),
        AppSendingConfig(
            bundlePrefix: "com.microsoft.edge", strategy: .hybrid(backspaceDelayMicroseconds: 800),
            name: "Edge (Legacy)"),
        AppSendingConfig(
            bundlePrefix: "company.thebrowser.Browser",
            strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Arc"),
        AppSendingConfig(
            bundlePrefix: "com.vivaldi.Vivaldi", strategy: .hybrid(backspaceDelayMicroseconds: 800),
            name: "Vivaldi"),
        AppSendingConfig(
            bundlePrefix: "com.operasoftware.Opera",
            strategy: .hybrid(backspaceDelayMicroseconds: 800), name: "Opera"),
        AppSendingConfig(
            bundlePrefix: "org.mozilla.firefox", strategy: .hybrid(backspaceDelayMicroseconds: 600),
            name: "Firefox"),
        AppSendingConfig(
            bundlePrefix: "org.mozilla.nightly", strategy: .hybrid(backspaceDelayMicroseconds: 600),
            name: "Firefox Nightly"),

        // Microsoft Office apps - hybrid with higher delay
        AppSendingConfig(
            bundlePrefix: "com.microsoft.Word", strategy: .hybrid(backspaceDelayMicroseconds: 1000),
            name: "Word"),
        AppSendingConfig(
            bundlePrefix: "com.microsoft.Excel",
            strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Excel"),
        AppSendingConfig(
            bundlePrefix: "com.microsoft.Powerpoint",
            strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "PowerPoint"),
        AppSendingConfig(
            bundlePrefix: "com.microsoft.Outlook",
            strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "Outlook"),
        AppSendingConfig(
            bundlePrefix: "com.microsoft.onenote.mac",
            strategy: .hybrid(backspaceDelayMicroseconds: 1000), name: "OneNote"),

        // Terminal apps - use arrow keys strategy for better compatibility
        AppSendingConfig(
            bundlePrefix: "com.apple.Terminal", strategy: .stepByStep, name: "Terminal"),
        AppSendingConfig(
            bundlePrefix: "com.googlecode.iterm2", strategy: .stepByStep, name: "iTerm2"),
        AppSendingConfig(
            bundlePrefix: "net.kovidgoyal.kitty", strategy: .stepByStep, name: "Kitty"),
        AppSendingConfig(
            bundlePrefix: "com.mitchellh.ghostty", strategy: .stepByStep, name: "Ghostty"),
        AppSendingConfig(bundlePrefix: "com.warp.Warp", strategy: .stepByStep, name: "Warp"),
        AppSendingConfig(bundlePrefix: "co.zeit.hyper", strategy: .stepByStep, name: "Hyper"),
        AppSendingConfig(bundlePrefix: "org.tabby", strategy: .stepByStep, name: "Tabby"),
        AppSendingConfig(
            bundlePrefix: "com.electron.alacritty", strategy: .stepByStep, name: "Alacritty"),
    ]

    /// Gets the sending strategy for a given app bundle ID
    static func getStrategy(for bundleId: String) -> SendingStrategy {
        for config in AppStrategies {
            if bundleId.hasPrefix(config.bundlePrefix) {
                return config.strategy
            }
        }
        return .batch  // Default: fast batch mode for native apps
    }

    /// Gets the human-readable app name for logging
    static func getAppName(for bundleId: String) -> String {
        for config in AppStrategies {
            if bundleId.hasPrefix(config.bundlePrefix) {
                return config.name
            }
        }
        return "Unknown App"
    }
    /// Compares two strings and determines the number of backspaces and differing characters needed.
    /// Uses zip() for cleaner iteration with early termination at first difference.
    static func calcKeyStrokes(from prevStr: String, to currentStr: String) -> (Int, [Character]) {
        let prev = Array(prevStr)
        let current = Array(currentStr)

        // Find first differing index using zip (stops at shorter array)
        let commonPrefixLength = zip(prev, current).prefix(while: { $0 == $1 }).count

        // Characters to type after backspacing
        let diffChars =
            commonPrefixLength < current.count
            ? Array(current[commonPrefixLength...])
            : []

        // Number of backspaces = characters to delete from prev after common prefix
        return (prev.count - commonPrefixLength, diffChars)
    }

    /// Sends a specified number of backspace key events.
    ///
    /// - Parameters:
    ///   - count: Number of backspaces to send
    ///   - source: The CGEventSource to use for creating events (for synchronization)
    ///   - delayMicroseconds: Delay between each backspace pair (0 = no delay).
    ///     Some apps (Electron, browsers) may drop rapid events due to coalescing.
    ///     Recommended values:
    ///     - Native macOS apps: 0
    ///     - Browsers: 500-1000 μs
    ///     - Electron apps: 1000-2000 μs
    static func sendBackspace(
        _ count: Int, source: CGEventSource? = nil, delayMicroseconds: UInt32 = 0
    ) {
        if count < 1 {
            return
        }

        let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

        if let source = eventSource,
            let backspaceKeyDown = CGEvent(
                keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
            let backspaceKeyUp = CGEvent(
                keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
        {
            backspaceKeyDown.flags = .maskNonCoalesced
            backspaceKeyUp.flags = .maskNonCoalesced

            for i in 1...count {
                backspaceKeyDown.post(tap: .cgSessionEventTap)
                // backspaceKeyUp.post(tap: .cgSessionEventTap)

                // Add delay between backspaces for apps that coalesce rapid events
                // Skip delay after last backspace (no need to wait)
                if delayMicroseconds > 0 && i < count {
                    usleep(delayMicroseconds)
                }
            }
        }
    }

    /// Sends a string as a series of key events.
    /// - Parameters:
    ///   - str: The string to send
    ///   - source: The CGEventSource to use for creating events (for synchronization)
    static func sendString(_ str: String, source: CGEventSource? = nil) {
        if str.count < 1 {
            return
        }

        let uniChars = [UniChar](str.utf16)
        let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

        if let source = eventSource,
            let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        {
            downEvent.flags = .maskNonCoalesced
            upEvent.flags = .maskNonCoalesced

            downEvent.keyboardSetUnicodeString(stringLength: str.count, unicodeString: uniChars)
            upEvent.keyboardSetUnicodeString(stringLength: str.count, unicodeString: uniChars)

            downEvent.post(tap: .cgSessionEventTap)
            upEvent.post(tap: .cgSessionEventTap)
        }
    }

    /// Sends a string character by character with individual key events.
    /// This is slower but works reliably in apps with event coalescing issues.
    /// - Parameters:
    ///   - str: The string to send
    ///   - source: The CGEventSource to use for creating events (for synchronization)
    ///   - delayMicroseconds: Delay between each character (default 500μs)
    static func sendStringStepByStep(
        _ str: String, source: CGEventSource? = nil, delayMicroseconds: UInt32 = 500
    ) {
        if str.count < 1 {
            return
        }

        let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

        guard let source = eventSource else {
            // Fallback to batch mode if we can't create source
            sendString(str)
            return
        }

        let chars = Array(str)
        for (index, char) in chars.enumerated() {
            let uniChar = UniChar(char.unicodeScalars.first!.value)

            if let downEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            {
                downEvent.flags = .maskNonCoalesced
                upEvent.flags = .maskNonCoalesced

                downEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])
                upEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [uniChar])

                downEvent.post(tap: .cgSessionEventTap)
                upEvent.post(tap: .cgSessionEventTap)
            }

            // Add small delay between characters, but not after the last one
            if delayMicroseconds > 0 && index < chars.count - 1 {
                usleep(delayMicroseconds)
            }
        }
    }

    /// Sends text replacement using the specified strategy.
    /// - Parameters:
    ///   - backspaceCount: Number of backspaces to send
    ///   - diffChars: Characters to type after backspacing
    ///   - strategy: The sending strategy to use
    static func sendReplacement(
        backspaceCount: Int,
        diffChars: [Character],
        strategy: SendingStrategy
    ) {
        // Create a single event source for all events in this batch
        let source = CGEventSource(stateID: .privateState)

        switch strategy {
        case .batch:
            sendBackspace(backspaceCount, source: source, delayMicroseconds: 0)
            sendString(String(diffChars), source: source)

        case .stepByStep:
            // In step-by-step mode, we send backspaces individually too
            print("Sending step by step...")
            sendBackspace(backspaceCount, source: source, delayMicroseconds: 2000)
            usleep(3000)
            sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
            usleep(3000)

        case .hybrid(let backspaceDelay):
            sendBackspace(backspaceCount, source: source, delayMicroseconds: backspaceDelay)
            sendString(String(diffChars), source: source)

        // TODO : LATER
        case .arrowsMoving:
            // For terminal apps: use arrow key navigation
            // Move cursor left N times, type new chars, move right N times, then N backspaces
            sendArrowKeys(.left, count: backspaceCount, source: source)
            sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 100)
            sendArrowKeys(.right, count: backspaceCount, source: source)
            sendBackspace(backspaceCount, source: source, delayMicroseconds: 100)
        }
    }

    /// Arrow key direction
    enum ArrowDirection {
        case left
        case right
        case up
        case down

        var keyCode: CGKeyCode {
            switch self {
            case .left: return 0x7B  // kVK_LeftArrow
            case .right: return 0x7C  // kVK_RightArrow
            case .down: return 0x7D  // kVK_DownArrow
            case .up: return 0x7E  // kVK_UpArrow
            }
        }
    }

    /// Sends arrow key events
    /// - Parameters:
    ///   - direction: Which arrow key to send
    ///   - count: Number of times to send
    ///   - source: The CGEventSource to use for creating events (for synchronization)
    ///   - delayMicroseconds: Delay between each key event
    static func sendArrowKeys(
        _ direction: ArrowDirection, count: Int, source: CGEventSource? = nil,
        delayMicroseconds: UInt32 = 100
    ) {
        if count < 1 {
            return
        }

        let eventSource = source ?? CGEventSource(stateID: .combinedSessionState)

        guard let source = eventSource,
            let downEvent = CGEvent(
                keyboardEventSource: source, virtualKey: direction.keyCode, keyDown: true),
            let upEvent = CGEvent(
                keyboardEventSource: source, virtualKey: direction.keyCode, keyDown: false)
        else {
            return
        }

        downEvent.flags = .maskNonCoalesced
        upEvent.flags = .maskNonCoalesced

        for i in 1...count {
            downEvent.post(tap: .cgSessionEventTap)
            upEvent.post(tap: .cgSessionEventTap)

            if delayMicroseconds > 0 && i < count {
                usleep(delayMicroseconds)
            }
        }
    }
}
