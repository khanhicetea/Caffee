# Big Refactor Plan - Caffee IME

## Overview
This document outlines a comprehensive refactoring plan for Caffee, keeping the **Engine** layer intact while modernizing and improving the **Platform** and **App** layers.

**Goal**: Create a cleaner, more maintainable architecture with better separation of concerns, improved testability, and modern Swift patterns.

---

## Current Architecture Analysis

### What We're Keeping: Engine Layer ✅
The Engine layer is solid and well-designed:
- `TiengViet.swift` - Core Vietnamese syllable model with tone marks and diacritics
- `TiengVietParser.swift` - Parsing logic for Vietnamese text
- `TiengVietState.swift` - State management for typing process
- `TiengVietTransformer.swift` - Text transformation logic
- `TiengVietValidator.swift` - Vietnamese syllable validation
- `Telex.swift` / `VNI.swift` - Input method implementations
- `TypingMethod.swift` - Protocol definition

**Why keep it?** Solid linguistic logic, well-tested, proven to work correctly.

### What We're Refactoring: Platform & App Layers 🔄

#### Current Issues:
1. **Tight Coupling**: AppState knows too much about EventHook, InputProcessor, and platform details
2. **Mixed Responsibilities**: InputProcessor handles both typing logic AND platform-specific quirks (app strategies, autocomplete fixes)
3. **Global State Management**: Heavy use of Combine publishers, scattered state
4. **Hard to Test**: Platform dependencies make unit testing difficult
5. **Inconsistent Patterns**: Mix of Combine, delegates, @objc callbacks
6. **Legacy Code Smell**: EventSimulator has grown complex with per-app strategies

---

## New Architecture Design

### 1. Core Principles

#### Clean Architecture Layers:
```
┌─────────────────────────────────────────┐
│           UI Layer (SwiftUI)             │
│  - MenuBar, Settings, Onboarding         │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Application Layer                │
│  - AppCoordinator (replaces AppState)    │
│  - InputCoordinator (replaces            │
│    InputProcessor business logic)        │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│          Domain Layer                    │
│  - Engine (Vietnamese typing logic)      │ ✅ KEEP AS-IS
│  - Models, Protocols                     │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│        Platform Layer                    │
│  - Keyboard Event System                 │
│  - Text Injection System                 │
│  - Accessibility Services                │
│  - App Detection                         │
└─────────────────────────────────────────┘
```

#### Design Patterns:
- **Protocol-Oriented Programming**: Define clear interfaces for all platform interactions
- **Dependency Injection**: Make all dependencies explicit and injectable
- **Strategy Pattern**: For per-app text sending strategies
- **Coordinator Pattern**: For app-level orchestration
- **Repository Pattern**: For settings and state persistence

---

## 2. Detailed Refactoring Plan

### Phase 1: Platform Layer Modernization

#### 2.1 Keyboard Event System
**Current**: `EventHook.swift` (116 lines, mixed responsibilities)

**New Structure**:
```
Platform/
├── Keyboard/
│   ├── KeyboardEventService.swift         # Main event tap manager
│   ├── KeyboardEventHandler.swift         # Protocol for handling events
│   ├── KeyboardLayoutMapping.swift        # Key code → character mapping
│   └── SecureInputDetector.swift          # Secure input mode detection
```

**KeyboardEventService.swift** - Clean interface:
```swift
protocol KeyboardEventHandling {
    func handleKeyDown(_ event: CGEvent) -> CGEvent?
    func handleModifiers(_ event: CGEvent) -> CGEvent?
    func handleMouse(_ event: CGEvent)
}

class KeyboardEventService {
    private let handler: KeyboardEventHandling
    private var eventTap: CFMachPort?
    private let secureInputDetector: SecureInputDetector
    
    init(handler: KeyboardEventHandling) { ... }
    
    func start() throws
    func stop()
    func isAccessibilityTrusted() -> Bool
}
```

