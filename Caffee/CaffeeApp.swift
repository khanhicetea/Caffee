//
//  CaffeeApp.swift
//  Caffee
//
//  Created by KhanhIceTea on 20/02/2024.
//

import KeyboardShortcuts
import Sparkle
import SwiftUI

@main
struct CaffeeApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    MenuBarExtra {
      if appDelegate.isTrusted {
        MainMenuView(appDelegate: appDelegate)
      } else {
        GuideMenuView(appDelegate: appDelegate)
      }
    } label: {
      MenuBarLabel(appState: appDelegate.appState, isTrusted: appDelegate.isTrusted)
    }

    Settings {
      SettingsRootView()
        .environment(appDelegate.appState)
    }
  }
}

struct MainMenuView: View {
  var appDelegate: AppDelegate
  @Environment(\.openSettings) private var openSettings

  /// The global toggle shortcut, shown next to the menu item (e.g. "  (⌥Z)").
  private var shortcutHint: String {
    KeyboardShortcuts.getShortcut(for: .toggleInputMode).map { "  (\($0))" } ?? ""
  }

  var body: some View {
    @Bindable var appState = appDelegate.appState

    if let updateItem = appDelegate.updateItem {
      Button("Cập nhật mới \(updateItem.displayVersionString) đã có sẵn!") {
        appDelegate.updaterController.checkForUpdates(nil)
      }
      Divider()
    }

    if !appState.tapStatus.isHealthy {
      Button(
        appState.tapStatus == .permissionRevoked
          ? "Quyền Accessibility đã bị thu hồi — Mở hướng dẫn…"
          : "Bộ gõ chưa hoạt động — Thử lại"
      ) {
        if appState.tapStatus == .permissionRevoked {
          appDelegate.openGuide()
        } else {
          appDelegate.retryEventTap()
        }
      }
      Divider()
    }

    if appState.secureInputActive {
      Button("Bàn phím bị khóa bởi macOS (Secure Input)…") {
        appDelegate.showSecureInputHelp()
      }
      Divider()
    }

    Toggle("Gõ tiếng Việt\(shortcutHint)", isOn: $appState.enabled)

    Divider()

    Picker("Kiểu gõ", selection: $appState.typingMethod) {
      ForEach(TypingMethods.allCases, id: \.self) { method in
        Text(method.rawValue).tag(method)
      }
    }
    .pickerStyle(.inline)

    if appState.activeAppName != AppState.unknownApp {
      Divider()
      Menu("Ứng dụng: \(appState.activeAppDisplayName)") {
        Picker(
          "Chế độ gõ",
          selection: Binding(
            get: { appState.store.preference(for: appState.activeAppName) },
            set: { appState.setPreference($0, for: appState.activeAppName) }
          )
        ) {
          ForEach(AppModePreference.allCases, id: \.self) { choice in
            Text(choice.title).tag(choice)
          }
        }
        .pickerStyle(.inline)

        Divider()

        Picker(
          "Cách gửi phím",
          selection: Binding(
            get: { appState.activeStrategyOverride },
            set: { appState.setStrategyOverride($0) }
          )
        ) {
          ForEach(SendingStrategyOverride.allCases, id: \.self) { choice in
            Text(choice.title).tag(choice)
          }
        }
        .pickerStyle(.inline)
      }
    }

    Divider()

    Button("Kiểm tra cập nhật…") {
      appDelegate.updaterController.checkForUpdates(nil)
    }

    Button("Cài đặt") {
      openSettings()
      NSApp.activate(ignoringOtherApps: true)
    }
    .keyboardShortcut(",", modifiers: .command)

    Divider()

    Button("Thoát") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
  }
}

struct GuideMenuView: View {
  var appDelegate: AppDelegate

  var body: some View {
    Button("Hướng dẫn cài đặt") {
      appDelegate.openGuide()
    }

    Divider()

    Button("Thoát") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
  }
}

struct MenuBarLabel: View {
  var appState: AppState
  var isTrusted: Bool

  var body: some View {
    if !isTrusted {
      Image(systemName: "gear.badge.questionmark")
        .accessibilityLabel("Caffee cần quyền Accessibility")
    } else if !appState.tapStatus.isHealthy {
      Image(systemName: "exclamationmark.triangle")
        .help("Bộ gõ chưa hoạt động. Mở menu để xem chi tiết.")
        .accessibilityLabel("Bộ gõ chưa hoạt động")
    } else if appState.secureInputActive {
      Image(systemName: "lock.square")
        .help("macOS Secure Input đang chặn bàn phím. Mở menu để xem cách khắc phục.")
        .accessibilityLabel("Bàn phím bị khóa bởi macOS Secure Input")
    } else {
      Image(systemName: appState.enabled ? "v.square" : "e.square")
        .accessibilityLabel(appState.enabled ? "Đang gõ tiếng Việt" : "Đang gõ tiếng Anh")
    }
  }
}
