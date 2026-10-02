# Caffee — Big Audit

> Scope: every Swift source file in `Caffee/`, `CaffeeTests/`, `CaffeeUITests/`, plus the Xcode project settings, entitlements and Info.plist (snapshot of `main` @ `08ab807`, v1.30.3).
> Goal: concrete suggestions to make Caffee **more reliable**, **nicer to use**, and **better designed**, ranked by impact.

Legend: **P0** = user-visible bug or likely to cause data loss/garbled text · **P1** = high-value improvement · **P2** = polish / hygiene.

---

## Status (updated after the follow-up pass)

Everything below is **done** unless it is listed under "Not done". The sections further down are the original findings, kept for context.

| § | Item | Status |
|---|------|--------|
| 1.1 | Async replacements interleaving with real keys | Done: real keys queue behind pending output (`KeyEventPoster` / `EventHook`), tested |
| 1.2 | Layout-aware characters, numpad | Done: character comes from the system, US map is only a fallback |
| 1.3 | Switch file / automation | Done: control file moved to `~/Library/Application Support/Caffee/switch`, whole-file read, retained monitor, handles delete/rename; added `caffee://` URL scheme. Unknown text is ignored instead of meaning "disable" |
| 1.4 | Over-retained events | Done (`passUnretained`) |
| 1.5 | AX timeouts | Partly: global AX messaging timeout (0.1 s) is set. Not done: focused-element cache / `AXObserver`, moving the tap off the main thread |
| 1.6 | Tag own events | Done (`eventSourceUserData`) |
| 1.7 | Stale word buffer | Done: any non-text key resets the word |
| 1.8 | Tap health | Done: `TapStatus`, menu item and icon, trust re-checked on the timer |
| 1.9 | Auto-switch heuristic | Done: removed; per-app override replaces it |
| 1.10 | Smaller items | Done: 20-unit chunks, UTF-16 stepping, no per-key pasteboard poll, no global engine state (`EngineConfig`), one `PermissionMonitor` |
| 2.1 | Menu bar | Done: Toggle with shortcut hint, inline Picker, one language, current app + per-app mode, accessibility labels. Not done: text "VI/EN" icon style |
| 2.2 | Mode HUD | Done (`ModeHUD`, toggle in Settings) |
| 2.3 | Per-app behaviour | Done: persisted, Settings > Ứng dụng (mode pin + sending strategy). Not done: shipping Terminal-class apps as English by default (many users type Vietnamese in terminals) |
| 2.4 | Typing options | Done: tone placement, spelling check, relabelled foreign consonants; macro stub deleted. Not done: Telex `w` → `ư` (the state stores the substituted letter, so `ww` could not restore the raw key without key history) |
| 2.5 | Settings window | Done: grouped Form in tabs, diagnostics export |
| 2.6 | Onboarding / upgrade | Done: in-place onboarding, shared `SystemActions`, upgrade screen only shown if trust is still missing 1.5 s after launch, guide view deleted. Not done: investigating the designated requirement across releases, String Catalog |
| 2.7 | Secure Input | Done: names the holding app, non-activating panel instead of a modal alert |
| 3.1 | Split `AppState` | Done: side-effect-free `init` + `start()`, `PermissionMonitor`, `AutomationService`, `AppModeStore` extracted. The frontmost-app observer stays inside `AppState` |
| 3.2 | Concurrency | Done: `@MainActor` on state/tap/delegate, Swift 6 language mode, strict concurrency clean. `InputProcessor` is not isolated (it is only driven from the main thread) |
| 3.3 | `InputProcessor` | Done: accessors removed, `Replacement`, `Set` of boundary keys |
| 3.4 | Engine | Done: generated case variants, `EngineConfig`, shared Telex/VNI helpers, lowerCamel `TaskKey` / `TypingMethods`. Vietnamese-named engine constants keep their names on purpose |
| 3.5 | Platform | Done: `KeyEventPoster` instance, `VirtualKey`, `os.Logger`, redundant prefixes removed. Not done: bundled JSON defaults (the Apps tab covers overrides) |
| 3.6 | Hygiene | Done: dead code removed, `.swift-format`, docs fixed, `AGENTS.md` symlink, `xcuserdata` untracked |
| 4.1 | Tests | Done: split by area, generated round-trip corpus (~9k syllables × Telex/VNI × tone order), English recovery list, AppState / automation / per-app tests, UI test stub replaced by a launch test |
| 4.2 | Build & CI | Done: format phase portable, GitHub Actions. Not done: extracting a `CaffeeEngine` package, App Intents |