**Benefits**:
- Easy to mock for testing
- Clear separation of event handling from business logic
- No direct dependency on InputProcessor

---

#### 2.2 Text Injection System
**Current**: `EventSimulator.swift` (350+ lines, complex per-app logic)

**New Structure**:
```
Platform/
├── TextInjection/
│   ├── TextInjectionService.swift         # Main service
│   ├── InjectionStrategy.swift            # Strategy protocol
│   ├── Strategies/
│   │   ├── BatchStrategy.swift
│   │   ├── StepByStepStrategy.swift
│   │   ├── HybridStrategy.swift
│   │   └── ArrowNavigationStrategy.swift
│   └── AppStrategyRegistry.swift          # Per-app strategy config
```

**TextInjectionService.swift**:
```swift
protocol TextInjectionStrategy {
    func inject(backspaces: Int, text: String, source: CGEventSource?)
}

class TextInjectionService {
    private let strategyRegistry: AppStrategyRegistry
    
    func replaceText(
        from: String,
        to: String,
        for bundleId: String
    ) {
        let strategy = strategyRegistry.strategy(for: bundleId)
        let (backspaces, diffChars) = calculateDiff(from: from, to: to)
        strategy.inject(backspaces: backspaces, text: String(diffChars))
    }
}
```

**AppStrategyRegistry.swift**:
```swift
struct AppStrategyConfig: Codable {
    let bundlePrefix: String
    let strategyType: StrategyType
    let parameters: [String: Any]?
}

class AppStrategyRegistry {
    // Load from JSON config file instead of hardcoded
    func strategy(for bundleId: String) -> TextInjectionStrategy
    func register(config: AppStrategyConfig)
    func detectAndUpdateStrategy(for bundleId: String, success: Bool)
}
```

**Benefits**:
- Strategies are interchangeable and testable
- Per-app configs can be loaded from external file
- Auto-detection logic separated from core injection
- Easy to add new strategies without modifying core code

---

#### 2.3 Accessibility Services
**Current**: `Focused.swift` (54 lines, basic wrapper)

**New Structure**:
```
Platform/
├── Accessibility/
│   ├── AccessibilityService.swift
│   ├── FocusedElement.swift              # Value type for focused element
│   └── TextSelection.swift               # Value type for selection
```

**AccessibilityService.swift**:
```swift
struct FocusedElement {
    let element: AXUIElement
    let text: String?
    let selectedText: String?
    let selectedRange: NSRange?
}

protocol AccessibilityServiceProtocol {
    func getFocusedElement() -> FocusedElement?
    func hasSelection() -> Bool
}

class AccessibilityService: AccessibilityServiceProtocol {
    // Clean, testable implementation
}
```

---

#### 2.4 App Detection
**Current**: Scattered in AppState, InputProcessor

**New Structure**:
```
Platform/
├── AppDetection/
│   ├── AppDetectionService.swift
│   ├── AppInfo.swift
│   └── AppChangeObserver.swift
```

**AppDetectionService.swift**:
```swift
struct AppInfo {
    let bundleId: String
    let name: String
    let isSecureInput: Bool
}

protocol AppChangeObserving: AnyObject {
    func appDidChange(to app: AppInfo)
}

class AppDetectionService {
    private var observers: [AppChangeObserving] = []
    
    func currentApp() -> AppInfo
    func startMonitoring()
    func stopMonitoring()
    func addObserver(_ observer: AppChangeObserving)
}
```

---

### Phase 2: Application Layer Refactoring

#### 2.5 Replace AppState with AppCoordinator
**Current**: `AppState.swift` (145 lines, does too much)

**New Structure**:
```
App/
├── Coordination/
│   ├── AppCoordinator.swift               # Main coordinator
│   ├── InputCoordinator.swift             # Input flow coordination
│   └── SettingsCoordinator.swift          # Settings management
├── State/
│   ├── InputModeState.swift               # Observable state
│   ├── TypingMethodState.swift
│   └── PerAppPreferences.swift            # App-specific settings
```

