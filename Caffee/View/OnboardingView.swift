//
//  OnboardingView.swift
//  Caffee
//
//  Created by KhanhIceTea on 30/01/2025.
//

import Cocoa
import Defaults
import LaunchAtLogin
import SwiftUI

// MARK: - Onboarding ViewModel

class OnboardingViewModel: ObservableObject {
  enum Step: Int, CaseIterable {
    case welcome = 0
    case permission = 1
    case configuration = 2
  }

  @Published var currentStep: Step = .welcome
  @Published var permissionGranted: Bool = false
  @Published var selectedMethod: TypingMethods = Defaults[.typingMethod]
  @Published var launchAtLogin: Bool = true

  private var permissionTimer: Timer?

  func startPermissionPolling(eventHook: EventHook) {
    permissionTimer?.invalidate()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
      [weak self] timer in
      if eventHook.isTrusted(prompt: false) {
        timer.invalidate()
        DispatchQueue.main.async {
          self?.permissionGranted = true
          // Auto-advance after short delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self?.currentStep = .configuration
          }
        }
      }
    }
  }

  func stopPermissionPolling() {
    permissionTimer?.invalidate()
    permissionTimer = nil
  }

  func completeOnboarding(appState: AppState) {
    // Save settings
    Defaults[.typingMethod] = selectedMethod
    appState.typingMethod = selectedMethod
    LaunchAtLogin.isEnabled = launchAtLogin

    // Relaunch app
    relaunchApp()
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

  deinit {
    stopPermissionPolling()
  }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
  @EnvironmentObject var appState: AppState
  @StateObject private var viewModel = OnboardingViewModel()

  var body: some View {
    VStack(spacing: 0) {
      // Content
      Group {
        switch viewModel.currentStep {
        case .welcome:
          WelcomeStepView(viewModel: viewModel)
        case .permission:
          PermissionStepView(viewModel: viewModel, appState: appState)
        case .configuration:
          ConfigurationStepView(viewModel: viewModel, appState: appState)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      // Step Indicator
      StepIndicator(
        totalSteps: OnboardingViewModel.Step.allCases.count,
        currentStep: viewModel.currentStep.rawValue
      )
      .padding(.bottom, 20)
    }
    .frame(width: 520, height: 520)
    .background(Color(NSColor.windowBackgroundColor))
  }
}

// MARK: - Step Indicator

struct StepIndicator: View {
  let totalSteps: Int
  let currentStep: Int

  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<totalSteps, id: \.self) { index in
        Circle()
          .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
          .frame(width: 8, height: 8)
          .animation(.easeInOut(duration: 0.3), value: currentStep)
      }
    }
  }
}

// MARK: - Step 1: Welcome

struct WelcomeStepView: View {
  @ObservedObject var viewModel: OnboardingViewModel

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      // App Icon
      Image("Cficon")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

      // Title
      Text("Caffee")
        .font(.system(size: 32, weight: .bold))

      Text("Bộ gõ tiếng Việt cho macOS")
        .font(.system(size: 16))
        .foregroundColor(.secondary)

      // Description
      VStack(spacing: 12) {
        FeatureRow(
          icon: "keyboard",
          text: "Gõ tiếng Việt dễ dàng với Telex hoặc VNI"
        )
        FeatureRow(
          icon: "bolt.fill",
          text: "Nhanh, nhẹ, không làm chậm máy"
        )
        FeatureRow(
          icon: "lock.shield",
          text: "An toàn, không gửi dữ liệu đi đâu"
        )
      }
      .padding(.horizontal, 40)
      .padding(.top, 10)

      Spacer()

      // Next Button
      Button(action: {
        withAnimation {
          viewModel.currentStep = .permission
        }
      }) {
        HStack {
          Text("Bắt đầu cài đặt")
          Image(systemName: "arrow.right")
        }
        .frame(width: 200)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

      Spacer().frame(height: 20)
    }
  }
}

struct FeatureRow: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .frame(width: 24)
        .foregroundColor(.accentColor)
      Text(text)
        .font(.system(size: 14))
      Spacer()
    }
  }
}

// MARK: - Step 2: Permission

struct PermissionStepView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  let appState: AppState
  @State private var hasRequestedPermission = false

  var body: some View {
    VStack(spacing: 12) {
      // Header
      HStack {
        Text("Cấp quyền Accessibility")
          .font(.system(size: 20, weight: .semibold))
        Spacer()
        Text("Bước 2/3")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 30)
      .padding(.top, 16)

      // Screenshot
      Image("PermissionGuide")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxHeight: 220)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)

      // Instructions
      VStack(alignment: .leading, spacing: 10) {
        InstructionStep(number: 1, text: "Bấm nút bên dưới để mở Cài đặt", isCompleted: hasRequestedPermission)
        InstructionStep(number: 2, text: "Bật công tắc bên cạnh \"Caffee\"", isCompleted: viewModel.permissionGranted)
        InstructionStep(number: 3, text: "Xác thực bằng vân tay hoặc mật khẩu", isCompleted: viewModel.permissionGranted)
      }
      .padding(.horizontal, 30)

      Spacer()

      // Action Button
      if viewModel.permissionGranted {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
          Text("Đã cấp quyền thành công!")
            .foregroundColor(.green)
        }
        .font(.system(size: 16, weight: .medium))
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
    .onAppear {
      viewModel.startPermissionPolling(eventHook: appState.eventHook)
    }
    .onDisappear {
      viewModel.stopPermissionPolling()
    }
  }

  private func openAccessibilitySettings() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }
}