Bugs the new corpus test found and fixed: the validator rejected the rime `eng` (xẻng, kẻng) and `uâng` (khuâng), and typing `o` after `oe` produced `ôe` instead of `oeo` (ngoèo, khoèo).

---

## 0. TL;DR — Top 10

| # | Pri | Area | Issue | Where |
|---|-----|------|-------|-------|
| 1 | P0 | Reliability | `stepByStep` / `hybrid` replacements are sent **asynchronously** while subsequent real keystrokes pass through immediately → characters can interleave in Terminal / Office when typing fast. | `EventSimulator.swift:149-165`, `:221-244` |
| 2 | P0 | Reliability | Keyboard mapping is hard-coded US QWERTY by key code → Dvorak/Colemak/AZERTY/QWERTZ users get wrong letters/tone keys. Numpad digits are not mapped (VNI). | `KeyLayout/KeyboardUS.swift` |
| 3 | P0 | Reliability | The `/tmp/caffee_switch` toggle only works on the first write when the file is overwritten (`echo vi > …`); later writes read empty data and **always disable** Vietnamese. File monitor is only kept alive by an accidental retain cycle. | `AppState.swift:103-112`, `FileMonitor.swift:33-60` |
| 4 | P0 | Reliability | Event-tap callback returns `Unmanaged.passRetained(event)` for the event it was given → over-retains every keystroke/click (memory leak over a long session). | `EventHook.swift:148-174`, `InputProcessor.swift:281` |
| 5 | P1 | Reliability | Accessibility (AX) calls run synchronously inside the event-tap callback with no messaging timeout; a hung target app can stall the tap → macOS disables it. | `Focused.swift`, `SelectionDetector.swift` |
| 6 | P1 | Reliability | Synthetic-event filtering uses "hardware only" (`eventSourceStateID == 1`) → on-screen keyboard, remappers, remote-desktop and automation input are ignored. Tag our own events instead. | `EventHook.swift:151-154` |
| 7 | P1 | Reliability | Keys that move the caret or cancel (Escape, Page Up/Down, Forward Delete, F-keys, unmapped keys) don't reset the word buffer → the next keystroke can rewrite the wrong text. | `InputProcessor.swift:303-320` |
| 8 | P1 | UX | Per-app Vietnamese/English memory is lost on every relaunch; no per-app exclude list / per-app compatibility override. | `AppState.swift:46` |
| 9 | P1 | Design | `AppState` is a god object with side effects in `init` (global hotkey, workspace observer, mutating global statics). Previews/onboarding instantiate extra copies. | `AppState.swift`, `OnboardingView.swift:34` |
| 10 | P1 | Quality | No CI, a 1.2k-line single test file, no dictionary-wide regression test, and a build phase that rewrites sources in place using a hard-coded `/opt/homebrew` path. | `CaffeeTests/`, `project.pbxproj:448` |

---

## 1. Reliability

### 1.1 [P0] Async replacement can interleave with real keystrokes
`EventSimulator.sendReplacement` / `sendSelectAndReplace` dispatch `.stepByStep` and `.hybrid` work to `simulationQueue` and return immediately (`EventSimulator.swift:149-165`, `:221-244`). The tap callback then returns `nil` for the current key, but the **next** physical key is evaluated against the *already-updated* `WordBuffer` and either passes straight through to the app or gets its own async job queued.

