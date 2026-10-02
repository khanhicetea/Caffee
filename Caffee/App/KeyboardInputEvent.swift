//
//  KeyboardInputEvent.swift
//  Caffee
//

import CoreGraphics

struct KeyboardInputEvent {
  let keyCode: Int64
  let shifted: Bool
  let commandPressed: Bool
  let controlPressed: Bool
  let optionPressed: Bool
  /// Character the active keyboard layout produces for this key (ASCII printable only).
  /// Only meaningful when `resolvedFromSystem` is true.
  var character: Character? = nil
  /// True when the system reported what the key types. A nil `character` then means the key
  /// is not an ASCII text key on the current layout (e.g. Cyrillic) and must not be guessed
  /// from a US key map.
  var resolvedFromSystem = false

  var hasBypassModifier: Bool {
    commandPressed || controlPressed || optionPressed
  }
}

extension KeyboardInputEvent {
  init(event: CGEvent, keyboardLayout: KeyboardLayout) {
    let flags = event.flags
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let shifted =
      flags.contains(.maskShift)
      || (!keyboardLayout.isNumberKey(keyCode: keyCode) && flags.contains(.maskAlphaShift))

    var result = KeyboardInputEvent(
      keyCode: keyCode,
      shifted: shifted,
      commandPressed: flags.contains(.maskCommand),
      controlPressed: flags.contains(.maskControl),
      optionPressed: flags.contains(.maskAlternate)
    )

    // Ask the system what this key types so Dvorak/Colemak/AZERTY/numpad all work.
    var length = 0
    var units = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(
      maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
    if length > 0 {
      let typed = String(utf16CodeUnits: units, count: length)
      result.resolvedFromSystem = true
      if typed.count == 1, let scalar = typed.unicodeScalars.first,
        (0x21...0x7E).contains(scalar.value)
      {
        result.character = Character(scalar)
      }
    }
    self = result
  }
}

enum InputEventResult: Equatable {
  case passThrough
  case handled
}
