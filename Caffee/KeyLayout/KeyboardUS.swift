import Cocoa

class KeyboardUS {
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
      36: .Enter,
      52: .Enter,
      48: .Tab,
      49: .Space,
      51: .Delete,
      53: .Escape,
      // Move
      115: .Home,
      119: .End,
      // Arrow keys
      123: .ArrowLeft,
      124: .ArrowRight,
      125: .ArrowDown,
      126: .ArrowUp,
      // Function keys
      122: .F1,
      120: .F2,
      99: .F3,
      118: .F4,
      96: .F5,
      97: .F6,
      98: .F7,
      100: .F8,
      101: .F9,
      109: .F10,
      103: .F11,
      111: .F12,
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
