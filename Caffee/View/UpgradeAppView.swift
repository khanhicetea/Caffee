//
//  UpgradeAppView.swift
//  Caffee
//
//  Created by KhanhIceTea on 30/01/2025.
//

import Cocoa
import SwiftUI

struct UpgradeAppView: View {
  @Environment(AppState.self) var appState
  var onDismiss: () -> Void = {}

  @State private var hasRequestedPermission = false
  @State private var permissionGranted = false

  private var hasActiveTap: Bool {
    appState.tapStatus == .active || appState.eventHook.eventTap != nil
  }

  var body: some View {
    VStack(spacing: 16) {
      // Header
      HStack {
        Image("Cficon")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 40, height: 40)
          .clipShape(.rect(cornerRadius: 8))

        VStack(alignment: .leading, spacing: 2) {
          Text("Cập nhật Caffee thành công!")
            .font(.system(size: 18, weight: .bold))
          Text("Cần cấp lại quyền Accessibility")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
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
        .clipShape(.rect(cornerRadius: 8))
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
              .foregroundStyle(.green)
            Text("Đã cấp quyền thành công!")
              .foregroundStyle(.green)
          }
          .font(.system(size: 16, weight: .medium))

          if hasActiveTap {
            Button(action: onDismiss) {
              HStack {
                Text("Hoàn tất")
                Image(systemName: "checkmark")
              }
              .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
          } else {
            Button(action: SystemActions.relaunchApp) {
              HStack {
                Text("Khởi động lại")
                Image(systemName: "arrow.clockwise")
              }
              .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
          }
        }
      } else {
        VStack(spacing: 10) {
          Button(action: {
            SystemActions.openAccessibilitySettings()
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
                .foregroundStyle(.secondary)
            }
          }
        }
      }

      Spacer().frame(height: 16)
    }
    .frame(width: 520, height: 480)
    .onChange(of: appState.permission.isTrusted, initial: true) { _, trusted in
      permissionGranted = trusted
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
            .foregroundStyle(.white)
            .font(.system(size: 11, weight: .bold))
        } else {
          Text("\(number)")
            .foregroundStyle(.white)
            .font(.system(size: 13, weight: .bold))
        }
      }

      Text(text)
        .font(.system(size: 13))
        .foregroundStyle(isCompleted ? .secondary : .primary)
    }
  }
}

#Preview("UpgradeAppView") {
  UpgradeAppView()
    .environment(AppState())
    .padding()
}