Failure: in Terminal/iTerm (step-by-step, ~2 ms per char + 3 ms pauses), typing `tieesng` quickly can deliver `g` to the app before the queued backspaces/characters for `ê`/`ế` → garbled text. Word/Excel (`hybrid`) have the same race with smaller windows.

Fix options (pick one):
- **Serialize everything through one pipeline.** While a simulation job is in flight, swallow incoming real key events (return `nil`) and re-post them from the same serial queue after the job finishes (tagged as our own, see 1.6). This preserves order exactly.
- **Run the tap on its own thread** (dedicated `Thread` + `CFRunLoop`) and do step-by-step synchronously there, with a total budget well under the tap timeout (~1 s). The main thread stays responsive and ordering is guaranteed because the tap processes events sequentially.

Either way, add a unit test with a fake `ReplacementSender` that records "posted" vs "passed through" events in order.

### 1.2 [P0] US-only key-code mapping
`KeyboardUS` maps raw virtual key codes to characters (`KeyboardUS.swift:15-66`). On any non-US layout the engine sees the wrong letter (e.g. Dvorak `o` key is US `s` → user typing `o` gets a sắc tone), and on AZERTY digits require Shift, which breaks VNI.

Fix:
- Read the character the OS would produce: `event.keyboardGetUnicodeString(...)` (cheap, honors the active layout), or translate with `UCKeyTranslate` + `TISCopyCurrentKeyboardLayoutInputSource` and cache per layout (invalidate on `kTISNotifySelectedKeyboardInputSourceChanged`).
- Keep key codes only for *task* keys (Return, Tab, arrows…), which are layout-independent.
- Map numpad digits (key codes 82–92) for VNI users.

### 1.3 [P0] `/tmp/caffee_switch` toggle is broken & fragile
`registerSwitchFileMonitor` (`AppState.swift:103-112`):
- Writes the file with `atomically: true` then opens a `FileHandle` and seeks to end. `FileMonitor.process` reads **from the last offset** (`FileMonitor.swift:55`). After a truncating write (`echo en > /tmp/caffee_switch`) the file is shorter than the stored offset, so `readDataToEndOfFile()` returns empty → `"" != "vi"` → Vietnamese is disabled. From the second overwrite onward it **always disables**. Only appending (`>>`) works.
- The monitor is a local `let` that is never stored; it survives only because `source.setEventHandler { self… }` forms a retain cycle. Any refactor that fixes the cycle silently kills the feature.
- Only `.extend` is watched; `rm`/rename/atomic replacement by the writer detaches the monitor forever.
- `/tmp` is shared and world-writable: another local user can pre-create the file (sticky-bit dir → our atomic write fails → feature silently off) or toggle your IME.

Better: replace with a supported automation surface, in order of preference:
1. **App Intents / Shortcuts** actions ("Set Caffee mode to Vietnamese/English", "Toggle"), usable from Raycast/Alfred/Shortcuts.
2. A **URL scheme** `caffee://mode/vi|en|toggle`.
3. `DistributedNotificationCenter` (for scripts).

If the file approach must stay: put it under `~/Library/Application Support/Caffee/`, store the monitor in a property, read the whole file from offset 0 on each event, and watch `[.write, .extend, .delete, .rename]` (re-open on delete/rename). Document the feature in the Settings window.

### 1.4 [P0] Over-retained events in the tap callback
`handleEvent` returns `Unmanaged.passRetained(event)` for the event passed in (`EventHook.swift:148, 153, 160, 166, 174`; `InputProcessor.swift:281`). The system does not transfer ownership of that event to the callback, so the returned reference should be `passUnretained(event)`. Each keystroke, modifier change and mouse click leaks one retain. Verify with Instruments → Leaks/Allocations (count `CGEvent` over a typing session), then switch to `passUnretained`.

