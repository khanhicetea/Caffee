//
//  KeyEventPoster.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Foundation
import os

/// Strategy for sending keyboard events to replace text.
enum SendingStrategy: Equatable {
  /// Send all characters in a single batch event (fastest, may fail in some apps).
  case batch
  /// Send each character as individual key events (slowest, most compatible).
  case stepByStep
  /// Send as batch but with delays between backspaces (balanced approach).
  case hybrid(backspaceDelayMicroseconds: UInt32)
}

/// Posts synthetic keyboard events that replace what the user just typed.
///
/// One instance owns the serial queue every asynchronous strategy runs on. While jobs are
/// pending, the event tap must not let real key events overtake them: `EventHook` asks `isBusy`
/// and re-posts such keys through `repost(_:)`, which keeps them behind the queued replacement.
// Pending-job bookkeeping is guarded by `pendingLock`; jobs themselves run on one serial queue.
final class KeyEventPoster: ReplacementSender, @unchecked Sendable {
  /// Value stored in `.eventSourceUserData` of every event Caffee posts, so the tap can
  /// recognise (and ignore) its own output without rejecting other synthetic sources
  /// such as the on-screen keyboard or remote-desktop input.
  static let syntheticEventTag: Int64 = 0x4341_4646  // "CAFF"

  /// Many apps only honour ~20 UTF-16 units per synthetic keyboard event.
  private static let maxUnicodeUnitsPerEvent = 20

  // MARK: - Ordered output queue

  /// Strategies that sleep dispatch here so the CGEvent tap callback returns immediately
  /// (otherwise macOS disables the tap).
  private let simulationQueue = DispatchQueue(
    label: "com.khanhicetea.Caffee.keyEventPoster", qos: .userInteractive)
  private let pendingLock = NSLock()
  private var pendingJobs = 0

  /// True while at least one asynchronous replacement has not finished posting.
  var isBusy: Bool {
    pendingLock.lock()
    defer { pendingLock.unlock() }
    return pendingJobs > 0
  }

  private func enqueue(_ job: @escaping () -> Void) {
    nonisolated(unsafe) let job = job
    pendingLock.lock()
    pendingJobs += 1
    pendingLock.unlock()

    simulationQueue.async { [self] in
      job()
      pendingLock.lock()
      pendingJobs -= 1
      pendingLock.unlock()
    }
  }

  /// Runs `job` inline when nothing is pending, otherwise behind the pending work.
  private func runOrdered(forceAsync: Bool = false, _ job: @escaping () -> Void) {
    if forceAsync || isBusy {
      enqueue(job)
    } else {
      job()
    }
  }

  /// Re-posts a real key event behind pending replacement jobs, preserving order.
  func repost(_ event: CGEvent) {
    guard let copy = event.copy() else { return }
    Self.tag(copy)
    enqueue { copy.post(tap: .cgSessionEventTap) }
  }

  static func tag(_ event: CGEvent) {
    event.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
  }

  static func isSynthetic(_ event: CGEvent) -> Bool {
    event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag
  }

  // MARK: - Primitive senders

  private static func makeKeyPair(
    source: CGEventSource,
    virtualKey: CGKeyCode,
    flags: CGEventFlags = []
  ) -> (down: CGEvent, up: CGEvent)? {
    guard
      let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
    else { return nil }

    for event in [down, up] {
      event.flags = flags.union(.maskNonCoalesced)
      tag(event)
    }
    return (down, up)
  }

  private static func defaultSource(_ source: CGEventSource?) -> CGEventSource? {
    source ?? CGEventSource(stateID: .combinedSessionState)
  }

  static func sendBackspace(
    _ count: Int,
    source: CGEventSource? = nil,
    delayMicroseconds: UInt32 = 0
  ) {
    guard count > 0, let source = defaultSource(source),
      let pair = makeKeyPair(source: source, virtualKey: VirtualKey.delete)
    else { return }

    for index in 0..<count {
      pair.down.post(tap: .cgSessionEventTap)
      pair.up.post(tap: .cgSessionEventTap)

      if delayMicroseconds > 0 && index < count - 1 {
        usleep(delayMicroseconds)
      }
    }
  }

  /// Splits `str` into chunks of at most `limit` UTF-16 units without breaking a Character.
  static func unicodeChunks(of str: String, limit: Int = maxUnicodeUnitsPerEvent) -> [[UniChar]] {
    var chunks: [[UniChar]] = []
    var current: [UniChar] = []
    for char in str {
      let units = Array(String(char).utf16)
      if !current.isEmpty && current.count + units.count > limit {
        chunks.append(current)
        current = []
      }
      current.append(contentsOf: units)
    }
    if !current.isEmpty { chunks.append(current) }
    return chunks
  }

