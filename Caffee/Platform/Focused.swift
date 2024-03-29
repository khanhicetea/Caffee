//
//  Focused.swift
//
//

import ApplicationServices
import Foundation

public struct Focused {
  public static func element() -> AXUIElement? {
    let systemWideElement: AXUIElement = AXUIElementCreateSystemWide()
    let result: AXUIElement? = systemWideElement.getAttribute(
      property: kAXFocusedUIElementAttribute)
    return result
  }

  public static func elementText() -> String? {
    if let focusedElement: AXUIElement = Focused.element() {
      if let selectedText: AXValue = focusedElement.getAttribute(property: kAXValueAttribute) {
        return "\(selectedText)"
      }
    }
    return nil
  }

  public static func hasHighlightedText() -> Bool {
    if let focusedElement: AXUIElement = Focused.element() {
      if let highlightedText: AXValue = focusedElement.getAttribute(
        property: kAXSelectedTextAttribute)
      {
        return !"\(highlightedText)".isEmpty
      }
    }
    return false
  }

  public static func highlightedText() -> String? {
    if let focusedElement: AXUIElement = Focused.element() {
      if let highlightedText: AXValue = focusedElement.getAttribute(
        property: kAXSelectedTextAttribute)
      {
        if !"\(highlightedText)".isEmpty {
          return "\(highlightedText)"
        }
      }
    }
    return nil
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