### 1.5 [P1] AX calls inside the tap have no timeout
`Focused.hasHighlightedText()` (called via `AccessibilitySelectionDetector` for browsers on every transformed keystroke) performs two synchronous cross-process AX queries. Default AX messaging timeout is ~6 s; if the browser's renderer is busy, the main thread (which also hosts the tap) blocks → macOS fires `tapDisabledByTimeout` and keys go missing.

Fix:
- `AXUIElementSetMessagingTimeout(systemWide, 0.05)` (and on the focused element).
- Cache the focused element per app activation instead of re-querying `kAXFocusedUIElementAttribute` each time; refresh on `kAXFocusedUIElementChangedNotification` via an `AXObserver`.
- Combined with 1.1, move the tap off the main thread so UI work (SwiftUI menu rendering, NSAlert) can never delay key handling.

### 1.6 [P1] Use event tagging instead of "hardware only" filtering
`EventHook.swift:151-154` drops everything whose `eventSourceStateID != 1`. This is how Caffee avoids re-processing its own synthetic events, but it also ignores the macOS Accessibility Keyboard, some remapping tools, remote-desktop/VNC input and UI-automation tools.

Fix: set a magic value on every event Caffee posts:
```swift
event.setIntegerValueField(.eventSourceUserData, value: CaffeeEventTag)
```
and skip only events carrying that tag. Optionally keep the hardware filter behind a setting.

### 1.7 [P1] Stale word buffer after non-handled keys
`handleTaskKey` (`InputProcessor.swift:303-320`) resets the word only for Enter/Space/Tab, Delete and arrows/Home/End. `Escape` and `F1–F12` are mapped but fall through without `newWord()`. Page Up/Down (116/121), Forward Delete (117), Help/Insert and any unmapped key code return `.passThrough` from `handleInputEvent` with the buffer intact.

Failure: type `vie`, press Page Down (caret moves elsewhere), type `e` → Caffee sends backspaces + `iê` into the new location.

Fix: invert the default — **any key that is not a recognized text char or Delete resets the word**. Also reset on `otherMouseDown` and on focused-element change (AX observer from 1.5).

### 1.8 [P1] Event tap creation failure is silent
`setupEventTap` just `print`s on failure (`EventHook.swift:84-87`). The menu icon still shows "V", but nothing works. Same if Accessibility is revoked while running: `tapIsEnabled` recovery keeps re-enabling an invalid tap.

Fix: expose a `tapHealth` state on `AppState` (`.ok`, `.failedToCreate`, `.permissionRevoked`), show it in the menu bar icon + a menu item "Bộ gõ không hoạt động — Thử lại / Mở hướng dẫn", and check `AXIsProcessTrusted()` inside the existing 0.5 s timer.

### 1.9 [P1] "Auto-switch strategy" heuristic doesn't detect real failures
`TransformationTracker.detectFailure` (`AppCompatibilityPolicy.swift:155-164`) counts consecutive *handled* keystrokes with the **same character** and flips the app to step-by-step after 3. It never observes whether the app actually received the right text, so it (a) rarely triggers and (b) when it does, it's on legitimate input (e.g. VNI `a111…`, held keys). The result is a silent, sticky downgrade to the slowest strategy until the user switches apps.

Fix: either remove it, or implement real verification for AX-capable apps (read `kAXValueAttribute` around the caret after the replacement and compare with `transformed`). Replace the heuristic with a user-visible **per-app compatibility override** (see 2.3).

