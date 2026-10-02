//
//  ModeHUD.swift
//  Caffee
//

import AppKit
import SwiftUI

/// Brief on-screen confirmation ("V" / "E") after the typing mode changes.
@MainActor
final class ModeHUD {
  static let shared = ModeHUD()

  fileprivate static let size = CGSize(width: 132, height: 132)
  private static let visibleDuration: TimeInterval = 0.7

  private var panel: NSPanel?
  private var hideWork: DispatchWorkItem?

  func show(vietnamese: Bool) {
    let panel = self.panel ?? makePanel()
    self.panel = panel
    panel.contentView = NSHostingView(rootView: ModeHUDView(vietnamese: vietnamese))
    panel.setFrame(frame(on: screenUnderMouse()), display: false)

    hideWork?.cancel()
    panel.alphaValue = 1
    panel.orderFrontRegardless()

    let work = DispatchWorkItem { [weak self] in
      guard let panel = self?.panel else { return }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.2
        panel.animator().alphaValue = 0
      } completionHandler: {
        MainActor.assumeIsolated { panel.orderOut(nil) }
      }
    }
    hideWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleDuration, execute: work)
  }

  private func makePanel() -> NSPanel {
    // Non-activating and click-through: showing it must never steal focus from the app
    // the user is typing in.
    let panel = NSPanel(
      contentRect: CGRect(origin: .zero, size: Self.size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .statusBar
    panel.ignoresMouseEvents = true
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    return panel
  }

  private func screenUnderMouse() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
  }

  private func frame(on screen: NSScreen?) -> CGRect {
    let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    return CGRect(
      x: visible.midX - Self.size.width / 2,
      y: visible.minY + visible.height * 0.28,
      width: Self.size.width,
      height: Self.size.height)
  }
}

private struct ModeHUDView: View {
  let vietnamese: Bool

  var body: some View {
    VStack(spacing: 4) {
      Text(vietnamese ? "V" : "E")
        .font(.system(size: 64, weight: .bold, design: .rounded))
      Text(vietnamese ? "Tiếng Việt" : "English")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .frame(width: ModeHUD.size.width, height: ModeHUD.size.height)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}
