# Caffee Onboarding Improvement Plan

## Current State Analysis

### Files Involved
- `Caffee/View/GuideView.swift` - First-launch permission request
- `Caffee/View/UpgradeAppView.swift` - Post-update permission re-grant
- `Caffee/App/AppDelegate.swift` - Onboarding flow control

### Current Issues

| Issue | Location | Severity |
|-------|----------|----------|
| Wall of text instructions | GuideView.swift:10-16 | High |
| No progress indicator | Both views | High |
| Manual permission check required | GuideView.swift:51-61 | High |
| Deprecated "System Preferences" AppleScript | UpgradeAppView.swift:4-20 | High |
| Mixed Vietnamese/English | Both views | Medium |
| Manual app restart required | GuideView.swift:27-32 | Medium |
| No app branding/welcome | Both views | Medium |
| No visual aids/screenshots | Both views | Medium |
| No typing method selection | Onboarding flow | Low |

---

## Proposed New Onboarding Flow

### Step 1: Welcome Screen
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                      [☕ App Icon]                       │
│                                                         │
│                        Caffee                           │
│              Bộ gõ tiếng Việt cho macOS                 │
│                                                         │
│   Gõ tiếng Việt dễ dàng với Telex hoặc VNI             │
│   ngay trên bàn phím của bạn.                          │
│                                                         │
│                  [Bắt đầu cài đặt]                      │
│                                                         │
│                        ● ○ ○                            │
└─────────────────────────────────────────────────────────┘
```

### Step 2: Permission Request
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   Cấp quyền Accessibility                    Bước 2/3  │
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │  [gear.badge icon]                              │   │
│   │                                                 │   │
│   │  Caffee cần quyền Accessibility để thay đổi    │   │
│   │  các ký tự bạn gõ thành tiếng Việt có dấu.     │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
│   Hướng dẫn:                                           │
│   ┌──┐                                                  │
│   │1 │ Bấm nút bên dưới để mở Cài đặt Hệ thống        │
│   └──┘                                                  │
│   ┌──┐                                                  │
│   │2 │ Bật công tắc bên cạnh "Caffee"                 │
│   └──┘                                                  │
│   ┌──┐                                                  │
│   │3 │ Xác thực bằng vân tay hoặc mật khẩu            │
│   └──┘                                                  │
│                                                         │
│            [Mở Cài đặt Accessibility]                   │
│                                                         │
│   ○ Đang chờ cấp quyền...  (auto-detecting)            │
│                                                         │
│                        ○ ● ○                            │
└─────────────────────────────────────────────────────────┘
```

### Step 3: Configuration & Complete
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   Hoàn tất cài đặt                           Bước 3/3  │
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │  [checkmark.circle.fill icon - green]           │   │
│   │  Đã cấp quyền thành công!                       │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
│   Chọn kiểu gõ:                                        │
│   ┌─────────────────┐  ┌─────────────────┐             │
│   │ [✓] Telex       │  │ [ ] VNI         │             │
│   │ aa→â, aw→ă      │  │ a6→â, a8→ă      │             │
│   │ s→sắc, f→huyền  │  │ 1→sắc, 2→huyền  │             │
│   └─────────────────┘  └─────────────────┘             │
│                                                         │
│   Tùy chọn:                                            │
│   [✓] Khởi động cùng máy tính                          │
│                                                         │
│   Phím tắt bật/tắt: ⌃Space (có thể đổi trong Cài đặt) │
│                                                         │
│                    [Hoàn tất]                           │
│                                                         │
│                        ○ ○ ●                            │
└─────────────────────────────────────────────────────────┘
```

---

## Technical Implementation

### 1. New File Structure

```
Caffee/View/Onboarding/
├── OnboardingView.swift        # Main container with step navigation
├── WelcomeStepView.swift       # Step 1: Welcome
├── PermissionStepView.swift    # Step 2: Permission request
├── ConfigurationStepView.swift # Step 3: Configuration
└── OnboardingViewModel.swift   # State management
```

### 2. OnboardingViewModel

```swift
class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case permission = 1
        case configuration = 2
    }

    @Published var currentStep: Step = .welcome
    @Published var permissionGranted: Bool = false
    @Published var selectedMethod: TypingMethods = .Telex
    @Published var launchAtLogin: Bool = true

    private var permissionTimer: Timer?

    func startPermissionPolling(eventHook: EventHook) {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            if eventHook.isTrusted(prompt: false) {
                timer.invalidate()
                self?.permissionGranted = true
                // Auto-advance after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.currentStep = .configuration
                }
            }
        }
    }

    func completeOnboarding() {
        // Save settings
        Defaults[.typingMethod] = selectedMethod
        LaunchAtLogin.isEnabled = launchAtLogin

        // Relaunch app
        relaunchApp()
    }
}
```

### 3. Fix Deprecated System Settings URL

```swift
// Old (deprecated):
// tell application "System Preferences" ...

