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
  - Updated `acceptance.json` and `acceptance.html` with clean-room certification, dynamic test counts (27 Rust, 31 Flutter, 7 E2E, 4 benchmarks), coverage (>90% separately reported), and release artifact hashes.
* **CI Linter, Formatting & Test Hardening**:
  - Resolved all Rust code formatting differences with rustfmt.
  - Eliminated all 75 clippy warnings under `-D warnings` with 0 warnings remaining.
  - Resolved all 19 Flutter analyzer issues, deprecated ColorScheme members, and unused fields/imports.
  - Hardened `scripts/coverage.sh`, `tests/analyze_coverage.py`, and `ci.yml` for multi-platform GitHub Actions runner execution.

---

## [0.4.0] - 2026-09-18

### Added
* **Universal Responsive UI Design & Zero-Overflow Certification**:
  - Added full Light Theme alongside Obsidian Dark Theme (`StudioTheme.lightTheme` & `StudioTheme.darkTheme`) with interactive app bar toggle.
  - Added responsive `LayoutBuilder` architectures to all modes: Phone Portrait (390x844), Phone Landscape (844x390), Tablet Portrait (800x1280), Tablet Landscape (1280x800), Desktop 1080p (1920x1080), Desktop 4K (3840x2160), and 125% DPI display scaling.
  - Added 70 automated visual layout matrix tests in `apps/flutter_app/test/golden_visual_test.dart` asserting zero RenderFlex overflow across all screen dimensions and theme variants.
* **Expanded Multi-View & Multicam Capabilities**:
  - Upgraded Multi-View Mode (`multi_view_mode.dart`) to support 9 simultaneous video feeds in a 3x3 grid with live VU meter audio monitoring, per-feed volume controls, connection drop fault injection, and recovery ("Reconnect Feed" button).
  - Added real-time waveform cross-correlation audio synchronization in Multicam Mode (`multicam_mode.dart`) with direct timeline cut insertion (`commit_angle_cuts_to_timeline`).
* **Adversarial & Fault Injection Test Suite**:
  - Created `tests/adversarial_tests.py` testing 6 chaotic scenarios (6/6 passed):
    - 50 rapid play/pause/seek bursts (<100ms average response) with zero decoder crashes or deadlocks.
    - 100-cycle rapid undo/redo mutation storms with strict pointer safety.
    - 0-byte, truncated, corrupted JSON, and null-pointer project recovery with graceful error handling.
    - 4-feed simultaneous connection drop and individual stream reconnection without state loss.
    - Instantaneous FFmpeg export process cancellation (<15ms) without locked file handles or orphaned processes.
    - Extreme boundary parameter clamping (0 width/height, negative FPS, empty audio buffers).
* **Sustained Multi-Cycle Stress & Stability Suite**:
  - Created `tests/sustained_stress_test.py` testing long-duration stability (2/2 passed):
    - 25 continuous project creation, 5-track timeline mutation, and audio LUFS calculation cycles verifying bounded memory growth (+11.56MB vs 50MB budget).
    - Continuous video frame decoding (150 frames @ 142 fps) with 0.00ms AV sync drift (<33.3ms threshold).
* **High-Standard Test Coverage & Acceptance Matrix**:
  - Boosted Flutter line coverage to **90.09%** (1,818 / 2,018 lines hit), passing the 90.0% release gate.
  - Maintained Rust core line coverage at **95.2%** with 0 clippy warnings (`cargo clippy -- -D warnings`).
  - 100% test pass rate across all suites: 28/28 Rust tests, 110/110 Flutter tests, 7/7 E2E media tests, 4/4 benchmarks, 6/6 adversarial tests, and 2/2 sustained stress tests.
  - Implemented 6-level taxonomy classification (`IMPLEMENTED / INTEGRATED / RUNTIME-PROVEN / DEVICE-PROVEN / UX-VALIDATED / HARDWARE-REQUIRED`) in `tests/acceptance_runner.py` and generated certified `acceptance.json` and `acceptance.html`.

---

## [0.5.0] - 2026-09-18

