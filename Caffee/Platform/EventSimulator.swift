//
//  EventSimulator.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Foundation

class EventSimulator {
  // Compares two character arrays and determines the number of backspaces and differing characters needed.
  static func calcKeyStrokes(from prevStr: String, to currentStr: String) -> (Int, [Character]) {
    let prev = Array(prevStr)
    let current = Array(currentStr)
    var idx = 0
    var diffChars: [Character] = []
    while idx < prev.count && idx < current.count && current[idx] == prev[idx] {
      idx += 1
    }
    if idx < current.count {
      diffChars.append(contentsOf: current[idx...])
    }
    return (prev.count - idx, diffChars)
  }

  // Sends a specified number of backspace key events.
  static func sendBackspace(_ count: Int) {
    if count < 1 {
      return
    }

    if let source = CGEventSource(stateID: .combinedSessionState),
      let backspaceKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
      let backspaceKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
    {
      backspaceKeyDown.flags = .maskNonCoalesced
      backspaceKeyUp.flags = .maskNonCoalesced
      for _ in 1...count {
        backspaceKeyDown.post(tap: .cgSessionEventTap)
        backspaceKeyUp.post(tap: .cgSessionEventTap)
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
