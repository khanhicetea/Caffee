import Cocoa

protocol KeyboardLayout {
  func mapText(keyCode: Int64, withShift shift: Bool) -> Character?
  func mapTask(keyCode: Int64) -> TaskKey?
  func isNumberKey(keyCode: Int64) -> Bool
}

class KeyboardUS: KeyboardLayout {
  private let keyMap: [Int64: (ascii: Character, shiftAscii: Character)]
  private let taskMap: [Int64: TaskKey]

  init() {
    // Initialize the key map with US keyboard layout
    keyMap = [
      // Numbers
      29: ("0", ")"),  // 0 key
      18: ("1", "!"),  // 1 key
      19: ("2", "@"),  // 2 key
      20: ("3", "#"),  // 3 key
      21: ("4", "$"),  // 4 key
      23: ("5", "%"),  // 5 key
      22: ("6", "^"),  // 6 key
      26: ("7", "&"),  // 7 key
      28: ("8", "*"),  // 8 key
      25: ("9", "("),  // 9 key
      // Letters
      0: ("a", "A"),  // A key
      11: ("b", "B"),  // B key
      8: ("c", "C"),  // C key
      2: ("d", "D"),  // D key
      14: ("e", "E"),  // E key
      3: ("f", "F"),  // F key
      5: ("g", "G"),  // G key
      4: ("h", "H"),  // H key
      34: ("i", "I"),  // I key
      38: ("j", "J"),  // J key
      40: ("k", "K"),  // K key
      37: ("l", "L"),  // L key
      46: ("m", "M"),  // M key
      45: ("n", "N"),  // N key
      31: ("o", "O"),  // O key
      35: ("p", "P"),  // P key
      12: ("q", "Q"),  // Q key
      15: ("r", "R"),  // R key
      1: ("s", "S"),  // S key
      17: ("t", "T"),  // T key
      32: ("u", "U"),  // U key
      9: ("v", "V"),  // V key
      13: ("w", "W"),  // W key
      7: ("x", "X"),  // X key
      16: ("y", "Y"),  // Y key
      6: ("z", "Z"),  // Z key
      // Punctuation and special characters
      50: ("`", "~"),  // Backquote key
      27: ("-", "_"),  // Minus key
      24: ("=", "+"),  // Equal key
      33: ("[", "{"),  // Left bracket key
      30: ("]", "}"),  // Right bracket key
      42: ("\\", "|"),  // Backslash key
      41: (";", ":"),  // Semicolon key
      39: ("'", "\""),  // Quote key
      43: (",", "<"),  // Comma key
      47: (".", ">"),  // Period key
      44: ("/", "?"),  // Slash key
    ]

    taskMap = [
      36: .enter,
      52: .enter,
      76: .enter,  // Keypad Enter
      48: .tab,
      49: .space,
      51: .delete,
      53: .escape,
      // Move
      115: .home,
      119: .end,
      // Arrow keys
      123: .arrowLeft,
      124: .arrowRight,
      125: .arrowDown,
      126: .arrowUp,
      // Function keys
      122: .f1,
      120: .f2,
      99: .f3,
      118: .f4,
      96: .f5,
      97: .f6,
      98: .f7,
      100: .f8,
      101: .f9,
      109: .f10,
      103: .f11,
      111: .f12,
    ]
  }

  func mapText(keyCode: Int64, withShift shift: Bool) -> Character? {
    guard let key = keyMap[keyCode] else { return nil }
    return shift ? key.shiftAscii : key.ascii
  }

  func mapTask(keyCode: Int64) -> TaskKey? {
    guard let key = taskMap[keyCode] else { return nil }
    return key
  }

  func isNumberKey(keyCode: Int64) -> Bool {
    // Number keys: 0-9
    return [29, 18, 19, 20, 21, 23, 22, 26, 28, 25].contains(keyCode)
  }
}