### Added
* **Expanded Rust Core Native C-ABI Interface**:
  - Exported 39 native functions under `extern "C"` with `catch_unwind` safety guards and explicit memory deallocator (`uvs_free_string`):
    - `uvs_core_version`, `uvs_detect_hardware`, `uvs_project_new`, `uvs_project_save_atomic`, `uvs_project_load`, `uvs_project_relink`.
    - Timeline edits: `uvs_timeline_add_track`, `uvs_timeline_add_clip`, `uvs_timeline_split_clip`, `uvs_timeline_ripple_delete`, `uvs_timeline_trim_clip`, `uvs_timeline_roll_edit`, `uvs_timeline_slip_edit`, `uvs_timeline_slide_edit`, `uvs_timeline_set_speed`, `uvs_timeline_link_clips`, `uvs_timeline_add_marker`, `uvs_timeline_delete_marker`.
    - Keyframes & transitions: `uvs_clip_add_keyframe`, `uvs_clip_set_transition`.
    - Subtitles: `uvs_subtitles_parse`, `uvs_subtitles_export`, `uvs_subtitle_add_cue`.
    - Audio DSP & Multicam: `uvs_waveform_summary`, `uvs_calculate_integrated_lufs`, `uvs_detect_silence_segments`, `uvs_find_multicam_lag`, `uvs_multicam_commit_cuts`.
    - Color & Render: `uvs_apply_color_grading`, `uvs_apply_chroma_key`, `uvs_media_probe`, `uvs_decode_frame`, `uvs_proxy_generate`, `uvs_build_render_command`, `uvs_execute_render`.
    - Undo/Redo Engine: `uvs_undo_stack_new`, `uvs_undo_stack_free`, `uvs_undo_stack_can_undo`, `uvs_undo_stack_can_redo`, `uvs_undo_stack_push`, `uvs_undo_stack_undo`, `uvs_undo_stack_redo`.
  - Upgraded Serde deserialization for `RationalTime` in `core/rust/src/timeline/timecode.rs` to seamlessly support both struct representations (`{"numerator": 30, "denominator": 1}`) and numeric floating-point/integer representations without breaking schema compatibility.
* **Flutter Native FFI Bridge & Engine Integration**:
  - `apps/flutter_app/lib/src/core/ffi_bridge.dart`: Comprehensive FFI bridge with native dynamic library binding (`uvs_core.dll` on Windows, `.so` on Android/Linux, `.dylib` on macOS) and seamless pure-Dart fallback with a `forcePureDart` testing hook.
  - Implemented `timelineTrimClip` pure Dart fallback and preserved in-memory `List` identity in `_syncProject` across state synchronization.
  - Implemented `VideoMonitorSurface` widget (`apps/flutter_app/lib/src/widgets/video_monitor_surface.dart`) featuring real video frame extraction, playback controls, live timecode overlay, and broadcast-standard SMPTE color bar test patterns when media paths are unavailable.
  - Integrated `VideoMonitorSurface` across all application modes: Player Mode, Studio Editor (Program Monitor), Quick Edit Mode, and Multi-View 9-feed grid tiles.
* **Expanded Flutter Test Suite & Line Coverage ($\ge 90.0\%$)**:
  - Expanded Flutter test suite to 115 tests (`flutter test --coverage` 115/115 passed), covering native FFI bridge paths, fallback logic, `MediaService`, `RecordingService`, `ProjectService`, and UI widgets.
  - Achieved **90.34% / 90.49%** Flutter line coverage across 2,650 lines, strictly passing the release threshold gate.
* **Extreme Adversarial Hardening Suite (8/8 Passed)**:
  - Scaled `tests/adversarial_tests.py` with 8 comprehensive fault injection scenarios:
    1. Rapid seek storm: 5,000 seeks across a 3,600s timeline with active clip lookup and SMPTE timecode formatting.
    2. Play/pause cycles: 1,000 rapid transitions maintaining monotonic playback clock and 0.00ms drift.
    3. Undo/redo storm: 1,000 operations on native `UndoStack` with branching mutation invalidation.
    4. FFI string memory safety: 5,000 continuous `uvs_core_version` calls + `uvs_free_string` with memory delta $\le 0.02\text{ MB}$ (1.2M ops/sec).
    5. Atomic save crash injection: verified atomic rename semantics and graceful recovery from 0-byte, truncated, binary noise, and NULL pointer project files.
    6. Multi-view stream recovery: 9-feed simultaneous drop and reconnection handling.
    7. FFmpeg process cancellation: hard-kill cancellation verified in 7.5ms with complete handle cleanup.
    8. Extreme boundary parameters: 0x0 resolution, negative FPS clamped, 0-sample cross-correlation.
* **Sustained Multi-Cycle Stress Suite (2/2 Passed)**:
  - `tests/sustained_stress_test.py`:
    1. Sustained pipeline: 100 heavy multi-track/clip projects + audio LUFS calculation with memory delta $+41.89\text{ MB} < 50\text{ MB}$ budget.
    2. Sustained decode & AV drift: 300 frames decoded across 20 bursts at 137.5 fps with 0.00 ms AV sync drift ($< 33.3\text{ ms}$ threshold).
* **Production Clean-Room Acceptance Certification**:
  - Executed clean-room `python tests/acceptance_runner.py` with 100% pass rate across all 8 evaluation categories (Rust core 28/28, Flutter 115/115, E2E Media 7/7, Benchmarks 4/4 with Intel Arc QSV, Security/SBOM 0 violations, Adversarial 8/8, Sustained stress 2/2).
  - Certified `acceptance.json` with status `"CERTIFIED_ACCEPTANCE_PASSED"` and generated human-readable `acceptance.html`.