**AppCoordinator.swift**:
```swift
@MainActor
class AppCoordinator: ObservableObject {
    // Dependencies (injected)
    private let keyboardService: KeyboardEventService
    private let appDetection: AppDetectionService
    private let settingsRepo: SettingsRepository
    private let inputCoordinator: InputCoordinator
    
    // Published state (minimal)
    @Published var isEnabled: Bool = false
    @Published var currentApp: AppInfo?
    @Published var isSecureInput: Bool = false
    
    init(
        keyboardService: KeyboardEventService,
        appDetection: AppDetectionService,
        settingsRepo: SettingsRepository,
        inputCoordinator: InputCoordinator
    ) { ... }
    
    func start()
    func toggleEnabled()
    func setTypingMethod(_ method: TypingMethod)
}
```

**Benefits**:
- Single responsibility: coordinate high-level app flow
- All dependencies injected and mockable
- State is minimal and focused
- Easy to test coordinator logic

---

#### 2.6 Refactor InputProcessor → InputCoordinator
**Current**: `InputProcessor.swift` (280+ lines, mixed concerns)

**New Structure**:
```
App/
├── Input/
│   ├── InputCoordinator.swift             # Orchestrates input flow
│   ├── TypingStateManager.swift           # Manages word buffer
│   ├── InputEventHandler.swift            # Implements KeyboardEventHandling
│   └── AutocompleteHandler.swift          # Handles autocomplete quirks
```

**InputCoordinator.swift**:
```swift
class InputCoordinator {
    private let engine: TypingMethod
    private let stateManager: TypingStateManager
    private let textInjection: TextInjectionService
    private let autocompleteHandler: AutocompleteHandler
    
    var currentTypingMethod: TypingMethod { engine }
    
    func processCharacter(
        _ char: Character,
        for appInfo: AppInfo
    ) -> TextReplacement? {
        // Pure business logic - no platform calls
        let previousState = stateManager.currentState
        stateManager.push(char, using: engine)
        let newState = stateManager.currentState
        
        return TextReplacement(
            from: previousState.transformed,
            to: newState.transformed
        )
    }
    
    func handleBackspace()
    func handleWordBoundary()
    func reset()
}

struct TextReplacement {
    let from: String
    let to: String
}
```

**InputEventHandler.swift**:
```swift
class InputEventHandler: KeyboardEventHandling {
    private let coordinator: InputCoordinator
    private let textInjection: TextInjectionService
    private let appDetection: AppDetectionService
    
    func handleKeyDown(_ event: CGEvent) -> CGEvent? {
        // Platform-specific event handling
        // Delegates business logic to coordinator
        // Calls text injection service for replacement
    }
}
```

**Benefits**:
- Business logic separated from platform code
- Easy to unit test typing logic
- Platform code can be integration tested separately
- Clear data flow: Event → Handler → Coordinator → Engine → State → Injection

---

### Phase 3: Settings & Persistence

#### 2.7 Settings Management
**Current**: Direct Defaults access scattered everywhere

**New Structure**:
```
App/
├── Settings/
│   ├── SettingsRepository.swift           # Single source of truth
│   ├── SettingsModel.swift                # Value types
│   └── PerAppSettings.swift               # App-specific prefs
```

**SettingsRepository.swift**:
```swift
struct CaffeeSettings {
    var typingMethod: TypingMethod
    var allowedZWJF: Bool
    var autoSwitchStrategy: Bool
    var checkForUpdatesAutomatically: Bool
    // ... all settings
}

protocol SettingsRepositoryProtocol {
    func load() -> CaffeeSettings
    func save(_ settings: CaffeeSettings)
    func observe() -> AnyPublisher<CaffeeSettings, Never>
}

class SettingsRepository: SettingsRepositoryProtocol {
    // Wraps Defaults, provides clean interface
}
```

