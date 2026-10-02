//
//  InputProcessor.swift
//  Caffee
//
//  Created by KhanhIceTea on 24/02/2024.
//

import AppKit
import CoreGraphics
import Foundation

// MARK: - WordBuffer

/// WordBuffer manages the Vietnamese word state during typing.
/// It tracks the current word being typed, handles push/pop operations,
/// and manages recovery mode with a snapshot stack for multi-step rollback.
struct WordBuffer {

  struct Snapshot {
    let wordState: TiengVietState
    let keys: [Character]
    let transformed: String
    let stopProcessing: Bool
  }

  var keys: [Character] = []
  var stopProcessing = false
  var lastTransformed = ""
  var transformed = ""

  var previousWordState: TiengVietState?
  var wordState = TiengVietState.empty

  /// Engine options applied to every word started from this buffer.
  var config = EngineConfig() {
    didSet { wordState = .empty(config: config) }
  }

  /// Last valid snapshot for single-step rollback out of recovery mode.
  var lastValidSnapshot: Snapshot?

  // MARK: - Word Lifecycle

  mutating func newWord(storePrevious: Bool = false) {
    previousWordState = nil
    if !wordState.isBlank && storePrevious {
      previousWordState = wordState
    }
    wordState = .empty(config: config)

    keys = []
    lastValidSnapshot = nil
    stopProcessing = false
    lastTransformed = ""
    transformed = ""
  }

  // MARK: - Pop (Backspace)

  mutating func pop(engine: TypingMethod) -> Replacement {
    lastTransformed = transformed

    // Single-step rollback: if we are in recovery and it was caused by the LATEST keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      lastValidSnapshot = nil

      return Self.letSystemDeleteOneCharacter(
        Replacement.diff(from: lastTransformed, to: transformed))
    }

    // Normal pop: restore previous word on empty buffer
    if wordState.isBlank, let prev = previousWordState {
      wordState = prev
      previousWordState = nil
      keys = Array(wordState.chuKhongDau)
      transformed = wordState.transformed
      lastTransformed = transformed
      stopProcessing = false
      lastValidSnapshot = nil
      return .none  // Let OS handle the backspace that brought us here
    }

    // Normal pop: remove last character
    wordState = engine.pop(state: wordState)
    keys = Array(wordState.chuKhongDau)
    stopProcessing = wordState.needsRecovery

    if stopProcessing {
      transformed = String(keys)
    } else {
      transformed = wordState.transformed
    }

    lastValidSnapshot = nil

    return Self.letSystemDeleteOneCharacter(
      Replacement.diff(from: lastTransformed, to: transformed))
  }

  /// A plain one-character deletion is already what the Backspace key does: let it through.
  private static func letSystemDeleteOneCharacter(_ replacement: Replacement) -> Replacement {
    replacement.deleteCount == 1 && replacement.insert.isEmpty ? .none : replacement
  }

  // MARK: - Push (New Character)

  mutating func push(char: Character, engine: TypingMethod) {
    // Save current state before mutation
    let snapshot = Snapshot(
      wordState: wordState,
      keys: keys,
      transformed: transformed,
      stopProcessing: stopProcessing
    )

    keys.append(char)
    lastTransformed = transformed

    if stopProcessing {
      transformed.append(char)
      wordState = wordState.push(char)
      return
    }

    let result = engine.push(char: char, keyStr: String(keys), state: wordState)

    switch result {
    case .insertRaw(let newState), .applyMark(let newState):
      wordState = newState
      stopProcessing = false
      transformed = wordState.transformed
      // Clear snapshot when we're in valid state; no rollback needed
      lastValidSnapshot = nil

    case .toggleToRaw(let newState):
      wordState = newState
      stopProcessing = true
      transformed = wordState.originalInput
      lastValidSnapshot = nil

    case .recover(let newState):
      wordState = newState
      stopProcessing = true
      // Use keys array which contains ALL typed characters (including tone marks like 's', 'f' etc.)
      transformed = String(keys)

      // If we JUST entered recovery mode, save the snapshot for rollback
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }

    case .noChange(let newState):
      wordState = newState
      transformed = lastTransformed
      lastValidSnapshot = nil
    }
  }
}

// MARK: - InputProcessor

class InputProcessor {
  static let newWordKeys: Set<Character> = Set("`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?")
  static let newWordTaskKeys: [TaskKey] = [.enter, .space, .tab]

  public var engine: TypingMethod
  public var typingMethod: TypingMethods
  var keyboardLayout: KeyboardLayout
  var replacementSender: ReplacementSender
  var selectionDetector: SelectionDetector
  var compatibilityPolicy: AppCompatibilityPolicy
  public var activeApp = ""

  /// Word buffer manages the current word state
  var wordBuffer = WordBuffer()

  /// How replacements are delivered to the active app.
  private(set) var sendingStrategy: SendingStrategy = .batch

  // MARK: - Init & Configuration

