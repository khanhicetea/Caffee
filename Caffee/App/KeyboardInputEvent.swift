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

    self.init(
      keyCode: keyCode,
      shifted: shifted,
      commandPressed: flags.contains(.maskCommand),
      controlPressed: flags.contains(.maskControl),
      optionPressed: flags.contains(.maskAlternate)
    )
  }
}

enum InputEventResult: Equatable {
  case passThrough
  case handled
}
