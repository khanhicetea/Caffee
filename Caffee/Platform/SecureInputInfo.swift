//
//  SecureInputInfo.swift
//  Caffee
//

import AppKit
import Darwin
import IOKit

enum SecureInputInfo {
  struct Holder {
    let name: String
    /// loginwindow keeping the lock after unlock is a macOS bug, not a password field.
    let isLoginWindow: Bool
  }

  /// The app or process that currently holds Secure Input, when macOS reports its pid.
  static func holder() -> Holder? {
    guard let pid = consoleSecureInputPID() ?? sessionSecureInputPID() else { return nil }
    if let app = NSRunningApplication(processIdentifier: pid) {
      return Holder(
        name: app.localizedName ?? app.bundleIdentifier ?? processName(for: pid) ?? "pid \(pid)",
        isLoginWindow: app.bundleIdentifier == "com.apple.loginwindow")
    }
    return Holder(
      name: processName(for: pid) ?? "pid \(pid)",
      isLoginWindow: false)
  }

  /// Resolves a CLI/daemon process name (e.g. `sudo`, `ssh`) that has no `NSRunningApplication`.
  private static func processName(for pid: pid_t) -> String? {
    var buffer = [CChar](repeating: 0, count: 256)
    let length = proc_name(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return nil }
    let bytes = buffer.prefix(Int(length)).map(UInt8.init(bitPattern:))
    let name = String(decoding: bytes, as: UTF8.self)
    return name.isEmpty ? nil : name
  }

  /// The IORegistry console-user entry names the process that enabled Secure Input.
  private static func consoleSecureInputPID() -> pid_t? {
    let root = IORegistryGetRootEntry(kIOMainPortDefault)
    guard root != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(root) }
    guard
      let users = IORegistryEntryCreateCFProperty(
        root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? [[String: Any]],
      let user = users.first(where: {
        ($0["kCGSSessionUserIDKey"] as? NSNumber)?.uint32Value == getuid()
      }),
      let pid = (user["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value,
      pid > 0
    else { return nil }
    return pid
  }

  /// Fallback only: the CGSession copy reports the frontmost app, not the real holder.
  private static func sessionSecureInputPID() -> pid_t? {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any],
      let pid = (session["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value,
      pid > 0
    else { return nil }
    return pid
  }
}
