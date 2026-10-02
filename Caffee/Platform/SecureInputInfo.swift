//
//  SecureInputInfo.swift
//  Caffee
//

import AppKit

enum SecureInputInfo {
  /// Name of the app that currently holds Secure Input, when macOS reports its pid.
  static func holderName() -> String? {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
      let pid = (session["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value
    else { return nil }
    return NSRunningApplication(processIdentifier: pid)?.localizedName
  }
}
