//
//  AppsSettingsView.swift
//  Caffee
//

import AppKit
import SwiftUI

/// Per-app behaviour: which mode an app starts in, and how replacements are sent to it.
struct AppsSettingsView: View {
  @Environment(AppState.self) var appState
  /// Apps the user added by hand this session that have no stored setting yet.
  @State private var added: Set<String> = []

  private var apps: [String] {
    Set(appState.store.knownApps).union(added).sorted {
      AppInfo.name(for: $0).localizedCaseInsensitiveCompare(AppInfo.name(for: $1))
        == .orderedAscending
    }
  }

  var body: some View {
    Form {
      Section {
        if apps.isEmpty {
          Text("Chưa có ứng dụng nào. Ứng dụng sẽ hiện ở đây sau khi bạn gõ trong đó.")
            .foregroundStyle(.secondary)
        }
        ForEach(apps, id: \.self) { bundleId in
          AppSettingsRow(bundleId: bundleId) { added.remove(bundleId) }
        }
      } header: {
        Text("Thiết lập riêng cho từng ứng dụng")
      } footer: {
        Text(
          "\"Cách gửi phím\" quyết định cách Caffee thay chữ. Nếu một ứng dụng bị lỗi chữ, thử \"Từng ký tự\"."
        )
      }

      Section {
        Menu("Thêm ứng dụng đang chạy…") {
          ForEach(runningApps, id: \.self) { bundleId in
            Button(AppInfo.name(for: bundleId)) { added.insert(bundleId) }
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(minHeight: 320)
  }

  private var runningApps: [String] {
    let known = Set(apps)
    return NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .compactMap(\.bundleIdentifier)
      .filter { !known.contains($0) && $0 != appState.bundleId }
      .sorted {
        AppInfo.name(for: $0).localizedCaseInsensitiveCompare(AppInfo.name(for: $1))
          == .orderedAscending
      }
  }
}

private struct AppSettingsRow: View {
  @Environment(AppState.self) var appState
  let bundleId: String
  let onForget: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(nsImage: AppInfo.icon(for: bundleId))
          .resizable()
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 0) {
          Text(AppInfo.name(for: bundleId)).font(.headline)
          Text(bundleId).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button(role: .destructive) {
          appState.forget(app: bundleId)
          onForget()
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Xóa mọi thiết lập của ứng dụng này")
      }

      Picker(
        "Chế độ gõ",
        selection: Binding(
          get: { appState.store.preference(for: bundleId) },
          set: { appState.setPreference($0, for: bundleId) })
      ) {
        ForEach(AppModePreference.allCases, id: \.self) { Text($0.title).tag($0) }
      }

      Picker(
        "Cách gửi phím",
        selection: Binding(
          get: { appState.store.strategy(for: bundleId) },
          set: { appState.setStrategy($0, for: bundleId) })
      ) {
        ForEach(SendingStrategyOverride.allCases, id: \.self) { Text($0.title).tag($0) }
      }
    }
    .padding(.vertical, 4)
  }
}

/// Name and icon of an app from its bundle identifier.
enum AppInfo {
  static func name(for bundleId: String) -> String {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
      return bundleId
    }
    return FileManager.default.displayName(atPath: url.path)
      .replacingOccurrences(of: ".app", with: "")
  }

  static func icon(for bundleId: String) -> NSImage {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
      return NSWorkspace.shared.icon(for: .applicationBundle)
    }
    return NSWorkspace.shared.icon(forFile: url.path)
  }
}
