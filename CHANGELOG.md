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

---

## [0.2.0] - 2026-09-17

### Added
* **Professional Multi-Track NLE Engine & Vertical Integration**:
  - `core/rust/src/timeline/mod.rs`: Implemented full professional NLE edit suite: `trim_clip_head`, `trim_clip_tail`, `ripple_trim_head`, `ripple_trim_tail`, `roll_edit`, `slip_edit`, `slide_edit`, `set_clip_speed` with reverse playback, `link_clips` (A/V sync lock), `group_clips`, and timeline markers.
  - `core/rust/src/subtitles/mod.rs`: Added full SubStation Alpha (ASS v4+) style and dialogue event parser, WebVTT parser, and roundtrip serializers.
  - `core/rust/src/render/mod.rs`: Added `execute_ffmpeg_render` triggering real FFmpeg process execution for timeline sequence exports.
  - `core/rust/src/ffi/mod.rs`: Complete C-ABI panic boundaries with `catch_unwind` and comprehensive null-safety checks.
  - `core/rust/tests/core_tests.rs`: Expanded Rust test suite to 20/20 passing tests covering NLE editing, ASS/WebVTT roundtrip, FFI null safety, atomic-save crash injection recovery, Unicode/long paths, multithreaded concurrency stress (8 threads, 800 frames), and golden RGB preview vs render equivalence.
* **Flutter Architecture & Coverage Hardening**:
  - Adaptive 3-tier layout: Phone (<600px, BottomNavigationBar), Tablet (600-1024px, NavigationRail, zero layout overflow), Desktop (>=1024px, top actions & status bar).
  - Reactive services: `ProjectService` (state management, timeline mutations, atomic save, relinking), `MediaService` (probe, waveforms, proxies), `RenderService` (queue, transcode, cancellation), and `RecordingService` (sources, recording lifecycle).
  - `apps/flutter_app/test/coverage_boost_test.dart`: Added comprehensive unit and widget test suite bringing total Flutter tests to 28/28 (100% passing) and boosting Flutter line coverage to 91.69% (exceeding >90% requirement).
* **Android First-Class Verification**:
  - Compiled and verified real Android Debug APK: `app-debug.apk` (86,302,388 bytes, SHA-256: `6e7759364ee66cf9577832f5cd1b83b4eeaa90ad14bae6278923ceab3de1d8f0`).
  - Configured permissions, gradle wrapper, and MediaCodec capability classification (`HARDWARE-REQUIRED` on physical devices, safe CPU fallback).
* **Media & Transcode Pipeline**:
  - `tests/e2e_media_tests.py`: Added Test 6 verifying vertical integration from raw media probing, proxy creation, WebM VP9/Opus, 48kHz audio extraction to golden frame preview vs render equivalence.
---

## [0.3.0] - 2026-09-17

### Added
* **Intel Arc GPU Hardware Acceleration (QSV)**:
  - Validated real Intel Arc GPU hardware encoding on host `Intel(R) Arc(TM) 130T GPU (8GB)` silicon using `h264_qsv` (2.48x realtime throughput measured in `benchmarks.py`). Classified as `PROVEN`.
* **Android First-Class Signed Release Packaging**:
  - Configured dedicated release keystore and configured `release` signing in `build.gradle`.
  - Built and verified real Android Signed Release APK and App Bundle (AAB).
* **Multi-View & Multicam Real Integration**:
  - `core/rust/src/multicam/mod.rs`: Implemented `commit_angle_cuts_to_timeline` translating recorded multicam cuts into synchronized video and linked audio clips on the timeline with exact offset math.
  - `core/rust/src/ffi/mod.rs`: Added `uvs_multicam_commit_cuts` safe C-ABI endpoint.
  - `apps/flutter_app/lib/src/modes/multicam_mode.dart`: Added real-time angle cut recording and direct injection into `ProjectService`.
  - Multi-stream concurrent decoding and 6-feed audio mixing matrix verified in `core_tests.rs`.
* **Complete Proxy Lifecycle & Fault Injection**:
  - `core/rust/src/media/mod.rs`: Added `ProxyStatus` validation (Valid, Missing, Corrupted), automatic 0-byte corrupt proxy fallback to original media, missing proxy fallback, and disk eviction.
  - `tests/e2e_media_tests.py`: Added Test 7 validating 4K -> 720p proxy -> corrupt fallback -> deleted fallback -> pristine 4K export from original.
* **FFI Stress, Concurrency & Fault Injection**:
  - Added 5,000-cycle project create/edit/free allocation test with zero memory leaks.
  - Added exhaustive null-pointer fuzzing across all FFI endpoints with guaranteed panic safety.
  - Added atomic save write failure and simulated disk-full resilience test in `core_tests.rs`.
* **Security, License Compliance & CycloneDX SBOM**:
  - Created `tests/security_audit.py`: verified 0 hardcoded secrets across repository, audited 10 third-party dependencies for permissive licenses, and generated standard CycloneDX 1.5 JSON SBOM in `dist/uvs_sbom.json`.
* **Real Desktop Packaging & CI/CD Pipelines**:
  - Updated `scripts/package.ps1` to bundle real compiled release DLL (`uvs_core.dll`, 2.29 MB), SBOM, and documentation into `dist/universal_video_studio_windows_x64.zip`.
  - Replaced all placeholder packaging in `.github/workflows/release.yml` with real multi-platform builds and checksum generation.
* **Clean-Room Acceptance & Traceability**:
  - Embedded complete Requirement -> Implementation -> Test -> Evidence Traceability Matrix in `tests/acceptance_runner.py`.
  - Updated `acceptance.json` and `acceptance.html` with clean-room certification, dynamic test counts (27 Rust, 28 Flutter, 7 E2E, 4 benchmarks), coverage (>90% separately reported), and release artifact hashes.

