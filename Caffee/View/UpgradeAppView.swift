//
//  UpgradeAppView.swift
//  Caffee
//
//  Created by KhanhIceTea on 30/01/2025.
//

import Cocoa
import SwiftUI

struct UpgradeAppView: View {
  @EnvironmentObject var appState: AppState

  @State private var hasRequestedPermission = false
  @State private var permissionGranted = false
  private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 16) {
      // Header
      HStack {
        Image("Cficon")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 40, height: 40)
          .clipShape(RoundedRectangle(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 2) {
          Text("Cập nhật Caffee thành công!")
            .font(.system(size: 18, weight: .bold))
          Text("Cần cấp lại quyền Accessibility")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
        Spacer()
      }
      .padding(.horizontal, 30)
      .padding(.top, 20)

      // Screenshot
      Image("PermissionGuide")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxHeight: 200)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)

      // Instructions
      VStack(alignment: .leading, spacing: 10) {
        UpgradeInstructionStep(
          number: 1, text: "Bấm nút bên dưới để mở Cài đặt",
          isCompleted: hasRequestedPermission)
        UpgradeInstructionStep(
          number: 2, text: "Tắt rồi bật lại công tắc \"Caffee\"",
          isCompleted: permissionGranted)
        UpgradeInstructionStep(
          number: 3, text: "Xác thực bằng vân tay hoặc mật khẩu",
          isCompleted: permissionGranted)
      }
      .padding(.horizontal, 30)

      Spacer()

      // Action Button
      if permissionGranted {
        VStack(spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
            Text("Đã cấp quyền thành công!")
              .foregroundColor(.green)
          }
          .font(.system(size: 16, weight: .medium))

          Button(action: relaunchApp) {
            HStack {
              Text("Khởi động lại")
              Image(systemName: "arrow.clockwise")
            }
            .frame(width: 200)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
        }
      } else {
        VStack(spacing: 10) {
          Button(action: {
            openAccessibilitySettings()
            hasRequestedPermission = true
          }) {
            HStack {
              Image(systemName: "gear")
              Text("Mở Cài đặt Accessibility")
            }
            .frame(width: 240)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)

          if hasRequestedPermission {
            HStack(spacing: 8) {
              ProgressView()
                .scaleEffect(0.7)
              Text("Đang chờ cấp quyền...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
          }
        }
      }

      Spacer().frame(height: 16)
    }
    .frame(width: 520, height: 480)
    .onReceive(permissionTimer) { _ in
      if hasRequestedPermission && !permissionGranted {
        permissionGranted = appState.eventHook.isTrusted(prompt: false)
      }
    }
  }

  private func openAccessibilitySettings() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }

  private func relaunchApp() {
    let url = Bundle.main.bundleURL
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true

    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
      DispatchQueue.main.async {
        NSApp.terminate(nil)
      }
    }
  }
}

struct UpgradeInstructionStep: View {
  let number: Int
  let text: String
  var isCompleted: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(isCompleted ? Color.green : Color.accentColor)
          .frame(width: 26, height: 26)

        if isCompleted {
          Image(systemName: "checkmark")
            .foregroundColor(.white)
            .font(.system(size: 11, weight: .bold))
        } else {
          Text("\(number)")
            .foregroundColor(.white)
            .font(.system(size: 13, weight: .bold))
        }
      }

      Text(text)
        .font(.system(size: 13))
        .foregroundColor(isCompleted ? .secondary : .primary)
    }
  }
}

struct UpgradeAppView_Previews: PreviewProvider {
  static var previews: some View {
    UpgradeAppView()
      .environmentObject(AppState())
      .previewLayout(PreviewLayout.sizeThatFits)
      .padding()
      .previewDisplayName("UpgradeAppView preview")
  }
}
