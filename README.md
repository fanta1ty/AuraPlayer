# AuraPlayer

A dark, audiophile iOS music player built in SwiftUI. Near-black surfaces, minimal chrome, and a single glowing electric-cyan accent that keeps the music front and center.

## Tech

- **Language:** Swift + SwiftUI
- **Architecture:** MVVM
- **Minimum target:** iOS 26+
- **Audio:** AVAudioEngine, Accelerate (vDSP) for FFT/spectrum
- **Charts:** Swift Charts

## Design

Visual identity is a **dark audiophile** aesthetic (reference: Doppler), dark mode only for v1, with a cyan glow as the signature effect. Full color tokens and rationale live in `DESIGN_NOTES.md` (local, not committed). The design system code lives under `AuraPlayer/AuraPlayer/DesignSystem/`.

## Project structure

```
AuraPlayer/AuraPlayer/
├── Models/          # Data types
├── ViewModels/      # MVVM logic layer (unit-tested)
├── Views/           # SwiftUI screens & components
├── Services/        # Audio engine, queue, EQ, downloads
├── DesignSystem/    # Colors, fonts, spacing, reusable components
└── Resources/       # Assets and supporting files
```

## Testing

- **Unit tests** (`AuraPlayerTests`) — Swift Testing framework, focused on ViewModels and Services (queue logic, EQ/FFT math).
- **UI tests** (`AuraPlayerUITests`) — XCUITest for a few critical end-to-end flows.
- Manual per-task checklists in the build guide cover audio/hardware behavior that can't be unit-tested.

## Building

1. Open `AuraPlayer/AuraPlayer.xcodeproj` in Xcode.
2. Select an iOS 26 simulator (or a device).
3. Build & run (⌘R).

## Roadmap

Development is organized into phases: Design System → Project Setup → Audio Engine → Player UI → Music Library → Lock Screen → EQ → Visualizer → File Import → Downloads → Spectrum → Waveform → Advanced DSP → Lyrics → AI Features → Polish & Release.