### 1.10 [P2] Smaller reliability items
- `sendString` puts the whole diff in one event (`EventSimulator.swift:92`). `keyboardSetUnicodeString` is honored only up to ~20 UTF-16 units by many apps; chunk at 20.
- `sendStringStepByStep` uses only the first unicode scalar of each `Character` and truncates to `UniChar` (`:114-115`). Fine for precomposed Vietnamese, wrong for combining sequences/emoji; iterate `utf16` instead.
- `NSPasteboard.general.changeCount` is queried on every keystroke (`InputProcessor.swift:275`) — it's an IPC round-trip. Checking on `Cmd+V` (already a bypass modifier) plus mouse-down is enough.
- `TiengViet.PhuAmDau` / `PhuAmDauTrie` are global `static var`s mutated from `AppState.allowedZWJF.didSet` (`TiengViet.swift:208, 272`). Parallel tests or a future off-main tap would race. Pass an immutable `EngineConfig` into the engine instead (see 3.4).
- `KeyboardShortcuts.onKeyUp { [self] … }` strongly captures `AppState` (`AppState.swift:72`); harmless today because it's a singleton, but previews and `OnboardingViewModel` create extra instances that register extra handlers/observers.
- Duplicate trust-polling timers: `AppDelegate` (2 s), `OnboardingViewModel` (1 s), `UpgradeAppView` (1 s). Consolidate into one `PermissionMonitor` that publishes `isTrusted`.

---

## 2. UX

### 2.1 Menu bar
Current menu (`CaffeeApp.swift:33-85`):
- `Tắt / Mở` doesn't say the current state. Use a `Toggle("Gõ tiếng Việt", isOn:)` (renders a checkmark) and show the hotkey next to it (`⌥Z` by default).
- `[✔] Kiểu Telex` / `Kiểu VNI` hand-draw checkmarks. Use `Picker("Kiểu gõ", selection:)` with `.pickerStyle(.inline)` — native checkmarks and accessible.
- Mixed languages: `Check for Updates...` is English amid Vietnamese labels. Pick one language (or localize properly with a String Catalog — see 2.6).
- Add a line showing the current app and its remembered mode, with "Luôn tắt trong <App>" action (see 2.3).
- Add `accessibilityLabel` for the normal V/E icons, not just the Secure Input one (`CaffeeApp.swift:104-118`).
- Optional: "VI"/"EN" text icon style setting; many users read text faster than SF Symbol letters.

### 2.2 Feedback when mode changes
Toggling with the hotkey or auto-switching on app change is invisible except for a tiny icon. Add an optional, brief on-screen HUD ("V" / "E", ~0.6 s, near the caret or screen center). This is the single most requested affordance in Vietnamese IMEs.

### 2.3 Per-app behavior
- **Persist** `appModes` with `Defaults` (`AppState.swift:46`) so remembered modes survive relaunch/updates.
- Add a Settings tab "Ứng dụng": list of apps with **Mode** (Remember / Always VI / Always EN) and **Compatibility** (Auto / Fast / Step-by-step / Select-and-replace). This replaces the hard-coded `sendingConfigs` / `autocompleteBundlePrefixes` as the user-overridable layer, and fixes Electron/JetBrains/web-app issues without a release.
- Ship sane defaults: Terminal-class apps, password managers and games default to EN.

### 2.4 Typing options users expect
- **Tone placement style**: old (`hòa`, `thủy`, `khỏe`) vs new (`hoà`, `thuỷ`, `khoẻ`). Currently fixed to old style (`TiengVietTransformer.swift:144-155`); add a setting and tests for `oa/oe/uy`.
- **Telex `w` → `ư`** at syllable start / standalone (`w` → `ư`, `[`→`ơ`, `]`→`ư` optional) as in UniKey.
- **Spelling check on/off**: the recovery mechanism is great for mixed English; expose a toggle for people who want marks applied even to non-dictionary syllables.
- **Macros / text expansion**: `MacroView.swift` is fully commented out. Either ship it (it fits the engine: expand on word boundary) or delete the stub.
- Rename "Phụ âm z,w,j,f" (`SettingView.swift:46`) to something self-explanatory, e.g. "Cho phép phụ âm ngoại lai (z, w, j, f)" with a `.help()` tooltip and example.