  private static func postUnicode(_ units: [UniChar], source: CGEventSource) {
    guard let pair = makeKeyPair(source: source, virtualKey: 0) else { return }
    pair.down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
    pair.up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
    pair.down.post(tap: .cgSessionEventTap)
    pair.up.post(tap: .cgSessionEventTap)
  }

  static func sendString(_ str: String, source: CGEventSource? = nil) {
    guard !str.isEmpty, let source = defaultSource(source) else { return }
    for chunk in unicodeChunks(of: str) {
      postUnicode(chunk, source: source)
    }
  }

  static func sendStringStepByStep(
    _ str: String,
    source: CGEventSource? = nil,
    delayMicroseconds: UInt32 = 500
  ) {
    guard !str.isEmpty else { return }
    guard let source = defaultSource(source) else { return }

    let chars = Array(str)
    for (index, char) in chars.enumerated() {
      postUnicode(Array(String(char).utf16), source: source)

      if delayMicroseconds > 0 && index < chars.count - 1 {
        usleep(delayMicroseconds)
      }
    }
  }

  // MARK: - Replacement

  func sendReplacement(_ replacement: Replacement, strategy: SendingStrategy) {
    let backspaceCount = replacement.deleteCount
    let diffChars = replacement.insert
    switch strategy {
    case .batch:
      // No delays; runs inline unless earlier async work is still pending.
      runOrdered {
        let source = CGEventSource(stateID: .privateState)
        Self.sendBackspace(backspaceCount, source: source, delayMicroseconds: 0)
        Self.sendString(String(diffChars), source: source)
      }

    case .stepByStep:
      runOrdered(forceAsync: true) {
        let source = CGEventSource(stateID: .privateState)
        Self.sendBackspace(backspaceCount, source: source, delayMicroseconds: 2000)
        usleep(3000)
        Self.sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
        usleep(3000)
      }

    case .hybrid(let backspaceDelay):
      runOrdered(forceAsync: true) {
        let source = CGEventSource(stateID: .privateState)
        Self.sendBackspace(backspaceCount, source: source, delayMicroseconds: backspaceDelay)
        Self.sendString(String(diffChars), source: source)
      }
    }
  }

  /// Sends Shift+Left arrow key events to select text to the left.
  /// This extends any existing selection (including inline autocomplete).
  static func sendShiftLeft(
    _ count: Int,
    source: CGEventSource? = nil
  ) {
    guard count > 0, let source = defaultSource(source),
      let pair = makeKeyPair(
        source: source, virtualKey: VirtualKey.leftArrow, flags: .maskShift)
    else { return }

    for _ in 0..<count {
      pair.down.post(tap: .cgSessionEventTap)
      pair.up.post(tap: .cgSessionEventTap)
    }
  }

  /// Uses Shift+Left to select characters then types replacement text.
  /// Unlike backspace-based replacement, Shift+Left naturally extends any
  /// existing inline autocomplete selection in browsers, so the replacement
  /// covers both the autocomplete text and the characters being modified.
  ///
  /// IMPORTANT: Only call this when there is currently highlighted text in the
  /// focused field (e.g. browser autocomplete ghost text). Canvas-based web
  /// editors like Google Docs ignore synthetic Shift+Left, so using this path
  /// there inserts the replacement after the old chars instead of replacing
  /// them. When no highlighted text is present, prefer the reliable backspace
  /// path (see `sendReplacement`).
  func sendSelectAndReplace(_ replacement: Replacement, strategy: SendingStrategy) {
    let selectLeftCount = replacement.deleteCount
    let diffChars = replacement.insert
    switch strategy {
    case .batch:
      runOrdered {
        let source = CGEventSource(stateID: .privateState)
        Self.sendShiftLeft(selectLeftCount, source: source)
        if !diffChars.isEmpty {
          Self.sendString(String(diffChars), source: source)
        } else if selectLeftCount > 0 {
          Self.sendBackspace(1, source: source)
        }
      }

    case .stepByStep:
      runOrdered(forceAsync: true) {
        let source = CGEventSource(stateID: .privateState)
        Self.sendShiftLeft(selectLeftCount, source: source)
        usleep(3000)
        if !diffChars.isEmpty {
          Self.sendStringStepByStep(String(diffChars), source: source, delayMicroseconds: 2000)
        } else if selectLeftCount > 0 {
          Self.sendBackspace(1, source: source)
        }
        usleep(3000)
      }

    case .hybrid(let backspaceDelay):
      runOrdered(forceAsync: true) {
        let source = CGEventSource(stateID: .privateState)
        Self.sendShiftLeft(selectLeftCount, source: source)
        usleep(backspaceDelay)
        if !diffChars.isEmpty {
          Self.sendString(String(diffChars), source: source)
        } else if selectLeftCount > 0 {
          Self.sendBackspace(1, source: source)
        }
      }
    }
  }
}