// New (macOS 13+):
func openAccessibilitySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
    }
}
```

### 4. Auto-Relaunch App

```swift
func relaunchApp() {
    let url = Bundle.main.bundleURL
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true

    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
}
```

### 5. Permission Polling Timer

```swift
// In PermissionStepView
.onAppear {
    viewModel.startPermissionPolling(eventHook: appState.eventHook)
}
.onDisappear {
    viewModel.stopPermissionPolling()
}
```

---

## UI Components

### Progress Indicator
```swift
struct StepIndicator: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}
```

### Numbered Step Card
```swift
struct StepCard: View {
    let number: Int
    let title: String
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.accentColor)
                    .frame(width: 28, height: 28)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                } else {
                    Text("\(number)")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
            }

            Text(title)
                .font(.system(size: 14))
        }
    }
}
```

### Typing Method Selector
```swift
struct TypingMethodCard: View {
    let method: TypingMethods
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(method == .Telex ? "Telex" : "VNI")
                        .font(.headline)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Text(method == .Telex ? "aa→â, aw→ă, s→sắc" : "a6→â, a8→ă, 1→sắc")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
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
```

---

## Upgrade Flow (Simplified)

For app upgrades, simplify to a single screen:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                      [☕ App Icon]                       │
│                                                         │
│              Cập nhật Caffee thành công!                │
│                                                         │
│   macOS yêu cầu cấp lại quyền sau mỗi lần cập nhật.    │
│                                                         │
│   ┌──┐                                                  │
│   │1 │ Bấm nút bên dưới để mở Cài đặt                  │
│   └──┘                                                  │
│   ┌──┐                                                  │
│   │2 │ Tắt rồi bật lại công tắc "Caffee"              │
│   └──┘                                                  │
│                                                         │
│            [Mở Cài đặt Accessibility]                   │
│                                                         │
│   ○ Đang chờ cấp quyền...                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Priority

### Phase 1 (High Priority)
- [ ] Create OnboardingViewModel with step management
- [ ] Implement 3-step wizard container
- [ ] Add permission auto-detection polling
- [ ] Fix deprecated System Settings URL
- [ ] Add auto-relaunch functionality

### Phase 2 (Medium Priority)
- [ ] Design WelcomeStepView with app branding
- [ ] Design PermissionStepView with numbered instructions
- [ ] Design ConfigurationStepView with method selection
- [ ] Add step progress indicator
- [ ] Consistent Vietnamese language

### Phase 3 (Polish)
- [ ] Add subtle animations (fade, slide)
- [ ] Add success checkmark animation
- [ ] Simplify UpgradeAppView
- [ ] Add keyboard navigation support
- [ ] Test on macOS 13, 14, 15

---

## Window Specifications

```swift
// Onboarding window size
let windowSize = NSSize(width: 500, height: 450)

// Style
styleMask: [.titled, .closable, .fullSizeContentView]
titlebarAppearsTransparent: true
titleVisibility: .hidden
```

---

## Notes

- All text should be in Vietnamese
- Use SF Symbols for icons (consistent with macOS)
- Support both light and dark mode
- Minimum deployment target: macOS 13 (Ventura)