**PerAppSettings.swift**:
```swift
struct PerAppPreferences: Codable {
    var enabledState: [String: Bool] = [:]
    var customStrategies: [String: StrategyType] = [:]
    
    func isEnabled(for bundleId: String, default: Bool) -> Bool
    mutating func setEnabled(_ enabled: Bool, for bundleId: String)
}
```

---

### Phase 4: Dependency Injection & Testing

#### 2.8 Service Container
**New File**: `App/DI/ServiceContainer.swift`

```swift
class ServiceContainer {
    // Singletons
    lazy var settingsRepository: SettingsRepository = {
        SettingsRepository()
    }()
    
    lazy var appDetectionService: AppDetectionService = {
        AppDetectionService()
    }()
    
    lazy var accessibilityService: AccessibilityService = {
        AccessibilityService()
    }()
    
    lazy var textInjectionService: TextInjectionService = {
        TextInjectionService(
            strategyRegistry: AppStrategyRegistry()
        )
    }()
    
    lazy var inputCoordinator: InputCoordinator = {
        InputCoordinator(
            engine: createTypingEngine(),
            stateManager: TypingStateManager(),
            textInjection: textInjectionService,
            autocompleteHandler: AutocompleteHandler(
                accessibilityService: accessibilityService
            )
        )
    }()
    
    lazy var keyboardService: KeyboardEventService = {
        let handler = InputEventHandler(
            coordinator: inputCoordinator,
            textInjection: textInjectionService,
            appDetection: appDetectionService
        )
        return KeyboardEventService(handler: handler)
    }()
    
    lazy var appCoordinator: AppCoordinator = {
        AppCoordinator(
            keyboardService: keyboardService,
            appDetection: appDetectionService,
            settingsRepo: settingsRepository,
            inputCoordinator: inputCoordinator
        )
    }()
    
    private func createTypingEngine() -> TypingMethod {
        let method = settingsRepository.load().typingMethod
        return method == .Telex ? Telex() : VNI()
    }
}
```

#### 2.9 Testing Infrastructure
```
Tests/
├── UnitTests/
│   ├── InputCoordinatorTests.swift        # Pure business logic
│   ├── TypingStateManagerTests.swift
│   ├── StrategyTests.swift
│   └── Mocks/
│       ├── MockTypingEngine.swift
│       ├── MockTextInjection.swift
│       └── MockAppDetection.swift
├── IntegrationTests/
│   ├── KeyboardEventTests.swift
│   └── TextInjectionTests.swift
└── UITests/
    └── OnboardingFlowTests.swift
```

---

## 3. Migration Strategy

### Step-by-Step Approach

#### Week 1: Platform Layer
- [ ] Create new `Platform/Keyboard/` structure
- [ ] Implement `KeyboardEventService` with protocol
- [ ] Move `EventHook` logic to new service
- [ ] Add unit tests for keyboard service

#### Week 2: Text Injection
- [ ] Create `Platform/TextInjection/` structure
- [ ] Extract strategies from `EventSimulator`
- [ ] Implement `AppStrategyRegistry` with JSON config
- [ ] Add tests for each strategy

#### Week 3: Application Layer (Part 1)
- [ ] Create `InputCoordinator` with business logic from `InputProcessor`
- [ ] Create `TypingStateManager` for word buffer management
- [ ] Extract autocomplete logic to `AutocompleteHandler`
- [ ] Write unit tests (should be easy now!)

#### Week 4: Application Layer (Part 2)
- [ ] Create `AppCoordinator` to replace `AppState`
- [ ] Implement `SettingsRepository`
- [ ] Implement `PerAppSettings`
- [ ] Update all Combine publishers to new structure

#### Week 5: Dependency Injection
- [ ] Create `ServiceContainer`
- [ ] Update `AppDelegate` to use container
- [ ] Remove all global state and singletons
- [ ] Ensure all dependencies are injected