### 2.5 Settings window
- Fixed `270×390` frame with `Grid` + empty-label toggles (`SettingView.swift:22-73`). Use `Form { … }.formStyle(.grouped)` with labeled `Toggle`s — better VoiceOver labels, scales with Dynamic Type/longer strings, standard macOS look.
- Split into tabs: Chung · Kiểu gõ · Ứng dụng · Nâng cao (automation, diagnostics) · Giới thiệu.
- Remove commented-out OpenAI token row (`SettingView.swift:59-62`) and the unused `Defaults.Keys.token` (`Setting.swift:36`).
- Add "Xuất nhật ký chẩn đoán" (export diagnostics: version, macOS, layout, active strategy per app, recent tap-recovery count) to speed up bug reports.

### 2.6 Onboarding & upgrade flows
- `OnboardingViewModel.completeOnboarding` **relaunches the app** (`OnboardingView.swift:63-82`) even though `AppDelegate` already polls trust and calls `setupTrustedSession()` (`AppDelegate.swift:64-72`). Relaunching is unnecessary friction and risks a double setup while onboarding is open. Make onboarding finish in-place.
- `UpgradeAppView` asks users to toggle Accessibility off/on after each update. The app is Developer-ID signed with a stable team (`project.pbxproj:681-687`), so TCC grants should normally survive updates. Investigate (`codesign -d -r- Caffee.app` across two releases; check whether the designated requirement changes) — if this flow can be shown only when `AXIsProcessTrusted()` is actually false *after* a short retry, most users never see it.
- `GuideView` (old onboarding, "bấm để tắt App rồi mở lại") is only referenced by its own preview → delete it and `WindowController`.
- Deduplicate `relaunchApp()` / `openAccessibilitySettings()` (copied in `OnboardingView.swift` and `UpgradeAppView.swift`).
- Localization: all strings are inline Vietnamese literals. Move them into a String Catalog (`Localizable.xcstrings`) — even if Vietnamese is the only language, it centralizes copy and makes an English UI trivial for non-native users on Vietnamese teams.

### 2.7 Secure Input
The recent Secure Input work (icon + explanation alert) is good. Two additions:
- Show **which app** holds Secure Input when possible (`ioreg -l -w 0 | grep SecureInput` exposes `kCGSSessionSecureInputPID`; read it via `CGSessionCopyCurrentDictionary()`), so the alert can say "Đóng ô mật khẩu trong **1Password**".
- Don't steal focus with `NSApp.activate(ignoringOtherApps:)` + modal alert; a popover from the menu or a non-modal panel is less disruptive.

---

## 3. Code design

### 3.1 Split `AppState` responsibilities
Today `AppState` (`AppState.swift`) owns UI state, the event hook, the input processor, global hotkey registration, NSWorkspace observation, file monitoring, *and* mutates engine globals. Its `init` performs side effects, so `GeneralView_Previews`, `UpgradeAppView_Previews`, etc. register real global hotkeys/observers.

Suggested shape:
```
AppState (@Observable, @MainActor)      // pure UI-facing state: enabled, method, options, health
 └─ TypingSession                       // owns InputProcessor + EventHook, applies config
 └─ AppModeStore                        // per-app memory, persisted
 └─ ActiveAppObserver                   // NSWorkspace → publishes bundleId
 └─ PermissionMonitor                   // single trust/secure-input source of truth
 └─ AutomationService                   // App Intents / URL scheme / (legacy) file switch
AppDelegate                             // composes the above once; no duplicated setup
```
- Make `init` side-effect free; start services in an explicit `start()`.
- Inject protocols so previews use a stub (`AppState.preview`).
- Remove the empty `load()` (`AppState.swift:82-84`) and the duplicated setup block in `AppDelegate` (`:48-55` vs `:79-85`).

### 3.2 Concurrency annotations
Adopt `@MainActor` on `AppState`, `AppDelegate`, view models; make `InputProcessor`/`WordBuffer` confined to the tap thread (an actor-like "TypingSession" with a dedicated executor or a serial queue). Then move to Swift 6 language mode (currently `SWIFT_VERSION = 5.10`) and turn on strict concurrency checking — it will flag today's cross-thread touches of `AppState.secureInputActive` and the global tries.

