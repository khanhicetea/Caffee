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

  // New functional API - returns new state instead of mutating
  func push(char: Character, state: TiengVietState) -> (state: TiengVietState, appliedMark: Bool)
  func pop(state: TiengVietState) -> TiengVietState
}
