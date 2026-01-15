# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Caffee is a macOS Vietnamese Input Method Editor (IME) - a native keyboard input system for typing Vietnamese with diacritical marks. It supports Telex and VNI input methods with app-specific input mode memory.

**Target**: macOS 13+ Ventura
**Language**: Swift
**Frameworks**: AppKit, SwiftUI

## Build Commands

```bash
# Build
xcodebuild build -scheme Caffee

# Run tests
xcodebuild test -scheme Caffee

# Code formatting (swift-format must be installed)
brew install swift-format
# Formatting runs automatically as a build phase
```

## Architecture

### Data Flow
```
Keyboard Event → EventHook (CGEvent tap) → InputProcessor
    → Engine (Telex/VNI) → TiengViet.transform() → EventSimulator
```

### Key Components

**App/** - Application lifecycle and state
- `AppState.swift` - Observable state container with Combine publishers for enabled state, typing method, and per-app input mode memory
- `InputProcessor.swift` - Main keyboard event handler that maintains word state and delegates to the typing engine
- `Setting.swift` - Persistent settings using Defaults framework

**Engine/** - Vietnamese typing logic
- `TiengViet.swift` - Core Vietnamese syllable model with tone marks (DauThanh) and diacritics (DauMu). Handles consonant clusters, vowels, and text transformation
- `Telex.swift` / `VNI.swift` - Input method implementations following TypingMethod protocol

**Platform/** - macOS system interaction
- `EventHook.swift` - Global CGEvent tap for keyboard interception (requires Accessibility permission)
- `EventSimulator.swift` - Simulates backspace and text input to replace typed text
- `Focused.swift` - Accessibility API to detect focused elements

**KeyLayout/** - Keyboard mapping
- `KeyboardUS.swift` - US keyboard layout key code to character mapping
- `Keys.swift` - TaskKey enum for special keys (Enter, Tab, Space, arrows)

### Dependencies (Swift Packages)
- **Defaults** - UserDefaults wrapper
- **KeyboardShortcuts** - Shortcut recording/binding
- **LaunchAtLogin** - Auto-start functionality
- **Settings** - SwiftUI preferences window

## Vietnamese Linguistics Reference

**Telex keys**: s=sắc, f=huyền, r=hỏi, x=ngã, j=nặng, aa=â, oo=ô, ee=ê, aw=ă, ow=ơ, uw=ư, dd=đ

**VNI keys**: 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng, 6=circumflex, 7=horn, 8=breve, 9=đ