### 3.3 `InputProcessor`
- The "convenience accessors (preserve existing API for tests)" (`InputProcessor.swift:193-223`) expose all of `WordBuffer`'s internals publicly. Tests should drive behavior through `handleInputEvent` and assert on recorded output; then delete these pass-throughs.
- `pop()` returns `(Int, [Character])`; introduce `struct Replacement { let deleteCount: Int; let insert: String }` (also used by `EventSimulator.calcKeyStrokes`) for clarity.
- Word-boundary character set (`NewWordKeys`) is a string literal searched per keystroke — use a `Set<Character>`.

### 3.4 Engine
The engine split (State / Parser / Transformer / Validator) is clean and pure — keep it. Improvements:
- **Case variants are enumerated by hand** (`TiengViet.swift:193-265`: 8 spellings of every triphthong). Lowercase the input for trie lookup and map the match length back onto the original characters. Removes ~150 lines and the risk of a missing variant.
- **Global mutable config** (`static var PhuAmDau`, `PhuAmDauTrie`) → `struct EngineConfig { allowForeignConsonants, toneStyle, … }` passed to `Telex`/`VNI` at construction; tries cached per config.
- `Telex` and `VNI` duplicate `rawResult`/`markResult` verbatim (`Telex.swift:116-142`, `VNI.swift:108-134`). Move them to a protocol extension or a shared base; each method then only supplies a key→action table plus its `shouldToggleToRaw` rules.
- Make `Telex`/`VNI` `struct`s (stateless) and the `TypingMethod` protocol `Sendable`.
- `QuyTacDatDau` / `QuyTacDatMu` are arrays of tuples searched linearly per character; use `[Character: Character]` dictionaries.
- Naming: `TypingMethods.Telex`, `TaskKey.Enter` etc. use UpperCamelCase cases; Swift convention is `lowerCamelCase`. Pick one domain language for identifiers per layer (Vietnamese in the engine is fine and readable; keep App/Platform layers English).

### 3.5 Platform layer
- `EventSimulator` is a bag of `static` funcs with a shared static queue; turn it into an instance (`KeyEventPoster`) owning its `CGEventSource` and queue, conforming to `ReplacementSender`. Then `EventSimulatorReplacementSender` (a pure forwarding wrapper) disappears.
- Centralize virtual key codes (`0x33`, `0x7B`, …) in `Keys.swift` instead of magic numbers.
- Replace `print` / `#if DEBUG print` with `os.Logger(subsystem: "com.khanhicetea.Caffee", category: …)`; logs then show in Console.app and can be included in diagnostics export (2.5).
- `AppCompatibilityPolicy`: prefix lists contain redundant entries (`com.google.Chrome` already covers `.canary`/`.beta`; `com.microsoft.edge` covers `edgemac*`). Move the defaults into a bundled JSON/plist, merged with user overrides from 2.3.

### 3.6 Dead code & repo hygiene
- `ContentView.swift` — not in the target and calls a non-existent `transform_text`; delete.
- `MacroView.swift` — 100% commented out; delete or implement.
- `GuideView.swift` + `WindowController` — unused (see 2.6).
- Mixed indentation (2 spaces in most files, 4 in `AppState.swift`, `SettingView.swift`, `OnboardingView.swift`) despite the format build phase → add a committed `.swift-format` config and run it once.
- `CLAUDE.md` / `AGENTS.md` say macOS 13+ and "Combine publishers"; the project targets **macOS 14.0** and uses `@Observable`. Update the docs; make `AGENTS.md` a symlink to `CLAUDE.md` to avoid drift.
- Commit hygiene: `UserInterfaceState.xcuserstate` shows as modified — make sure `xcuserdata/` is in `.gitignore` and untracked (`git rm --cached`).

---

## 4. Testing & tooling

### 4.1 Tests
Current state: one 1,237-line `CaffeeTests.swift` (108 tests, good engine coverage), UI tests are the Xcode template stubs.

