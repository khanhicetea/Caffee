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
        case removeIME = 3
    }

    @Published var currentStep: Step = .welcome
    @Published var permissionGranted: Bool = false
    @Published var selectedMethod: TypingMethods = Defaults[.typingMethod]
    @Published var launchAtLogin: Bool = true

    private var permissionTimer: Timer?

    init() {
        // Check if permissions already granted
        let eventHook = EventHook(inputProcessor: InputProcessor(method: Defaults[.typingMethod]))
        if eventHook.isTrusted(prompt: false) {
            permissionGranted = true
            currentStep = .removeIME
        }
    }

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
                case .removeIME:
                    RemoveIMEStepView(viewModel: viewModel, appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Step Indicator
            StepIndicator(
                totalSteps: OnboardingViewModel.Step.allCases.count,
                currentStep: viewModel.currentStep.rawValue
            )
            .padding(.bottom, 24)
        }
        .frame(width: 800, height: 700)
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
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // App Icon
            Image("Cficon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

            // Title
            Text("Caffee")
                .font(.system(size: 40, weight: .bold))

            Text("Bộ gõ tiếng Việt cho macOS")
                .font(.system(size: 20))
                .foregroundColor(.secondary)

            // Description
            VStack(spacing: 16) {
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
            .padding(.horizontal, 48)
            .padding(.top, 20)

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
                .frame(width: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer().frame(height: 24)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 32)
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 13))
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
                    .font(.system(size: 28, weight: .semibold))
                Spacer()
                Text("Bước 2/4")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 48)
            .padding(.top, 24)

            // Screenshot
            Image("PermissionGuide")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 260)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)

            // Instructions
            VStack(alignment: .leading, spacing: 14) {
                InstructionStep(
                    number: 1, text: "Bấm nút bên dưới để mở Cài đặt",
                    isCompleted: hasRequestedPermission)
                InstructionStep(
                    number: 2, text: "Bật công tắc bên cạnh \"Caffee\"",
                    isCompleted: viewModel.permissionGranted)
                InstructionStep(
                    number: 3, text: "Xác thực bằng vân tay hoặc mật khẩu",
                    isCompleted: viewModel.permissionGranted)
            }
            .padding(.horizontal, 48)

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
                        .frame(width: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if hasRequestedPermission {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Đang chờ cấp quyền...")
                                .font(.system(size: 14))
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
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                } else {
                    Text("\(number)")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
            }

            Text(text)
                .font(.system(size: 18))
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
                    .font(.system(size: 28, weight: .semibold))
                Spacer()
                Text("Bước 3/4")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 48)
            .padding(.top, 24)

            // Success Badge
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Đã cấp quyền thành công!")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Hãy chọn kiểu gõ và tùy chọn khác.")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 48)

            // Typing Method Selection
            VStack(alignment: .leading, spacing: 14) {
                Text("Chọn kiểu gõ:")
                    .font(.system(size: 18, weight: .semibold))

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
            .padding(.horizontal, 48)

            // Options
            VStack(alignment: .leading, spacing: 18) {
                Text("Tùy chọn:")
                    .font(.system(size: 18, weight: .semibold))

                Toggle(isOn: $viewModel.launchAtLogin) {
                    HStack {
                        Image(systemName: "power")
                            .frame(width: 24)
                        Text("Khởi động cùng máy tính")
                            .font(.system(size: 26))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            }
            .padding(.horizontal, 48)

            // Shortcut Info
            HStack(spacing: 14) {
                Image(systemName: "command")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Phím tắt bật/tắt: Option + Z")
                        .font(.system(size: 16, weight: .medium))
                    Text("Bạn có thể đổi trong Cài đặt sau.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 48)

            Spacer()

            // Next Button
            Button(action: {
                withAnimation {
                    viewModel.currentStep = .removeIME
                }
            }) {
                HStack {
                    Text("Tiếp theo")
                    Image(systemName: "arrow.right")
                }
                .frame(width: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer().frame(height: 12)
        }
        .onAppear {
            // Bring app to front when configuration step appears (permissions already granted)
            NSApp.activate(ignoringOtherApps: true)
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
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }

                Text(method == .Telex ? "aa->â, aw->ă, as->á" : "a6->â, a8->ă, a1->á")
                    .font(.system(size: 18))
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

// MARK: - Step 4: Remove IME

struct RemoveIMEStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let appState: AppState
    @State private var currentPage = 0
    @State private var carouselTimer: Timer? = nil

    let carouselImages = [
        ("RemoveIME1", "Bước 1: Chọn bộ gõ cần gỡ"),
        ("RemoveIME2", "Bước 2: Bấm dấu trừ để gỡ"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Gỡ bỏ bộ gõ cũ")
                    .font(.system(size: 28, weight: .semibold))
                Spacer()
                Text("Bước 4/4")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 48)
            .padding(.top, 24)

            // Warning message
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tránh xung đột bộ gõ")
                        .font(.system(size: 22, weight: .semibold))
                    Text(
                        "Nên gỡ Telex, SimpleTelex hoặc các bộ gõ tiếng Việt khác để tránh xung đột."
                    )
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 48)

            // Carousel with screenshots
            VStack(spacing: 8) {
                ZStack {
                    ForEach(0..<carouselImages.count, id: \.self) { index in
                        VStack(spacing: 8) {
                            Image(carouselImages[index].0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 48)

                            Text(carouselImages[index].1)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .opacity(currentPage == index ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5), value: currentPage)
                    }
                }
                .frame(height: 320)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<carouselImages.count, id: \.self) { index in
                        Circle()
                            .fill(
                                currentPage == index ? Color.accentColor : Color.gray.opacity(0.3)
                            )
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 4)
            }
            .onAppear {
                startCarouselTimer()
            }
            .onDisappear {
                stopCarouselTimer()
            }

            // Instructions
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Mở System Settings → Keyboard → Input Sources")
                        .font(.system(size: 14))
                }
                HStack(spacing: 8) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Chọn bộ gõ tiếng Việt (Telex, SimpleTelex...)")
                        .font(.system(size: 14))
                }
                HStack(spacing: 8) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Bấm dấu trừ (-) để gỡ bỏ")
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 48)

            Spacer()

            // Open Settings Button
            Button(action: {
                if let url = URL(
                    string: "x-apple.systempreferences:com.apple.preference.keyboard?InputSources")
                {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Mở Cài đặt Bàn phím")
                }
                .frame(width: 260)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            // Complete Button
            Button(action: {
                stopCarouselTimer()
                viewModel.completeOnboarding(appState: appState)
            }) {
                HStack {
                    Text("Hoàn tất cài đặt")
                    Image(systemName: "checkmark")
                }
                .frame(width: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Ứng dụng sẽ khởi động lại sau khi hoàn tất.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer().frame(height: 12)
        }
    }

    private func startCarouselTimer() {
        carouselTimer?.invalidate()
        carouselTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation {
                currentPage = (currentPage + 1) % carouselImages.count
            }
        }
    }

    private func stopCarouselTimer() {
        carouselTimer?.invalidate()
        carouselTimer = nil
    }
}

// MARK: - Onboarding Window Controller

class OnboardingWindowController: NSWindowController {
    override init(window: NSWindow? = nil) {
        super.init(window: window)
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("Onboarding Window")
            window.title = "Caffee - Cài Đặt"
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
