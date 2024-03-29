//
//  TypingMethod.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/02/2024.
//

import Defaults
import Foundation

enum TypingMethods: String, CaseIterable, Defaults.Serializable {
  case Telex = "Telex"
  case VNI = "VNI"
}

protocol TypingMethod {
  func shouldStopProcessing(keyStr: String) -> Bool
  func push(char: Character, to word: TiengViet) -> Bool
  func pop(from word: TiengViet) -> Character?
}