#### Week 6: UI & Integration
- [ ] Update SwiftUI views to use new coordinators
- [ ] Update menu bar to observe new state
- [ ] Ensure onboarding flow still works
- [ ] Add integration tests

#### Week 7: Polish & Documentation
- [ ] Remove old files (`AppState.swift`, `InputProcessor.swift`, etc.)
- [ ] Update documentation and comments
- [ ] Add architecture diagram to README
- [ ] Performance testing and optimization

---

## 4. File Organization (After Refactor)

```
Caffee/
├── CaffeeApp.swift                        # Entry point
├── App/
│   ├── AppDelegate.swift                  # Updated to use ServiceContainer
│   ├── DI/
│   │   └── ServiceContainer.swift
│   ├── Coordination/
│   │   ├── AppCoordinator.swift
│   │   ├── InputCoordinator.swift
│   │   └── SettingsCoordinator.swift
│   ├── Input/
│   │   ├── TypingStateManager.swift
│   │   ├── InputEventHandler.swift
│   │   └── AutocompleteHandler.swift
│   ├── Settings/
│   │   ├── SettingsRepository.swift
│   │   ├── SettingsModel.swift
│   │   └── PerAppSettings.swift
│   └── State/
│       ├── InputModeState.swift
│       └── TypingMethodState.swift
├── Engine/                                 # ✅ NO CHANGES
│   ├── TiengViet.swift
│   ├── TiengVietParser.swift
│   ├── TiengVietState.swift
│   ├── TiengVietTransformer.swift
│   ├── TiengVietValidator.swift
│   ├── Telex.swift
│   ├── VNI.swift
│   └── TypingMethod.swift
├── Platform/
│   ├── Keyboard/
│   │   ├── KeyboardEventService.swift
│   │   ├── KeyboardEventHandler.swift     # Protocol
│   │   ├── KeyboardLayoutMapping.swift
│   │   └── SecureInputDetector.swift
│   ├── TextInjection/
│   │   ├── TextInjectionService.swift
│   │   ├── InjectionStrategy.swift        # Protocol
│   │   ├── AppStrategyRegistry.swift
│   │   └── Strategies/
│   │       ├── BatchStrategy.swift
│   │       ├── StepByStepStrategy.swift
│   │       ├── HybridStrategy.swift
│   │       └── ArrowNavigationStrategy.swift
│   ├── Accessibility/
│   │   ├── AccessibilityService.swift
│   │   ├── FocusedElement.swift
│   │   └── TextSelection.swift
│   └── AppDetection/
│       ├── AppDetectionService.swift
│       ├── AppInfo.swift
│       └── AppChangeObserver.swift
├── View/                                   # Minimal changes
│   ├── GuideView.swift
│   ├── MacroView.swift
│   ├── OnboardingView.swift
│   ├── SettingView.swift                  # Update to use coordinators
│   └── UpgradeAppView.swift
├── KeyLayout/                              # Move to Platform/Keyboard/
│   ├── KeyboardUS.swift
│   └── Keys.swift
└── Resources/
    ├── AppStrategies.json                 # NEW: Per-app configs
    └── Assets.xcassets
```

---

## 5. Key Benefits of This Refactor

### Code Quality
- ✅ **Separation of Concerns**: Each component has one clear responsibility
- ✅ **Testability**: All business logic can be unit tested easily
- ✅ **Maintainability**: Changes isolated to specific modules
- ✅ **Readability**: Clear data flow and dependencies

### Architecture
- ✅ **Protocol-Oriented**: Easy to mock and swap implementations
- ✅ **Dependency Injection**: No hidden dependencies or singletons
- ✅ **Clean Layers**: UI → App → Domain → Platform
- ✅ **SOLID Principles**: Followed throughout