  init(
    method: TypingMethods,
    keyboardLayout: KeyboardLayout = KeyboardUS(),
    replacementSender: ReplacementSender = KeyEventPoster(),
    selectionDetector: SelectionDetector = AccessibilitySelectionDetector(),
    compatibilityPolicy: AppCompatibilityPolicy = DefaultAppCompatibilityPolicy(),
    config: EngineConfig = EngineConfig()
  ) {
    typingMethod = method
    engine = typingMethod == .telex ? Telex() : VNI()
    wordBuffer.config = config
    self.keyboardLayout = keyboardLayout
    self.replacementSender = replacementSender
    self.selectionDetector = selectionDetector
    self.compatibilityPolicy = compatibilityPolicy
  }

  public func changeTypingMethod(newMethod: TypingMethods) {
    typingMethod = newMethod
    engine = typingMethod == .telex ? Telex() : VNI()
    newWord()
  }

  /// Applies new engine options (foreign consonants, tone placement, spelling check).
  public func changeEngineConfig(_ config: EngineConfig) {
    guard config != wordBuffer.config else { return }
    wordBuffer.config = config
    newWord()
  }

  public func changeActiveApp(_ app: String) {
    activeApp = app
    sendingStrategy = compatibilityPolicy.replacementStrategy(for: app)
    selectionDetector.invalidateCache()
  }

  // MARK: - Word Operations (delegate to WordBuffer)

  public func newWord(storePrevious: Bool = false) {
    wordBuffer.newWord(storePrevious: storePrevious)
    selectionDetector.invalidateCache()
  }

  public func pop() -> Replacement {
    return wordBuffer.pop(engine: engine)
  }

  public func push(char: Character) {
    wordBuffer.push(char: char, engine: engine)
  }

  // MARK: - Main Input Handler

  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let inputEvent = KeyboardInputEvent(event: event, keyboardLayout: keyboardLayout)
    return handleInputEvent(inputEvent) == .handled ? nil : Unmanaged.passUnretained(event)
  }

  func handleInputEvent(_ event: KeyboardInputEvent) -> InputEventResult {
    // Handle modifier keys (Cmd, Ctrl, Alt) - clear word buffer
    if event.hasBypassModifier {
      newWord()
      return .passThrough
    }

    // Dispatch based on key type
    if let taskKey = keyboardLayout.mapTask(keyCode: event.keyCode) {
      return handleTaskKey(taskKey)
    }

    // Prefer what the active layout really types; fall back to the US key map only when the
    // event carries no system information (synthetic input, tests).
    let newChar =
      event.resolvedFromSystem
      ? event.character
      : keyboardLayout.mapText(keyCode: event.keyCode, withShift: event.shifted)
    if let newChar {
      return handleTextChar(newChar)
    }

    // Anything else (Page Up/Down, Forward Delete, Insert, non-Latin input, ...) may move the
    // caret or change the text, so the current word can no longer be trusted.
    newWord()
    return .passThrough
  }

  // MARK: - Private Event Handlers

  private func handleTaskKey(_ taskKey: TaskKey) -> InputEventResult {
    if InputProcessor.newWordTaskKeys.contains(taskKey) {
      newWord(storePrevious: true)
    } else if taskKey == .delete {
      let replacement = pop()
      if !replacement.isEmpty {
        replacementSender.sendReplacement(replacement, strategy: sendingStrategy)
        return .handled
      }
    } else {
      // Arrows, Home/End, Escape and F-keys: the caret or focus may have moved.
      newWord()
    }
    return .passThrough
  }

  private func handleTextChar(_ newChar: Character) -> InputEventResult {
    // Check if this is a word-ending character (punctuation, etc.) BEFORE processing
    if InputProcessor.newWordKeys.contains(newChar) {
      newWord(storePrevious: true)
      return .passThrough
    }

    push(char: newChar)
    let replacement = Replacement.diff(
      from: wordBuffer.lastTransformed, to: wordBuffer.transformed)

    // If the only change is the new character itself, let it pass through
    if replacement.deleteCount == 0 && replacement.insert == [newChar] {
      return .passThrough
    }

    if compatibilityPolicy.shouldFixAutocomplete(for: activeApp)
      && selectionDetector.hasHighlightedText()
    {
      // For autocomplete-capable apps (browsers, etc.), use select-and-replace
      // only when there is highlighted text (checked through a short throttle)
      // typically inline autocomplete ghost text that backspace cannot reach.
      // Shift+Left extends the existing selection so the replacement covers both
      // the autocomplete text and the characters being modified.
      //
      // When there is no highlighted text (e.g. Google Docs canvas editor),
      // fall through to the backspace path below. Canvas-based web editors
      // ignore synthetic Shift+Left, so select-and-replace would leave the old
      // characters behind.
      replacementSender.sendSelectAndReplace(replacement, strategy: sendingStrategy)
      selectionDetector.invalidateCache()
    } else {
      replacementSender.sendReplacement(replacement, strategy: sendingStrategy)
    }
    return .handled
  }
}
