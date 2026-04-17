//
//  Focused.swift
//
//

import ApplicationServices
import Foundation

public struct Focused {
  public static func element() -> AXUIElement? {
    let systemWideElement = AXUIElementCreateSystemWide()
    return systemWideElement.getAttribute(property: kAXFocusedUIElementAttribute)
  }

  public static func elementText() -> String? {
    guard let focusedElement = Focused.element() else { return nil }
    guard let selectedText: AXValue = focusedElement.getAttribute(property: kAXValueAttribute)
    else { return nil }
    return "\(selectedText)"
  }

  public static func hasHighlightedText() -> Bool {
    guard let focusedElement = Focused.element() else { return false }

    // Method 1: Check selected text content directly
    if let highlightedText: AXValue = focusedElement.getAttribute(
      property: kAXSelectedTextAttribute)
    {
      if !"\(highlightedText)".isEmpty {
        return true
      }
    }

    // Method 2: Check selected text range length (fallback)
    // Some apps (e.g., Chrome's address bar) don't expose kAXSelectedTextAttribute
    // but do expose kAXSelectedTextRangeAttribute with a valid CFRange.
    if let rangeValue: AXValue = focusedElement.getAttribute(
      property: kAXSelectedTextRangeAttribute)
    {
      var range = CFRange(location: 0, length: 0)
      if AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 {
        #if DEBUG
          print(
            "[Caffee] hasHighlightedText: detected via selectedTextRange (location=\(range.location), length=\(range.length))"
          )
        #endif
        return true
      }
    }

    return false
  }

  public static func highlightedText() -> String? {
    guard let focusedElement = Focused.element() else { return nil }
    guard let highlightedText: AXValue = focusedElement.getAttribute(
      property: kAXSelectedTextAttribute)
    else { return nil }
    guard !"\(highlightedText)".isEmpty else { return nil }
    return "\(highlightedText)"
  }
}

extension AXUIElement {
  public func getAttribute<T>(property: String) -> T? {
    var ptr: AnyObject?
    if AXUIElementCopyAttributeValue(self, property as CFString, &ptr) != AXError.success {
      return nil
    }
    return ptr.map {
      $0 as! T
    }
  }
}
