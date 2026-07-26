# AuraPlayer

A dark, audiophile iOS music player built in SwiftUI. Near-black surfaces, minimal chrome, and a single glowing electric-cyan accent that keeps the music front and center.

Plays your own files — no streaming, no accounts, no ads.

## Features

**Playback**
- Gapless-capable dual-node `AVAudioEngine` graph with **crossfade** between tracks
- Queue with shuffle, repeat (off / one / all), and auto-advance
- **A-B repeat** loop for practising a passage
- Independent **pitch** (±12 semitones) and **speed** (0.5×–2×) control
- **Volume normalization** (ReplayGain-style loudness analysis, cached per file)
- **Sleep timer** with fade-out, or stop at end of track
- Background audio, lock screen controls, and Control Center integration

**Sound**
- **10-band parametric EQ** (32 Hz – 16 kHz) with preamp
- 9 built-in presets plus user-saved custom presets
- Live **frequency response curve** (Bode plot) that follows the sliders
- Real-time **FFT spectrum analyzer** (Accelerate/vDSP) with bars, line, and mirror modes

**Library**
- Browse by songs, albums, artists, and playlists
- Search, sort (A–Z / recently added / duration), and pull-to-refresh
- **Star ratings** and automatic **play counts**
- **Metadata editor** — fix titles, artists, albums, genres, years, and cover art
- Automatic artwork lookup for untagged files
- Track **Info** sheet: format, sample rate, bit depth, bitrate, and file size

**Getting music in**
- Import from the Files app (multi-select)
- iTunes/Finder file sharing
- "Open in AuraPlayer" from Safari, Mail, and other apps
- Built-in **download manager** — paste a URL, downloads continue in the background
- Storage management and download history

**Extras**
- **Synced lyrics** (.lrc) that scroll with playback — tap a line to seek
- Reads embedded lyrics, sidecar files, or fetches from LRCLIB
- Waveform scrubber rendered from the actual audio

## Tech

- **Language:** Swift + SwiftUI
- **Architecture:** MVVM
- **Minimum target:** iOS 26+
- **Audio:** `AVAudioEngine`, `AVAudioUnitEQ`, `AVAudioUnitTimePitch`
- **DSP:** Accelerate (vDSP) for FFT, waveform, and loudness analysis
- **Charts:** Swift Charts
- **Formats:** MP3, M4A/AAC, ALAC, FLAC, WAV, AIFF (DSD files are detected but not yet decoded)

## Design

A **dark audiophile** aesthetic (reference point: Doppler), dark mode only, with a cyan glow as the signature effect. Colour tokens meet WCAG AA contrast on every surface. Design decisions and exact hex values live in `DESIGN_NOTES.md` (local, not committed); the implementation is under `DesignSystem/`.

## Project structure

```
AuraPlayer/AuraPlayer/
├── Models/          # Track, Album, Artist, Playlist, Lyrics, EQPreset…
├── ViewModels/      # Player, Library, Playlists, Stats, Overrides
├── Views/           # Screens and components
├── Services/        # Audio engine, EQ, spectrum, scanner, downloads, lyrics
├── DesignSystem/    # Colours, fonts, spacing, reusable components
└── Resources/
```

Notable services:

| File | Responsibility |
|---|---|
| `AuraAudioEngine` | Dual-player node graph, crossfade, seeking |
| `EQEngine` | 10-band EQ state, presets, persistence |
| `SpectrumAnalyzer` | Realtime FFT tap on the mixer |
| `LibraryScanner` | Recursive Documents scan + metadata reading |
| `LoudnessAnalyzer` | RMS loudness → playback gain |
| `LyricsProvider` | Sidecar → embedded → LRCLIB resolution |
| `DownloadManager` | Background `URLSession` queue |

## Testing

- **Unit tests** (`AuraPlayerTests`) — Swift Testing. Covers `.lrc` parsing, EQ curve maths, preset integrity, and model serialisation.
- **UI tests** (`AuraPlayerUITests`) — XCUITest scaffold.
- Run with **⌘U**.

Audio behaviour that can't be unit-tested (lock screen, AirPlay, background playback) is verified manually on a device.

## Building

1. Open `AuraPlayer/AuraPlayer.xcodeproj` in Xcode.
2. Select an iOS 26 simulator or a device.
3. Build & run (⌘R).

To add music: run the app, then either use the in-app import button, drop files into the AuraPlayer folder in the Files app, or paste a direct URL in Settings → Downloads.

## Not implemented

- DSD decoding (`.dsf`/`.dff` are recognised but need a C bridge to play)
- Writing tags back to files — metadata edits are stored app-side, leaving audio files untouched
- AI-assisted playlists and EQ suggestions

## Licence

See `LICENSE`.
