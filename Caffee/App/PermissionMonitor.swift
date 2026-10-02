//
//  PermissionMonitor.swift
//  Caffee
//

import ApplicationServices
import Foundation
import Observation

/// Single source of truth for the Accessibility permission, replacing the separate polling
/// timers the app delegate, onboarding and upgrade screens used to run.
@MainActor
@Observable
final class PermissionMonitor {
  private(set) var isTrusted: Bool
  /// Called on every change of `isTrusted`.
  @ObservationIgnored var onChange: ((Bool) -> Void)?

  @ObservationIgnored private let check: () -> Bool
  @ObservationIgnored private var timer: Timer?

  init(check: @escaping () -> Bool = { AXIsProcessTrusted() }) {
    self.check = check
    self.isTrusted = check()
  }

  /// Re-reads the permission now.
  @discardableResult
  func refresh() -> Bool {
    let trusted = check()
    if trusted != isTrusted {
      isTrusted = trusted
      onChange?(trusted)
    }
    return trusted
  }

  /// Polls until `stop()`. Calling it again just restarts the timer.
  func start(interval: TimeInterval = 1.0) {
    timer?.invalidate()
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] timer in
      guard let self else {
        timer.invalidate()
        return
      }
      MainActor.assumeIsolated { _ = self.refresh() }
    }
    timer.tolerance = interval / 4
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }
}