### Features
- ✅ **Extensibility**: Easy to add new typing methods, strategies, or platforms
- ✅ **Configuration**: Per-app strategies can be updated without code changes
- ✅ **Performance**: Optimized text injection strategies per app
- ✅ **Reliability**: Better error handling and state management

### Developer Experience
- ✅ **Easy to Debug**: Clear boundaries and minimal state
- ✅ **Easy to Test**: Mocks and stubs for all external dependencies
- ✅ **Easy to Extend**: Add features without touching core logic
- ✅ **Easy to Understand**: Architecture diagram matches code structure

---

## 6. Backward Compatibility

### During Migration:
- Keep old files alongside new implementation
- Use feature flags to switch between old/new code paths
- Run both implementations in parallel during testing phase

### Settings Migration:
- Automatic migration of old Defaults keys to new structure
- Preserve per-app enabled states
- Preserve user preferences and shortcuts

### Data Migration:
```swift
class SettingsRepository {
    func migrateFromLegacy() {
        // Migrate old Defaults keys to new structure
        let oldEnabled = Defaults[.enabled] // if existed
        let oldMethod = Defaults[.typingMethod]
        // ... migrate all settings
    }
}
```

---

## 7. Success Metrics

### Code Metrics:
- [ ] Unit test coverage > 80%
- [ ] Average file size < 150 lines
- [ ] Max cyclomatic complexity < 10
- [ ] Zero retain cycles / memory leaks

### Performance:
- [ ] Event handling latency < 5ms (same as current)
- [ ] Memory usage < 50MB (same or better)
- [ ] No UI lag on app switching

### Quality:
- [ ] All existing features work identically
- [ ] No regressions in Vietnamese typing accuracy
- [ ] Per-app preferences preserved
- [ ] Onboarding flow unchanged

---

## 8. Risk Mitigation

### Potential Risks:
1. **Event handling regression**: Keyboard events might behave differently
   - **Mitigation**: Integration tests, parallel running during testing
   
2. **Text injection failures**: New strategies might break some apps
   - **Mitigation**: Keep fallback to old implementation, gradual rollout per app
   
3. **Performance degradation**: More layers could slow down event handling
   - **Mitigation**: Profile before/after, optimize hot paths
   
4. **State synchronization bugs**: New state management could have race conditions
   - **Mitigation**: Use `@MainActor`, strict concurrency checking

### Rollback Plan:
- Feature flag to switch back to old implementation
- Keep old files until new version is stable
- Phased rollout: internal testing → beta → production

---

## 9. Future Enhancements (Post-Refactor)

With the new architecture, these become much easier:

### Phase 5 (Future):
- [ ] Add telemetry for auto-strategy tuning
- [ ] Machine learning for app strategy detection
- [ ] Plugin system for custom typing methods
- [ ] Cloud sync for settings across devices
- [ ] Advanced macro system (currently commented out)
- [ ] Multi-language support beyond Vietnamese
- [ ] Custom keyboard layouts support

---

## 10. Questions to Consider

Before starting:
1. Do we need to support macOS < 13? (affects async/await usage)
2. Should we use Swift Concurrency everywhere or stick with Combine?
3. Do we want to support plugin architecture from the start?
4. Should we use SwiftData for settings instead of Defaults?
5. Do we need A/B testing infrastructure for new features?

---

## Conclusion

This refactor will transform Caffee from a working but tightly-coupled codebase into a modern, maintainable, and extensible application. By keeping the proven Engine layer and modernizing everything around it, we minimize risk while maximizing benefit.

**Estimated Timeline**: 7 weeks for full migration + 2 weeks buffer = ~2 months

**Effort Level**: Medium-High (touches most files but keeps core logic)

**Risk Level**: Medium (can be mitigated with phased approach)

**Reward Level**: High (much easier to maintain and extend going forward)

---

**Next Steps**:
1. Review this plan with team
2. Set up feature flag system for gradual migration
3. Create initial test suite for current behavior (regression tests)
4. Start with Week 1: Platform Layer
