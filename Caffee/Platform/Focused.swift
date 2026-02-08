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
    guard let highlightedText: AXValue = focusedElement.getAttribute(
      property: kAXSelectedTextAttribute)
    else { return false }
    return !"\(highlightedText)".isEmpty
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