struct InstructionStep: View {
  let number: Int
  let text: String
  var isCompleted: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(isCompleted ? Color.green : Color.accentColor)
          .frame(width: 28, height: 28)

        if isCompleted {
          Image(systemName: "checkmark")
            .foregroundColor(.white)
            .font(.system(size: 12, weight: .bold))
        } else {
          Text("\(number)")
            .foregroundColor(.white)
            .font(.system(size: 14, weight: .bold))
        }
      }

      Text(text)
        .font(.system(size: 14))
        .foregroundColor(isCompleted ? .secondary : .primary)
    }
  }
}

// MARK: - Step 3: Configuration

struct ConfigurationStepView: View {
  @ObservedObject var viewModel: OnboardingViewModel
  let appState: AppState

  var body: some View {
    VStack(spacing: 20) {
      // Header
      HStack {
        Text("Hoàn tất cài đặt")
          .font(.system(size: 20, weight: .semibold))
        Spacer()
        Text("Bước 3/3")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .padding(.horizontal, 30)
      .padding(.top, 20)

      // Success Badge
      HStack(spacing: 12) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 32))
          .foregroundColor(.green)

        VStack(alignment: .leading, spacing: 2) {
          Text("Đã cấp quyền thành công!")
            .font(.system(size: 16, weight: .semibold))
          Text("Hãy chọn kiểu gõ và tùy chọn khác.")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.green.opacity(0.1))
      .cornerRadius(12)
      .padding(.horizontal, 30)

      // Typing Method Selection
      VStack(alignment: .leading, spacing: 12) {
        Text("Chọn kiểu gõ:")
          .font(.system(size: 14, weight: .semibold))

        HStack(spacing: 12) {
          TypingMethodCard(
            method: .Telex,
            isSelected: viewModel.selectedMethod == .Telex,
            action: { viewModel.selectedMethod = .Telex }
          )

          TypingMethodCard(
            method: .VNI,
            isSelected: viewModel.selectedMethod == .VNI,
            action: { viewModel.selectedMethod = .VNI }
          )
        }
      }
      .padding(.horizontal, 30)

      // Options
      VStack(alignment: .leading, spacing: 16) {
        Text("Tùy chọn:")
          .font(.system(size: 14, weight: .semibold))

        Toggle(isOn: $viewModel.launchAtLogin) {
          HStack {
            Image(systemName: "power")
              .frame(width: 20)
            Text("Khởi động cùng máy tính")
          }
        }
        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
      }
      .padding(.horizontal, 30)

      // Shortcut Info
      HStack(spacing: 12) {
        Image(systemName: "command")
          .font(.system(size: 20))
          .foregroundColor(.accentColor)

        VStack(alignment: .leading, spacing: 2) {
          Text("Phím tắt bật/tắt: Option + Z")
            .font(.system(size: 14, weight: .medium))
          Text("Bạn có thể đổi trong Cài đặt sau.")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
        Spacer()
      }
      .padding(12)
      .background(Color.gray.opacity(0.1))
      .cornerRadius(8)
      .padding(.horizontal, 30)

      Spacer()

      // Complete Button
      Button(action: {
        viewModel.completeOnboarding(appState: appState)
      }) {
        HStack {
          Text("Hoàn tất")
          Image(systemName: "checkmark")
        }
        .frame(width: 200)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

      Text("Ứng dụng sẽ khởi động lại sau khi hoàn tất.")
        .font(.system(size: 12))
        .foregroundColor(.secondary)

      Spacer().frame(height: 10)
    }
  }
}

struct TypingMethodCard: View {
  let method: TypingMethods
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(method.rawValue)
            .font(.system(size: 16, weight: .semibold))
          Spacer()
          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.accentColor)
          }
        }

        Text(method == .Telex ? "aa->a, aw->a, s->sac" : "a6->a, a8->a, 1->sac")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
      )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Onboarding Window Controller

class OnboardingWindowController: NSWindowController {
  override init(window: NSWindow? = nil) {
    super.init(window: window)
    if window == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered, defer: false)
      window.center()
      window.setFrameAutosaveName("Onboarding Window")
      window.title = "Caffee - Cai dat"
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.isMovableByWindowBackground = true
      self.window = window
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
  static var previews: some View {
    OnboardingView()
      .environmentObject(AppState())
      .previewDisplayName("Onboarding")
  }
}
