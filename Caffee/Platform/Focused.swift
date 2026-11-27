//
//  Focused.swift
//
//

import ApplicationServices
import Foundation

public struct Focused {
  public static func element() -> AXUIElement? {
    let systemWideElement = AXUIElementCreateSystemWide()
    return systemWideElement.getAXUIElementAttribute(property: kAXFocusedUIElementAttribute)
  }

  public static func elementText() -> String? {
    guard let focusedElement = Focused.element() else { return nil }
    return focusedElement.getStringAttribute(property: kAXValueAttribute)
  }

  public static func hasHighlightedText() -> Bool {
    guard let focusedElement = Focused.element() else { return false }

    // Method 1: Check selected text content directly
    if let highlightedText = focusedElement.getStringAttribute(
      property: kAXSelectedTextAttribute),
      !highlightedText.isEmpty
    {
      return true
    }

    // Method 2: Check selected text range length (fallback)
    // Some apps (e.g., Chrome's address bar) don't expose kAXSelectedTextAttribute
    // but do expose kAXSelectedTextRangeAttribute with a valid CFRange.
    if let rangeValue = focusedElement.getAXValueAttribute(
      property: kAXSelectedTextRangeAttribute)
    {
      var range = CFRange(location: 0, length: 0)
      if AXValueGetValue(rangeValue, .cfRange, &range), range.length > 0 {
        Log.accessibility.debug(
          "hasHighlightedText via selectedTextRange (location=\(range.location), length=\(range.length))"
        )
        return true
      }
    }

    return false
  }

  public static func highlightedText() -> String? {
    guard let focusedElement = Focused.element() else { return nil }
    guard
      let highlightedText = focusedElement.getStringAttribute(
        property: kAXSelectedTextAttribute),
      !highlightedText.isEmpty
    else { return nil }
    return highlightedText
  }
}

extension AXUIElement {
  private func copyRawAttribute(property: String) -> CFTypeRef? {
    var ptr: CFTypeRef?
    guard AXUIElementCopyAttributeValue(self, property as CFString, &ptr) == .success else {
      return nil
    }
    return ptr
  }

  public func getStringAttribute(property: String) -> String? {
    copyRawAttribute(property: property) as? String
  }

  public func getAXValueAttribute(property: String) -> AXValue? {
    guard let ptr = copyRawAttribute(property: property),
      CFGetTypeID(ptr) == AXValueGetTypeID()
    else { return nil }
    return (ptr as! AXValue)
  }

  public func getAXUIElementAttribute(property: String) -> AXUIElement? {
    guard let ptr = copyRawAttribute(property: property),
      CFGetTypeID(ptr) == AXUIElementGetTypeID()
    else { return nil }
    return (ptr as! AXUIElement)
  }
}
