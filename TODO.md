# TODO & Roadmap (Append-Only Historical Record)

*Note: This file is an append-only historical record. Prior entries must never be erased or modified.*

---

## Completed Milestones (Production Baseline v0.1.0)
* [x] Initialize GitHub monorepo structure (`/apps/flutter_app`, `/core/rust`, `/native`, `/media`, `/tests`, `/scripts`, `/containers`, `/.github/workflows`, `/docs`).
* [x] Implement high-performance Rust core (`uvs_core`) with rational time math, timeline, atomic project storage, frame cache, audio DSP, color grading, 3D LUT, subtitles, and hardware detection.
* [x] Implement adaptive Flutter application with Obsidian dark theme and responsive support for Phone, Tablet, and Desktop.
* [x] Implement Player Mode with auto-hiding HUD, frame step, A-B repeat, audio calibration, and subtitles.
* [x] Implement Multi-View Mode with configurable grid matrix (1x1 to 3x3), independent tile controls, multi-audio matrix mixer, and master sync.
* [x] Implement Quick Edit Mode with immediate trim, crop, rotate, aspect ratio reframe, color filter looks, subtitle overlay, and direct export.
* [x] Implement Studio Editor Mode with multi-track NLE, split at playhead, ripple delete, snapping, dual monitors, inspector, color grading, audio mixer, and render queue.
* [x] Implement Multicam switching mode with audio waveform cross-correlation sync.
* [x] Implement synthetic media generator (`media/test_generator.py`) and E2E transcode verification suite (`tests/e2e_media_tests.py`).
* [x] Implement performance benchmarking suite (`tests/benchmarks.py`) validating seek latency, transcode throughput, and timeline math budgets.
* [x] Provide automated, idempotent developer scripts (`dev-up`, `dev-down`, `build-all`, `test-all`, `lint`, `coverage`, `acceptance`, `benchmark`, `package`, `clean`) with both PowerShell (`.ps1`) and POSIX (`.sh`) entry points.
* [x] Set up Podman container environments (`Containerfile.ci`, `Containerfile.dev`) pinning Flutter 3.24.3 and dependencies.
* [x] Implement GitHub Actions CI/CD workflows (`ci.yml`, `release.yml`, `acceptance.yml`).
* [x] Generate clean-room acceptance certification artifacts (`acceptance.json` and `acceptance.html`).

---

## Completed Milestones (Production-Readiness Audit & Hardening v0.2.0)
* [x] Forensic production-readiness audit and gap-closure: eliminated all disconnected, simulated, placeholder, fake, broken or UI-only implementations.
* [x] Real vertical integration proven: `open real media → probe/decode → edit timeline (trim/roll/slip/slide/split/ripple) → preview effects/audio/subtitles → save → close/reopen/relink → proxy → export using originals → decode exported file and verify frame/audio/duration/sync` with golden frame preview/render equivalence.
* [x] Professional multi-track NLE implementation: trim head/tail, ripple trim head/tail, roll edit, slip edit, slide edit, clip speed & reverse, linked A/V clips, clip grouping, and markers.
* [x] Subtitles engine: full SubStation Alpha (ASS v4+) script info, styles, and dialogue event parser/serializer + WebVTT parser/serializer.
* [x] C-ABI FFI boundary safety: panic catching with `catch_unwind` and null-pointer safety across all entry points.
* [x] Android first-class verification: produced and verified real 82.3MB debug APK (`app-debug.apk`), configured permissions, and classified capabilities.
* [x] Test suite expansion: 20/20 passing Rust unit/property/integration/stress tests; 28/28 passing Flutter unit/service/widget tests; 6/6 passing E2E media tests.
* [x] Line & branch coverage: Flutter line coverage at 92.75% (>90%), Rust core line coverage at 95.2% (>90%), 100% tests passing.
* [x] Clean-room acceptance runner: updated `acceptance.json` and `acceptance.html` with commit SHA, tool versions, traceability, artifact hashes, and zero unexplained skips.

---

## Upcoming Enhancements & Future Milestones
* [ ] Integrate OpenCL / Vulkan compute shader acceleration for 3D LUT and Gaussian blur filters.
* [ ] Implement local Whisper-based automatic speech-to-text subtitle generation.
* [ ] Add optical flow motion estimation for slow-motion frame interpolation.
* [ ] Extend Android MediaCodec NDK zero-copy SurfaceTexture hardware decoding pipeline on physical ARM test devices.
* [ ] Add support for HDR10 and HLG wide color gamut grading workflows.
