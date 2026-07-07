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

  /// Last valid snapshot for single-step rollback out of recovery mode.
  var lastValidSnapshot: Snapshot?

  // MARK: - Word Lifecycle

  mutating func newWord(storePrevious: Bool = false) {
    previousWordState = nil
    if !wordState.isBlank {
      if storePrevious {
        previousWordState = wordState
      }
      wordState = .empty
    }

    keys = []
    lastValidSnapshot = nil
    stopProcessing = false
    lastTransformed = ""
    transformed = ""
  }

  // MARK: - Pop (Backspace)

  mutating func pop(engine: TypingMethod) -> (Int, [Character]) {
    lastTransformed = transformed

    // Single-step rollback: if we are in recovery and it was caused by the LATEST keystroke
    if stopProcessing, let valid = lastValidSnapshot, keys.count == valid.keys.count + 1 {
      wordState = valid.wordState
      keys = valid.keys
      transformed = valid.transformed
      stopProcessing = valid.stopProcessing
      lastValidSnapshot = nil

      let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
        from: lastTransformed, to: transformed)

      if numBackspaces == 1 && diffChars.isEmpty {
        return (0, [])
      }

      return (numBackspaces, diffChars)
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
      return (0, [])  // Let OS handle the backspace that brought us here
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

    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If it's a simple 1-char deletion, let the OS handle it
    if numBackspaces == 1 && diffChars.isEmpty {
      return (0, [])
    }

    return (numBackspaces, diffChars)
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

    let result = engine.push(char: char, state: wordState)
    wordState = result.state

    // Check if we need to recover original input (invalid Vietnamese syllable)
    if wordState.needsRecovery {
      stopProcessing = true
      // Use keys array which contains ALL typed characters (including tone marks like 's', 'f' etc.)
      transformed = String(keys)

      // If we JUST entered recovery mode, save the snapshot for rollback
      if !snapshot.stopProcessing {
        lastValidSnapshot = snapshot
      }
    } else {
      transformed = wordState.transformed
      // Clear snapshot when we're in valid state; no rollback needed
      lastValidSnapshot = nil
    }

    if engine.shouldStopProcessing(keyStr: String(keys)) {
      stopProcessing = true
      if transformed.count == lastTransformed.count {
        transformed.append(char)
        wordState = wordState.push(char)
      }
    }
  }
}

// MARK: - InputProcessor

class InputProcessor {
  static let NewWordKeys = "`!@#$%^&*()-=[]\\;',./~_+{}|:\"<>?"
  static let NewWordTaskKeys: [TaskKey] = [.Enter, .Space, .Tab]
  static let JumpTaskKeys: [TaskKey] = [.Home, .End, .ArrowUp, .ArrowDown, .ArrowLeft, .ArrowRight]

  public var engine: TypingMethod
  public var typingMethod: TypingMethods
  var keyboardLayout: KeyboardLayout
  var replacementSender: ReplacementSender
  var selectionDetector: SelectionDetector
  var compatibilityPolicy: AppCompatibilityPolicy
  public var activeApp = ""

  /// Word buffer manages the current word state
  var wordBuffer = WordBuffer()

  /// Transformation tracker manages per-app strategy and failure detection
  var strategyTracker = TransformationTracker()

  /// Track pasteboard change count to detect external paste operations
  private var lastPasteboardChangeCount: Int = NSPasteboard.general.changeCount

  // MARK: - Convenience accessors (preserve existing API for tests)

  public var keys: [Character] {
    get { wordBuffer.keys }
    set { wordBuffer.keys = newValue }
  }

  public var stopProcessing: Bool {
    get { wordBuffer.stopProcessing }
    set { wordBuffer.stopProcessing = newValue }
  }

  public var lastTransformed: String {
    get { wordBuffer.lastTransformed }
    set { wordBuffer.lastTransformed = newValue }
  }

  public var transformed: String {
    get { wordBuffer.transformed }
    set { wordBuffer.transformed = newValue }
  }

  public var previousWordState: TiengVietState? {
    get { wordBuffer.previousWordState }
    set { wordBuffer.previousWordState = newValue }
  }

  public var wordState: TiengVietState {
    get { wordBuffer.wordState }
    set { wordBuffer.wordState = newValue }
  }

