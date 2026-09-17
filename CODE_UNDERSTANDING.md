# Codebase Understanding & Tour

This guide helps engineers navigate the Universal Video Studio monorepo, understand key abstractions, and make modifications safely.

---

## 1. Rust Core Engine (`core/rust/src`)

* [`timeline/timecode.rs`](file:///core/rust/src/timeline/timecode.rs):
  Defines `RationalTime` and `TimecodeConfig`. Handles SMPTE drop-frame formatting and frame-to-second conversions.
* [`timeline/mod.rs`](file:///core/rust/src/timeline/mod.rs):
  Contains the central `Timeline`, `Track`, `Clip`, `Transform`, and `KeyframeTrack` structures.
* [`project/storage.rs`](file:///core/rust/src/project/storage.rs):
  Contains `Project`, `AssetMetadata`, atomic file writer (`save_atomic`), and missing asset relinker (`relink_missing_assets`).
* [`media/mod.rs`](file:///core/rust/src/media/mod.rs):
  Contains probe structures (`MediaInfo`), the thread-safe `FrameCache` using `AtomicUsize` memory budgeting, and `ProxyManager`.
* [`graph/mod.rs`](file:///core/rust/src/graph/mod.rs):
  Pixel canvas compositor (`ImageCanvas`), alpha blend modes (Normal, Add, Multiply, Screen, Overlay), and transform blitter.
* [`audio/mod.rs`](file:///core/rust/src/audio/mod.rs):
  48kHz `AudioBuffer`, RBJ `BiquadFilter`, 5-band `Equalizer`, dynamic `Compressor`, `calculate_integrated_lufs`, and `extract_waveform`.
* [`effects/mod.rs`](file:///core/rust/src/effects/mod.rs):
  `ColorGradingConfig`, 3D `.cube` parser & interpolator (`Lut3D`), and green-screen keyer (`ChromaKeyConfig`).
* [`subtitles/mod.rs`](file:///core/rust/src/subtitles/mod.rs):
  `SubtitleTrack`, `SubtitleCue`, SRT and WebVTT parsers and formatters.
* [`render/mod.rs`](file:///core/rust/src/render/mod.rs):
  Hardware capability detector (`HardwareCapabilities`), `RenderQueue`, and FFmpeg argument generator.
* [`undo/mod.rs`](file:///core/rust/src/undo/mod.rs):
  Invertible `Action` enum and `UndoStack` implementing bidirectional command history.
* [`ffi/mod.rs`](file:///core/rust/src/ffi/mod.rs):
  C-compatible exports (`uvs_project_new`, `uvs_project_save_atomic`, `uvs_project_load`, `uvs_free_string`).

---

## 2. Flutter Adaptive Application (`apps/flutter_app/lib`)

* [`main.dart`](file:///apps/flutter_app/lib/main.dart):
  App shell, mode switcher, responsive viewport router (Phone, Tablet, Desktop).
* [`src/core/theme.dart`](file:///apps/flutter_app/lib/src/core/theme.dart):
  Obsidian dark design tokens, color palette, typography.
* [`src/modes/player_mode.dart`](file:///apps/flutter_app/lib/src/modes/player_mode.dart):
  Standalone media player with auto-hiding floating HUD and A-B repeat.
* [`src/modes/multi_view_mode.dart`](file:///apps/flutter_app/lib/src/modes/multi_view_mode.dart):
  Multi-stream matrix monitoring with per-tile volume faders and master sync.
* [`src/modes/quick_edit_mode.dart`](file:///apps/flutter_app/lib/src/modes/quick_edit_mode.dart):
  Rapid trim, rotate, aspect ratio reframe, color filter looks, subtitle overlay.
* [`src/modes/studio_editor_mode.dart`](file:///apps/flutter_app/lib/src/modes/studio_editor_mode.dart):
  Full multi-track NLE, Program monitor, split at playhead, ripple delete, render dialog.
* [`src/widgets/timeline_view.dart`](file:///apps/flutter_app/lib/src/widgets/timeline_view.dart):
  Interactive multi-track timeline widget with pinch zoom and clip rendering.
* [`src/widgets/audio_mixer_view.dart`](file:///apps/flutter_app/lib/src/widgets/audio_mixer_view.dart):
  Master meters, track faders, 5-band EQ visualization, and compressor controls.
* [`src/widgets/color_inspector_view.dart`](file:///apps/flutter_app/lib/src/widgets/color_inspector_view.dart):
  Color grading sliders, 3D LUT loader, and interactive Lift/Gamma/Gain wheels.
