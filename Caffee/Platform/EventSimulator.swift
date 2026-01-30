//
//  EventSimulator.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Foundation

class EventSimulator {
  /// Compares two strings and determines the number of backspaces and differing characters needed.
  /// Uses zip() for cleaner iteration with early termination at first difference.
  static func calcKeyStrokes(from prevStr: String, to currentStr: String) -> (Int, [Character]) {
    let prev = Array(prevStr)
    let current = Array(currentStr)

    // Find first differing index using zip (stops at shorter array)
    let commonPrefixLength = zip(prev, current).prefix(while: { $0 == $1 }).count

    // Characters to type after backspacing
    let diffChars = commonPrefixLength < current.count
      ? Array(current[commonPrefixLength...])
      : []

    // Number of backspaces = characters to delete from prev after common prefix
    return (prev.count - commonPrefixLength, diffChars)
  }

  /// Sends a specified number of backspace key events.
  ///
  /// - Parameters:
  ///   - count: Number of backspaces to send
  ///   - delayMicroseconds: Delay between each backspace pair (0 = no delay).
  ///     Some apps (Electron, browsers) may drop rapid events due to coalescing.
  ///     Recommended values:
  ///     - Native macOS apps: 0
  ///     - Browsers: 500-1000 μs
  ///     - Electron apps: 1000-2000 μs
  static func sendBackspace(_ count: Int, delayMicroseconds: UInt32 = 0) {
    if count < 1 {
      return
    }

    if let source = CGEventSource(stateID: .combinedSessionState),
      let backspaceKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
      let backspaceKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
    {
      backspaceKeyDown.flags = .maskNonCoalesced
      backspaceKeyUp.flags = .maskNonCoalesced

      for i in 1...count {
        backspaceKeyDown.post(tap: .cgSessionEventTap)
        backspaceKeyUp.post(tap: .cgSessionEventTap)

        // Add delay between backspaces for apps that coalesce rapid events
        // Skip delay after last backspace (no need to wait)
        if delayMicroseconds > 0 && i < count {
          usleep(delayMicroseconds)
        }
      }
    }
  }

  // Sends a string as a series of key events.
  static func sendString(_ str: String) {
    if str.count < 1 {
      return
    }

    let uniChars = [UniChar](str.utf16)

    if let source = CGEventSource(stateID: .combinedSessionState),
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
}
