//
//  AdvancedSettingsView.swift
//  Caffee
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Automation reference and diagnostics export.
struct AdvancedSettingsView: View {
  @Environment(AppState.self) var appState
  @State private var exportMessage: String?

  private let switchPath = AutomationService.defaultSwitchFileURL.path

  var body: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("Điều khiển từ script, Shortcuts, Raycast, Alfred…")
          Text(
            """
            open caffee://mode/vi        (en, toggle)
            open caffee://method/telex   (vni)
            echo vi > "\(switchPath)"
            """
          )
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .padding(8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        Button("Mở thư mục chứa file điều khiển") {
          NSWorkspace.shared.activateFileViewerSelecting([AutomationService.defaultSwitchFileURL])
        }
      } header: {
        Text("Tự động hóa")
      }

      Section {
        HStack {
          Button("Xuất nhật ký chẩn đoán…", action: exportDiagnostics)
          Button("Sao chép") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Diagnostics.report(for: appState), forType: .string)
            exportMessage = "Đã sao chép."
          }
        }
        if let exportMessage {
          Text(exportMessage).font(.caption).foregroundStyle(.secondary)
        }
      } header: {
        Text("Chẩn đoán")
      } footer: {
        Text(
          "Gồm phiên bản, bố cục bàn phím, tình trạng bộ gõ và log gần đây. Không có nội dung bạn gõ."
        )
      }
    }
    .formStyle(.grouped)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func exportDiagnostics() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "caffee-diagnostics.txt"
    panel.allowedContentTypes = [.plainText]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try Diagnostics.report(for: appState).write(to: url, atomically: true, encoding: .utf8)
      exportMessage = "Đã lưu vào \(url.lastPathComponent)."
    } catch {
      exportMessage = "Không lưu được: \(error.localizedDescription)"
    }
  }
}
