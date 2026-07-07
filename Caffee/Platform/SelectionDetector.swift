//
//  SelectionDetector.swift
//  Caffee
//

import Foundation

protocol SelectionDetector {
  func hasHighlightedText() -> Bool
  func invalidateCache()
}

final class AccessibilitySelectionDetector: SelectionDetector {
  private var highlightedTextCached = false
  private var highlightedTextCheckedAt: Date = .distantPast
  private let highlightedTextThrottle: TimeInterval

  init(highlightedTextThrottle: TimeInterval = 0.05) {
    self.highlightedTextThrottle = highlightedTextThrottle
  }

  func hasHighlightedText() -> Bool {
    let now = Date()
    if now.timeIntervalSince(highlightedTextCheckedAt) >= highlightedTextThrottle {
      highlightedTextCached = Focused.hasHighlightedText()
      highlightedTextCheckedAt = now
    }
    return highlightedTextCached
  }

  func invalidateCache() {
    highlightedTextCheckedAt = .distantPast
  }
}
