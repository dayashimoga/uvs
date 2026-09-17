# Testing & QA Framework

Universal Video Studio implements a strict automated quality gate enforcing **>90% code coverage** and **100% passing mandatory tests** before any code is approved.

---

## 1. Test Taxonomy

1. **Rust Core Integration Tests (`core/rust/tests/core_tests.rs`)**:
   - Timecode rational math, drop-frame calculation.
   - Timeline operations: clip overlap validation, split, ripple delete.
   - Keyframe linear, ease-in, ease-out, and Bezier interpolation.
   - Project JSON serialization, atomic file writing, schema migration.
   - Memory-budgeted frame cache LRU eviction.
   - Audio DSP: 5-band EQ, compressor envelope follower, integrated LUFS, waveform extractor.
   - Color grading: 3D LUT parsing and interpolation, green-screen chroma keying.
   - Subtitle SRT and WebVTT parsing and formatting.
   - Audio correlation lag detection for multicam synchronization.
   - Automation: silence detection intervals, scene cuts, smart reframing bounding box.
   - Invertible 100-step undo/redo stack fuzzing.
2. **Flutter Widget & Layout Tests (`apps/flutter_app/test/widget_test.dart`)**:
   - Model hierarchy integrity.
   - App launches in Player mode and switches cleanly across all 5 modes.
   - Split at playhead and ripple delete execution.
   - Responsive layout at Phone (400x800) displaying bottom navigation bar.
3. **End-to-End Media Tests (`tests/e2e_media_tests.py`)**:
   - Generates real synthetic SMPTE HD color bars, 4K clips, and tone sweeps using FFmpeg.
   - Probes files with `ffprobe` to verify exact codecs, dimensions, and audio channels.
   - Tests 720p proxy generation from 4K media.
   - Tests transcode to WebM (VP9 + Opus) and 48kHz PCM WAV extraction.
4. **Performance Benchmarks (`tests/benchmarks.py`)**:
   - Seek latency (< 250ms target).
   - Transcoding throughput (> 1.5x realtime target).
   - Timeline math loop throughput (> 500,000 ops/sec target).

---

## 2. Executing the Quality Gates

```bash
# Execute entire test suite
.\scripts\test-all.ps1

# Execute coverage threshold check
.\scripts\coverage.ps1

# Execute full clean-room acceptance runner
.\scripts\acceptance.ps1
```