Recommendations:
- **Split by area**: `TelexTests`, `VNITests`, `ParserTests`, `ValidatorTests`, `InputProcessorTests`, `SecureInputTests`, `CompatibilityPolicyTests`.
- **Dictionary round-trip test (biggest win)**: bundle a Vietnamese syllable list (~6–7k syllables). For each syllable, generate its Telex and VNI keystroke sequences (including free-order variants like `tieengs` vs `tiesng`), feed them through `InputProcessor` with a recording sender, and assert the reconstructed text equals the syllable. This catches regressions in `gi`/`qu`/`uơ`/tone-placement instantly.
- **English-recovery corpus**: a list of common English/code words (`class`, `boss`, `window`, `file`, `json`, `const`) must come out unchanged.
- **Ordering tests** for 1.1 (fake sender that records interleaving of posted vs passed-through keys).
- Tests for the stale-buffer cases in 1.7 and the per-app persistence in 2.3.
- Delete or replace the template UI tests; a launch smoke test is fine, `testExample` is noise.

### 4.2 Build & CI
- The "format" build phase runs `/opt/homebrew/bin/swift-format -i -r .` on **every build** (`project.pbxproj:448`): it rewrites sources during compilation, fails silently on Intel Macs/CI (different brew prefix), and slows builds. Move it to a pre-commit hook or a `make format` target; in CI run `swift-format lint --strict`.
- Add GitHub Actions: `xcodebuild test -scheme Caffee -destination 'platform=macOS'` on PRs, plus lint.
- Consider moving the engine (`Engine/` + `KeyLayout/`) into a local Swift package (`CaffeeEngine`). Tests then run with `swift test` in seconds, without the app host or Accessibility permission, and the boundary enforces that the engine never imports AppKit.

---

## 5. Suggested roadmap

**Release N+1 — "nothing gets garbled" (P0s)**
1. `passUnretained` in tap callback (1.4).
2. Reset word buffer on all non-text keys (1.7).
3. Fix/replace `/tmp/caffee_switch` (1.3) — at minimum read-from-0 + retained monitor + Application Support path.
4. Serialize async replacements with incoming keys (1.1).
5. Layout-aware character mapping + numpad (1.2).

**Release N+2 — "it tells me what's wrong"**
6. Tap health state & menu feedback (1.8); AX timeout (1.5); event tagging (1.6).
7. Menu cleanup (Toggle/Picker, consistent language) (2.1); persist per-app modes (2.3).
8. `os.Logger` + diagnostics export.

**Release N+3 — "it fits my workflow"**
9. Per-app settings tab with compatibility overrides; remove the auto-switch heuristic (1.9, 2.3).
10. Tone style option, `w`→`ư`, HUD (2.2, 2.4).
11. App Intents / URL scheme automation (1.3).

**Ongoing — code health**
12. Split `AppState`; `@MainActor`; Swift 6 (3.1, 3.2).
13. Engine config struct, case-insensitive tries, shared Telex/VNI helpers (3.4).
14. Extract `CaffeeEngine` package, dictionary round-trip tests, CI (4.x).
15. Delete dead code, fix docs, unify formatting (3.6).

---

## 6. Things that are already good (keep them)

- Pure, immutable engine pipeline (`TiengVietState` → Parser → Validator/Transformer) with cached parse results — easy to test and reason about.
- Recovery to raw input for non-Vietnamese syllables, and single-step rollback on Backspace (`WordBuffer.pop`) — excellent for mixed English typing.
- Backspace across a word boundary restores the previous word's state (`previousWordState`).
- Protocol seams already exist (`ReplacementSender`, `SelectionDetector`, `AppCompatibilityPolicy`, `KeyboardLayout`) and are used in tests.
- Secure Input handling: polled on a timer in common modes, re-sampled per event, never reuses a word across protected fields.
- Browser inline-autocomplete handling via Shift+Left only when a selection actually exists (avoids the Google Docs canvas trap).
- Sparkle with EdDSA-signed appcast and hardened runtime.
