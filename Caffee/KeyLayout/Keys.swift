//
//  Keys.swift
//  Caffee
//
//  Created by KhanhIceTea on 27/3/24.
//

import CoreGraphics
import Foundation

enum TaskKey {
  case enter
  case tab
  case space
  case delete
  case escape
  case arrowLeft
  case arrowRight
  case arrowUp
  case arrowDown
  case home
  case end
  case f1
  case f2
  case f3
  case f4
  case f5
  case f6
  case f7
  case f8
  case f9
  case f10
  case f11
  case f12
}

/// Layout-independent virtual key codes used when synthesizing events.
enum VirtualKey {
  static let delete: CGKeyCode = 0x33
  static let leftArrow: CGKeyCode = 0x7B
}