  // MARK: - Init & Configuration

  init(
    method: TypingMethods,
    keyboardLayout: KeyboardLayout = KeyboardUS(),
    replacementSender: ReplacementSender = EventSimulatorReplacementSender(),
    selectionDetector: SelectionDetector = AccessibilitySelectionDetector(),
    compatibilityPolicy: AppCompatibilityPolicy = DefaultAppCompatibilityPolicy()
  ) {
    typingMethod = method
    engine = typingMethod == .Telex ? Telex() : VNI()
    self.keyboardLayout = keyboardLayout
    self.replacementSender = replacementSender
    self.selectionDetector = selectionDetector
    self.compatibilityPolicy = compatibilityPolicy
  }

  public func changeTypingMethod(newMethod: TypingMethods) {
    typingMethod = newMethod
    engine = typingMethod == .Telex ? Telex() : VNI()
    newWord()
  }

  public func changeActiveApp(_ app: String) {
    activeApp = app
    strategyTracker.resetForApp(app, policy: compatibilityPolicy)
    selectionDetector.invalidateCache()
  }

  // MARK: - Word Operations (delegate to WordBuffer)

  public func newWord(storePrevious: Bool = false) {
    wordBuffer.newWord(storePrevious: storePrevious)
    selectionDetector.invalidateCache()
  }

  public func pop() -> (Int, [Character]) {
    return wordBuffer.pop(engine: engine)
  }

  public func push(char: Character) {
    wordBuffer.push(char: char, engine: engine)
  }

  // MARK: - Main Input Handler

  public func handleEvent(event: CGEvent) -> Unmanaged<CGEvent>? {
    let inputEvent = KeyboardInputEvent(event: event, keyboardLayout: keyboardLayout)

    // Detect if a paste operation occurred (pasteboard changed externally)
    let currentPasteboardCount = NSPasteboard.general.changeCount
    if currentPasteboardCount != lastPasteboardChangeCount {
      lastPasteboardChangeCount = currentPasteboardCount
      newWord()
    }

    return handleInputEvent(inputEvent) == .handled ? nil : Unmanaged.passRetained(event)
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
    } else if let newChar = keyboardLayout.mapText(keyCode: event.keyCode, withShift: event.shifted) {
      return handleTextChar(newChar)
    }

    return .passThrough
  }

  // MARK: - Private Event Handlers

  private func handleTaskKey(_ taskKey: TaskKey) -> InputEventResult {
    if InputProcessor.NewWordTaskKeys.contains(taskKey) {
      newWord(storePrevious: true)
    } else if taskKey == .Delete {
      let (numBackspaces, diffChars) = pop()
      if numBackspaces > 0 || !diffChars.isEmpty {
        replacementSender.sendReplacement(
          backspaceCount: numBackspaces,
          diffChars: diffChars,
          strategy: strategyTracker.currentStrategy
        )
        return .handled
      }
    } else if InputProcessor.JumpTaskKeys.contains(taskKey) {
      newWord()
    }
    return .passThrough
  }

  private func handleTextChar(_ newChar: Character) -> InputEventResult {
    // Check if this is a word-ending character (punctuation, etc.) BEFORE processing
    if let _ = InputProcessor.NewWordKeys.firstIndex(of: newChar) {
      newWord(storePrevious: true)
      return .passThrough
    }

    push(char: newChar)
    let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
      from: lastTransformed, to: transformed)

    // If the only change is the new character itself, let it pass through
    if let firstDiffChar = diffChars.first,
      diffChars.count == 1 && firstDiffChar == newChar && numBackspaces == 0
    {
      return .passThrough
    }

    // Check for transformation failures and auto-switch if needed
    if strategyTracker.detectFailure(input: newChar) {
      strategyTracker.autoSwitchIfNeeded(activeApp: activeApp, policy: compatibilityPolicy)
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
      replacementSender.sendSelectAndReplace(
        selectLeftCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
      selectionDetector.invalidateCache()
    } else {
      replacementSender.sendReplacement(
        backspaceCount: numBackspaces,
        diffChars: diffChars,
        strategy: strategyTracker.currentStrategy
      )
    }
    return .handled
  }
}
