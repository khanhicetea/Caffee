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
        MainMenuView(appState: appDelegate.appState, updaterController: appDelegate.updaterController)
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
  var appState: AppState
  var updaterController: SPUStandardUpdaterController

  var body: some View {
    Button("Tắt / Mở") {
      appState.enabled.toggle()
    }
    
    Divider()
    
    Button(appState.typingMethod == .Telex ? "[✔] Kiểu Telex" : "Kiểu Telex") {
      appState.typingMethod = .Telex
    }
    
    Button(appState.typingMethod == .VNI ? "[✔] Kiểu VNI" : "Kiểu VNI") {
      appState.typingMethod = .VNI
    }
    
    Divider()
    
    Button("Check for Updates...") {
      updaterController.checkForUpdates(nil)
    }
    
    SettingsLink {
      Text("Cài Đặt")
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