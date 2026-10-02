//
//  SecureInputHelpPanel.swift
//  Caffee
//

import AppKit
import SwiftUI

/// Explains Secure Input in a small floating panel. Unlike a modal alert it does not activate
/// Caffee, so focus (and the password field the user may be in) stays where it was.
@MainActor
final class SecureInputHelpPanel {
  private var panel: NSPanel?

  func show(holder: String?) {
    let panel =
      self.panel
      ?? {
        let panel = NSPanel(
          contentRect: CGRect(x: 0, y: 0, width: 420, height: 100),
          styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
          backing: .buffered,
          defer: true)
        panel.title = "Secure Input"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        return panel
      }()
    self.panel = panel

    let hosting = NSHostingView(rootView: SecureInputHelpView(holder: holder))
    panel.contentView = hosting
    panel.setContentSize(hosting.fittingSize)
    panel.center()
    panel.orderFrontRegardless()
  }
}

private struct SecureInputHelpView: View {
  let holder: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("macOS đang bật Secure Input", systemImage: "lock.square")
        .font(.headline)

      if let holder {
        Text("Ứng dụng đang giữ khóa: **\(holder)**")
      }

      Text(
        "macOS đang chặn bộ gõ nhận bàn phím để bảo vệ dữ liệu nhạy cảm. Hãy đóng ô hoặc hộp thoại nhập mật khẩu\(holder.map { " trong \($0)" } ?? "")."
      )

      Text(
        "Nếu đã chuyển sang ô văn bản thường mà vẫn bị khóa, hãy thoát và mở lại ứng dụng đã bật Secure Input. Caffee không thể tắt Secure Input của ứng dụng khác, và thoát/mở lại Caffee cũng không gỡ được khóa này. Bộ gõ sẽ tự hoạt động lại khi ứng dụng đó nhả khóa."
      )
      .foregroundStyle(.secondary)
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(width: 420, alignment: .leading)
    .padding(20)
  }
}
