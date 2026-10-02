//
//  CompatibilityPolicyTests.swift
//  CaffeeTests
//

import CoreGraphics
import XCTest

@testable import Caffee

final class CompatibilityPolicyTests: XCTestCase {

  func testStrategyOverrideWinsOverBuiltInDefault() {
    let policy = DefaultAppCompatibilityPolicy(overrides: {
      ["com.apple.Terminal": .fast, "com.example.app": .stepByStep]
    })
    XCTAssertEqual(policy.replacementStrategy(for: "com.apple.Terminal"), .batch)
    XCTAssertEqual(policy.replacementStrategy(for: "com.example.app"), .stepByStep)
    XCTAssertEqual(policy.replacementStrategy(for: "com.googlecode.iterm2"), .stepByStep)
    XCTAssertEqual(policy.replacementStrategy(for: "com.other"), .batch)
  }

  func testAutocompletePrefixesCoverBrowserVariants() {
    let policy = DefaultAppCompatibilityPolicy(overrides: { [:] })
    for bundleId in [
      "com.google.Chrome", "com.google.Chrome.canary", "com.microsoft.edgemac",
      "com.microsoft.edgemac.Beta", "org.mozilla.firefox", "com.apple.Safari",
    ] {
      XCTAssertTrue(policy.shouldFixAutocomplete(for: bundleId), bundleId)
    }
    XCTAssertFalse(policy.shouldFixAutocomplete(for: "com.apple.TextEdit"))
  }
}
