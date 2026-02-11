//
//  CaffeeApp.swift
//  Caffee
//
//  Created by KhanhIceTea on 20/02/2024.
//

import SwiftUI
import Sparkle

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
      GeneralView()
        .environment(appDelegate.appState)
    }
  }
}

struct MainMenuView: View {
  var appDelegate: AppDelegate
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    if let updateItem = appDelegate.updateItem {
      Button("Cập nhật mới \(updateItem.displayVersionString) đã có sẵn!") {
        appDelegate.updaterController.checkForUpdates(nil)
      }
      Divider()
    }

    Button("Tắt / Mở") {
      appDelegate.appState.enabled.toggle()
    }
    
    Divider()
    
    Button(appDelegate.appState.typingMethod == .Telex ? "[✔] Kiểu Telex" : "Kiểu Telex") {
      appDelegate.appState.typingMethod = .Telex
    }
    
    Button(appDelegate.appState.typingMethod == .VNI ? "[✔] Kiểu VNI" : "Kiểu VNI") {
      appDelegate.appState.typingMethod = .VNI
    }
    
    Divider()
    
    Button("Check for Updates...") {
      appDelegate.updaterController.checkForUpdates(nil)
    }
    
    Button("Cài Đặt") {
      try? openSettings()
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
    } else if appState.secureInputActive {
      Image(systemName: "lock.square")
    } else {
      Image(systemName: appState.enabled ? "v.square" : "e.square")
    }
  }
}