# Caffee Architecture Deep Dive

This document provides a comprehensive technical analysis of how Caffee, the macOS Vietnamese Input Method Editor (IME), processes keyboard input and transforms it into Vietnamese text with diacritical marks.

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Platform Layer](#platform-layer)
3. [Engine Layer](#engine-layer)
4. [Data Flow](#data-flow)
5. [Key Algorithms](#key-algorithms)
6. [Performance Optimizations](#performance-optimizations)

---

## High-Level Architecture

Caffee follows a layered architecture that separates platform-specific macOS integrations from the Vietnamese language processing engine:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INPUT                                      │
│                           (Physical Keyboard)                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PLATFORM LAYER                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │   EventHook     │  │ EventSimulator  │  │       Focused               │  │
│  │ (CGEvent tap)   │  │ (Key injection) │  │ (Accessibility API)         │  │
│  └────────┬────────┘  └────────▲────────┘  └──────────────▲──────────────┘  │
└───────────┼────────────────────┼──────────────────────────┼─────────────────┘
            │                    │                          │
            ▼                    │                          │
┌─────────────────────────────────────────────────────────────────────────────┐
│                           APPLICATION LAYER                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        InputProcessor                                   │ │
│  │  - Maintains word state (TiengVietState)                               │ │
│  │  - Delegates to typing engine (Telex/VNI)                              │ │
│  │  - Calculates diff and triggers text replacement                       │ │
│  └────────────────────────────────┬───────────────────────────────────────┘ │
└───────────────────────────────────┼─────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             ENGINE LAYER                                     │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        TypingMethod Protocol                           │  │
│  │            ┌────────────────┐    ┌────────────────┐                   │  │
│  │            │     Telex      │    │      VNI       │                   │  │
│  │            │  (s=sắc, w=ư)  │    │  (1=sắc, 7=ư)  │                   │  │
│  │            └───────┬────────┘    └───────┬────────┘                   │  │
│  └────────────────────┼─────────────────────┼────────────────────────────┘  │
│                       │                     │                                │
│                       └──────────┬──────────┘                                │
│                                  ▼                                           │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                       TiengVietState (Immutable)                        │ │
│  │   - chuKhongDau: [Character]  (raw input without diacritics)           │ │
│  │   - dauThanh: DauThanh        (tone mark: sắc, huyền, hỏi, ngã, nặng) │ │
│  │   - dauMu: DauMu              (diacritical: mũ, móc, trăng)           │ │
│  │   - gachD: Bool               (đ stroke)                               │ │
│  └─────────────────────────────────┬──────────────────────────────────────┘ │
│                                    │                                         │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                      TiengVietParser (Pure)                             │ │
│  │   Parses: [Character] → ThanhPhanTieng                                 │ │
│  │   - phuAmDau: Initial consonant cluster (kh, ng, ngh, tr...)          │ │
│  │   - nguyenAm: Vowel cluster (a, oa, uoi, ươi...)                      │ │
│  │   - phuAmCuoi: Final consonant (c, ch, m, n, ng, nh, p, t)            │ │
│  │   - conLai: Remainder (invalid characters)                            │ │
│  └─────────────────────────────────┬──────────────────────────────────────┘ │
│                                    │                                         │
│              ┌─────────────────────┴─────────────────────┐                   │
│              ▼                                           ▼                   │
│  ┌────────────────────────┐               ┌────────────────────────┐        │
│  │  TiengVietValidator    │               │  TiengVietTransformer  │        │
│  │  - needsRecovery()     │               │  - transform()         │        │
│  │  - Vowel+ending rules  │               │  - Apply diacritics    │        │
│  └────────────────────────┘               └────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Platform Layer

The Platform layer handles all macOS-specific system interactions.

### EventHook.swift

**Purpose**: Intercepts keyboard events at the system level using CGEvent taps.

**Key Mechanisms**:

```swift
// Creates a session-level event tap to intercept keyboard and mouse events
CGEvent.tapCreate(
    tap: .cgSessionEventTap,      // Session-wide interception
    place: .headInsertEventTap,    // Insert at head of event queue
    options: .defaultTap,          // Active tap (can modify/consume events)
    eventsOfInterest: eventMask,   // keyDown, flagsChanged, mouse clicks
    callback: eventTapCallback,
    userInfo: Unmanaged.passUnretained(self).toOpaque()
)
```

**Event Processing Flow**:

1. **Filter non-hardware events**: Only process events from HID system (stateID == 1)
2. **Secure input detection**: Uses private API `CGSIsSecureEventInputSet()` to skip password fields
3. **Delegate to InputProcessor**: For keyDown events when processing is enabled
4. **Mouse click handling**: Clears word buffer on mouse clicks (user may have moved cursor)

```swift
// Security check - skip IME in password fields
if CGSIsSecureEventInputSet() {
    return Unmanaged.passRetained(event)  // Pass through unchanged
}
```

### EventSimulator.swift

**Purpose**: Simulates keyboard input to replace typed text with Vietnamese characters.

**Core Algorithm - calcKeyStrokes**:

```swift
static func calcKeyStrokes(from prevStr: String, to currentStr: String) -> (Int, [Character])
```

This is a diff algorithm that determines:
1. **Number of backspaces** needed to delete the changed portion
2. **Characters to type** to complete the transformation

**Example**:
```
prevStr:    "toi"
currentStr: "tối"  (after pressing 's' for sắc tone)

Common prefix: "t" (length 1)
Backspaces needed: 2 (delete "oi")
Characters to type: ['ố', 'i']
```

**Backspace Delay Handling**:

Some apps (Electron-based, browsers) coalesce rapid keyboard events, causing dropped backspaces:

```swift
// Delay between backspaces for problematic apps
static func sendBackspace(_ count: Int, delayMicroseconds: UInt32 = 0) {
    for i in 1...count {
        backspaceKeyDown.post(tap: .cgSessionEventTap)
        backspaceKeyUp.post(tap: .cgSessionEventTap)
        if delayMicroseconds > 0 && i < count {
            usleep(delayMicroseconds)  // e.g., 1500μs for VS Code
        }
    }
}
```

### Focused.swift

**Purpose**: Queries focused UI elements using macOS Accessibility APIs.

**Key Functions**:
- `element()`: Returns the currently focused AXUIElement
- `hasHighlightedText()`: Detects text selection (for autocomplete fix)
- `highlightedText()`: Gets the selected text content

**Autocomplete Fix**: Some apps (Safari, Chrome) auto-select suggested text. When replacing text, an extra backspace is needed to clear the selection first.

### FileMonitor.swift

**Purpose**: Watches files for changes using GCD dispatch sources.

Uses `DispatchSource.makeFileSystemObjectSource` with `.extend` event mask to monitor file appends. Currently used for development/debugging purposes.

---

## Engine Layer

The Engine layer contains all Vietnamese language processing logic.

### TiengViet.swift - Data Types and Constants

**Tone Marks (DauThanh)**:
```swift
enum DauThanh: UInt8 {
    case bang = 0    // No tone (ma)
    case sac = 2     // Acute accent (má)
    case huyen = 4   // Grave accent (mà)
    case hoi = 8     // Hook above (mả)
    case nga = 16    // Tilde (mã)
    case nang = 32   // Dot below (mạ)
}
```

**Diacritical Marks (DauMu)**:
```swift
enum DauMu: UInt8 {
    case khongMu = 0  // No diacritical
    case muUp = 2     // Circumflex: a→â, e→ê, o→ô
    case muMoc = 4    // Horn: u→ư, o→ơ
    case muNgua = 8   // Breve: a→ă
}
```

**Syllable Components (ThanhPhanTieng)**:
```swift
struct ThanhPhanTieng {
    var phuAmDau: [Character]    // Initial consonants: ngh, tr, kh...
    var nguyenAm: [Character]    // Vowels: a, oa, uoi, ươi...
    var phuAmCuoi: [Character]   // Final consonants: c, ch, ng, nh...
    var conLai: [Character]      // Invalid remainder
    var viTriDauMu = -1          // Diacritical position
    var viTriDauThanh = -1       // Tone mark position
    var chuaNguyenAmUO = false   // Special "uo" handling flag
}
```

### TiengVietState.swift - Immutable State Container

**Design Pattern**: Immutable state with mutation methods that return new instances.

```swift
struct TiengVietState {
    let chuKhongDau: [Character]  // Raw input
    let dauThanh: DauThanh        // Current tone
    let dauMu: DauMu              // Current diacritical
    let gachD: Bool               // đ stroke flag
    private let _cachedThanhPhan: ThanhPhanTieng?  // Cached parse result
    
    // Mutation returns new state
    func push(_ letter: Character) -> TiengVietState {
        let newChuKhongDau = chuKhongDau + [letter]
        return TiengVietState(
            chuKhongDau: newChuKhongDau,
            dauThanh: dauThanh,
            dauMu: dauMu,
            gachD: gachD,
            cachedThanhPhan: TiengVietParser.parse(newChuKhongDau)
        )
    }
}
```

**Toggle Behavior**: Pressing the same tone/diacritical key twice removes it:
```swift
func withTone(_ tone: DauThanh) -> TiengVietState {
    TiengVietState(
        // ... other fields
        dauThanh: dauThanh == tone ? .bang : tone,  // Toggle off if same
    )
}
```

### TiengVietParser.swift - Syllable Parser

**Pure Function**: No side effects, deterministic output.

**Parsing Algorithm**:
1. Match initial consonant cluster (longest match first)
2. Match vowel cluster (longest match first)
3. Match final consonant
4. Remainder goes to `conLai`

**Special Case - "gi"**:
```swift
// "gi" handling:
// - "gia", "giết" → "gi" is initial consonant, continue parsing vowel
// - "gi" alone → "g" is consonant, "i" is vowel
if matched.lowercased() == "gi" {
    let afterGi = String(remaining.dropFirst(2))
    let hasFollowingVowel = TiengViet.NguyenAm.contains { vowel in
        afterGi.lowercased().hasPrefix(vowel.lowercased())
    }
    if hasFollowingVowel {
        result.phuAmDau = Array(matched)  // "gi" as consonant
    } else {
        result.phuAmDau = [matched.first!]  // "g" as consonant
        result.nguyenAm = [matched.last!]   // "i" as vowel
    }
}
```

### TiengVietTransformer.swift - Character Transformation

**Transformation Order**:
1. Apply đ stroke (d → đ)
2. Apply diacritical mark (mũ/móc/trăng)
3. Apply tone mark

**Diacritical Placement Rules**:
```
Rule 1: "uo" + horn → "ươ" (both vowels get diacritical)
Rule 2: 3 vowels OR 2 vowels + final consonant → place on 2nd vowel
Rule 3: Otherwise → place on first applicable vowel

Examples:
- "tuoi" + horn → "tươi" (both u and o get horn)
- "toai" + tone → "toái" (tone on 2nd vowel 'a')
- "toi" + tone → "tói" (tone on 1st vowel 'o')
```

### TiengVietValidator.swift - Syllable Validation

**Purpose**: Detect invalid Vietnamese syllables and trigger recovery to original input.

**Validation Rules**:
1. **Remainder check**: If `conLai` is non-empty, syllable is invalid
2. **Invalid vowel combinations**: `ae`, `ea`, `ey`, `iy`, `oe`, `uu`, `yi`, `yo`, `yu`
3. **Vowel + final consonant compatibility**:

```swift
static let ValidVowelEndings: [String: Set<String>] = [
    "a": ["c", "ch", "m", "n", "ng", "nh", "p", "t"],
    "ai": [],  // No final consonant allowed
    "ao": [],  // No final consonant allowed
    "uô": ["c", "m", "n", "ng", "p", "t"],
    "ươ": ["c", "m", "n", "ng", "p", "t"],
    // ... more rules
]
```

### Telex.swift & VNI.swift - Input Methods

**TypingMethod Protocol**:
```swift
protocol TypingMethod {
    func shouldStopProcessing(keyStr: String) -> Bool
    func push(char: Character, state: TiengVietState) -> (state: TiengVietState, appliedMark: Bool)
    func pop(state: TiengVietState) -> TiengVietState
}
```

**Telex Key Mappings**:
```
Tone marks:      s=sắc  f=huyền  r=hỏi  x=ngã  j=nặng
Diacriticals:    aa=â   ee=ê     oo=ô   aw=ă   ow=ơ   uw=ư
Special:         dd=đ   w=context-dependent (ơ/ư/ă)
```

**VNI Key Mappings**:
```
Tone marks:      1=sắc  2=huyền  3=hỏi  4=ngã  5=nặng
Diacriticals:    6=mũ(^)  7=móc(horn)  8=trăng(breve)
Special:         9=đ
```

**Stop Processing Detection** (Double-press to cancel):
```swift
// Pre-compiled regex for performance
private static let compiledStoppingRegex: [NSRegularExpression] = {
    let patterns = [
        "ss$", "ff$", "rr$", "xx$", "jj$", "ww$",  // Double tone keys
        "[0-9]$",                                    // Number input
        "a+[a-zA-Z]*aa$",                            // Triple 'a'
        "o+[a-zA-Z]*oo$",                            // Triple 'o'
        // ... more patterns
    ]
    return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
}()
```

---

## Data Flow

### Complete Keystroke Processing Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ User types 'v', 'i', 'e', 't', 's' to produce "việt"                       │
└─────────────────────────────────────────────────────────────────────────────┘

Step 1: 'v' pressed
├── EventHook receives CGEvent
├── InputProcessor.push('v')
├── Telex.push('v', state) → state.push('v')
├── TiengVietState: chuKhongDau=['v'], dauThanh=bang
├── TiengVietParser.parse(['v']) → {phuAmDau:['v'], nguyenAm:[], ...}
├── transformed = "" (no vowel yet)
└── No change, pass event through

Step 2: 'i' pressed
├── InputProcessor.push('i')
├── Telex.push('i', state) → state.push('i')
├── TiengVietState: chuKhongDau=['v','i'], dauThanh=bang
├── Parser: {phuAmDau:['v'], nguyenAm:['i'], ...}
├── transformed = "vi"
└── No change (diff: "" → "vi", but 'i' matches, pass through)

Step 3: 'e' pressed
├── InputProcessor.push('e')
├── Telex.push('e', state) → state.push('e')
├── TiengVietState: chuKhongDau=['v','i','e']
├── Parser: {phuAmDau:['v'], nguyenAm:['i','e'], ...}
├── transformed = "vie"
└── No change needed

Step 4: 't' pressed
├── InputProcessor.push('t')
├── TiengVietState: chuKhongDau=['v','i','e','t']
├── Parser: {phuAmDau:['v'], nguyenAm:['i','e'], phuAmCuoi:['t']}
├── transformed = "viet"
└── No change needed

Step 5: 's' pressed (Telex tone mark)
├── InputProcessor.push('s')
├── Telex.push('s', state) → detects vowel exists
│   └── Returns (state.withTone(.sac), true)
├── TiengVietState: chuKhongDau=['v','i','e','t'], dauThanh=sac
├── TiengVietTransformer.transform():
│   ├── Parse: {nguyenAm:['i','e'], phuAmCuoi:['t']}
│   ├── Tone placement: 2 vowels + final consonant → place on 2nd vowel
│   └── 'e' + sac → 'ế'
├── transformed = "việt"
├── calcKeyStrokes("viet", "việt"):
│   ├── Common prefix: "vi" (length 2)
│   ├── Backspaces: 2 (delete "et")
│   └── Type: ['ệ', 't']... wait, 'ế' not 'ệ'
│       Actually: Backspaces: 2, Type: ['ế', 't']
├── EventSimulator.sendBackspace(2)
├── EventSimulator.sendString("ệt")
└── Return nil (consume original 's' event)
```

---

## Key Algorithms

### 1. Diff-Based Text Replacement

Instead of replacing the entire word on each keystroke, Caffee calculates the minimal diff:

```swift
let (numBackspaces, diffChars) = EventSimulator.calcKeyStrokes(
    from: lastTransformed,  // "viet"
    to: transformed         // "việt"
)
// Result: (2, ['ế', 't'])
// Only delete "et" and type "ệt" - minimal disruption
```

### 2. Cached Parsing

Each `TiengVietState` caches its parsed `ThanhPhanTieng` to avoid redundant parsing:

```swift
private let _cachedThanhPhan: ThanhPhanTieng?

var thanhPhanTieng: ThanhPhanTieng {
    _cachedThanhPhan ?? TiengVietParser.parse(chuKhongDau)
}
```

### 3. Recovery Mode

When input forms an invalid Vietnamese syllable, the engine "recovers" by returning the raw input:

```swift
if wordState.needsRecovery {
    stopProcessing = true
    transformed = String(keys)  // Return raw input, not transformed
}
```

**Example**: Typing "xyz" → validator detects invalid combination → output "xyz" unchanged.

### 4. Previous Word Restoration

On backspace, if the current word is empty, the previous word's state can be restored:

```swift
public func pop() {
    if wordState.isBlank, let prev = previousWordState {
        wordState = prev
        previousWordState = nil
        keys = Array(wordState.chuKhongDau)
        transformed = wordState.transformed
        lastTransformed = transformed
    } else {
        wordState = engine.pop(state: wordState)
        // ...
    }
}
```

---

## Performance Optimizations

### 1. Pre-compiled Regular Expressions

Stop-processing patterns are compiled once at class initialization:

```swift
private static let compiledStoppingRegex: [NSRegularExpression] = {
    let patterns = ["ss$", "ff$", "rr$", ...]
    return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
}()
```

### 2. Longest-Match-First Ordering

Consonant and vowel arrays are ordered by length (longest first) to ensure correct greedy matching:

```swift
static let PhuAmGhep: [String] = [
    "ngh",  // 3 chars - matched before "ng"
    "ng",   // 2 chars - matched before "n"
    "n",    // 1 char
    // ...
]
```

### 3. App-Specific Delay Tables

Instead of a one-size-fits-all approach, backspace delays are tuned per-app:

```swift
static let SlowEventApps: [(prefix: String, delay: UInt32)] = [
    ("com.microsoft.VSCode", 1500),  // Electron - needs most delay
    ("com.google.Chrome", 800),       // Browser - moderate delay
    // Native apps: 0 delay (fastest)
]
```

### 4. Minimal Event Generation

The system only generates replacement events when necessary:

```swift
// If the only difference is the new character itself, let it pass through
if let firstDiffChar = diffChars.first, diffChars.count == 1 && firstDiffChar == newChar {
    return Unmanaged.passRetained(event)  // No replacement needed
}
```

---

## Security Considerations

### Secure Input Mode Detection

Caffee respects macOS secure input mode (password fields):

```swift
@_silgen_name("CGSIsSecureEventInputSet")
func CGSIsSecureEventInputSet() -> Bool

// In event handler:
if isSecureInput {
    return Unmanaged.passRetained(event)  // Pass through, no processing
}
```

### Accessibility Permissions

Caffee requires Accessibility permissions to:
1. Install CGEvent tap for keyboard interception
2. Query focused UI elements for autocomplete detection

```swift
func isTrusted(prompt: Bool = true) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt as CFBoolean]
    return AXIsProcessTrustedWithOptions(options as CFDictionary?)
}
```

---

## Summary

Caffee's architecture demonstrates several key design principles:

1. **Separation of Concerns**: Platform-specific code is isolated from language processing logic
2. **Immutability**: State mutations return new instances, ensuring predictability
3. **Pure Functions**: Parser and transformer are side-effect-free
4. **Minimal Intervention**: Only replace characters that actually changed
5. **Graceful Degradation**: Invalid input falls back to raw text (recovery mode)
6. **Performance-First**: Pre-compiled regex, cached parsing, app-specific tuning
