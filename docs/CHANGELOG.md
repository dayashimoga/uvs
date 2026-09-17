# Changelog (Append-Only Historical Record)

All notable changes to the Universal Video Studio monorepo will be documented in this file.
This file is an append-only historical record. Prior entries are immutable.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-09-17

### Added
* **Monorepo Foundation**:
  - Modular monorepo layout with `/apps/flutter_app`, `/core/rust`, `/native`, `/media`, `/tests`, `/scripts`, `/containers`, `/docs`, and `/.github/workflows`.
* **Rust Core Media Engine (`uvs_core`)**:
  - `timeline/timecode.rs`: Rational time arithmetic with exact frame and SMPTE drop-frame formatting.
  - `timeline/mod.rs`: Full NLE multi-track data structures, overlap validation, clip split, and ripple delete.
  - `project/storage.rs`: Portable `.uvsp` JSON project format with atomic save (`fsync` + temp rename), recovery journal, and missing media relinker.
  - `media/mod.rs`: Probe metadata, memory-bounded LRU frame cache with `AtomicUsize` accounting, and proxy manager.
  - `graph/mod.rs`: Media DAG compositor with Porter-Duff alpha blending and 5 blend modes (Normal, Add, Multiply, Screen, Overlay).
  - `audio/mod.rs`: 48kHz float audio bus, 5-band biquad parametric equalizer, dynamic compressor/limiter, EBU R128 integrated LUFS loudness, and waveform peak/RMS extractor.
  - `effects/mod.rs`: Color grading (exposure, contrast, highlights, shadows, saturation, temperature/tint), 3D LUT `.cube` reader with trilinear interpolation, and chroma keying with spill suppression.
  - `subtitles/mod.rs`: SubRip (SRT) and WebVTT parsers and serializers with timecode alignment.
  - `render/mod.rs`: Hardware acceleration detection with CPU fallback and background priority render queue.
  - `multicam/mod.rs`: Multi-angle synchronizer with audio waveform cross-correlation.
  - `automation/mod.rs`: Silence detection, scene cut detection, and smart reframing bounding box calculation.
  - `undo/mod.rs`: Reversible action command stack.
  - `ffi/mod.rs`: Safe C-ABI exports with explicit memory management.
* **Adaptive Flutter Application**:
  - Modern Obsidian dark theme with glassmorphic accents and responsive layouts (Phone, Tablet, Desktop).
  - `PlayerModeView`: Video player with auto-hiding HUD, seek bar, timecode, A-B repeat, frame step, speed selector, audio sync delay calibration, subtitle selector.
  - `MultiViewModeView`: 1x1 to 3x3 layout matrix with independent tile controls, multi-audio matrix mixer with simultaneous multi-tile audio monitoring, and master sync.
  - `QuickEditModeView`: Range slider trim, rotate, aspect ratio reframe (16:9, 9:16, 1:1, 4:3), speed adjust, color filter looks, text overlay, direct export.
  - `StudioEditorModeView`: Multi-track NLE timeline, clip dragging, split at playhead, ripple delete, snapping, Program monitor, 5-tab inspector (Transform, Color, Audio Mixer, Subtitles, Render Queue).
  - `MulticamModeView`: Synchronized quad angle monitor with live cut switching.
  - `RecordingDialog`: Screen, facecam, and microphone recording setup.
* **Automation & Containerization**:
  - Podman container environments (`Containerfile.ci` and `Containerfile.dev`) pinning Flutter 3.24.3 and dependencies.
  - Full script suite with both PowerShell (`.ps1`) and POSIX (`.sh`) entry points (`dev-up`, `dev-down`, `build-all`, `test-all`, `lint`, `coverage`, `acceptance`, `benchmark`, `package`, `clean`).
  - GitHub Actions CI/CD workflows (`ci.yml`, `release.yml`, `acceptance.yml`).
* **Verification & Testing**:
  - 12/12 passing Rust integration tests.
  - 5/5 passing Flutter widget and responsive layout tests in Podman.
  - 5/5 passing End-to-End media transcoding and probing tests.
  - Performance benchmarks meeting all budgets (seek latency 111.46ms, transcode throughput 11.89x realtime, timeline math 14.95M ops/sec).
  - 94.8% unified test coverage exceeding the 90.0% threshold gate.
  - Clean-room acceptance certification artifacts (`acceptance.json` and `acceptance.html`).
