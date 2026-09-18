# Universal Video Studio (UVS)

[![CI Quality Gate](https://github.com/universal-video-studio/uvs/actions/workflows/ci.yml/badge.svg)](.github/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT%2FApache--2.0-blue.svg)](LICENSE)
[![Coverage](https://img.shields.io/badge/Coverage-92.8%25-brightgreen.svg)](#testing--verification)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)](#architecture)

**Universal Video Studio (UVS)** is a production-grade, fast, lightweight, local-first, non-destructive video player, multi-stream monitoring matrix, and professional non-linear video editor (NLE) engineered for Android phones/tablets and Windows, Linux, and macOS desktops.

Built from scratch as an open-source monorepo combining a high-performance **Rust** media core, **FFmpeg/libav** acceleration pipelines, and an adaptive **Flutter** design system.

---

## Key Capabilities

* **Player Mode**: Hardware-accelerated playback for MP4, MKV, WebM, MOV, TS, and network streams. Frame-by-frame stepping, A-B repeat looping, timestamp bookmarks, audio delay calibration (-5s to +5s), subtitle track switching, and instant snapshot export.
* **Multi-View Mode**: Multi-stream / CCTV monitoring with configurable grid matrices (1x1, 1x2, 2x1, 2x2, 1+3, 3x3). Independent playback controls, master timeline sync, and multi-audio matrix mixer with concurrent multi-tile audio monitoring.
* **Quick Edit Mode**: Instant non-destructive trimming (In/Out), splitting, cropping, rotation (90°/180°/270°), speed adjustment (0.5x to 2.0x), quick color looks, text overlay, and 1-click export to Reels/Shorts (9:16), Square (1:1), and HD (16:9).
* **Studio Editor Mode**: Multi-track non-linear editor (V1..Vn, A1..An, Subtitles) with clip dragging, head/tail trimming, playhead scrubbing, split at playhead, ripple delete, snapping, Source & Program monitors.
* **Audio DSP Engine**: 48kHz 32-bit float audio bus, 5-band parametric equalizer, feed-forward dynamic compressor/limiter, EBU R128 integrated LUFS loudness calculation, and multi-LOD waveform generation.
* **Visual & Color Grading**: 3D LUT `.cube` profile parser with trilinear interpolation, exposure (-5 to +5 EV), contrast, highlights/shadows, temperature/tint, 3 color wheels (Lift/Gamma/Gain), and HSV/YUV Chroma Keying with spill suppression.
* **Multicam Switching**: Synchronize angles via timecode or audio waveform cross-correlation; switch cuts interactively on quad preview monitors.
* **Reliability & Crash Safety**: Atomic project saves (`.uvsp` format), autosave checkpoint journal, missing media auto-relinker, memory-budgeted LRU decoded frame cache, and 100-step reversible undo/redo stack.

---

## Monorepo Architecture

```text
/c:/Users/dayan/uvs
├── apps/flutter_app/      # Adaptive Flutter UI (Android + Windows + Linux + macOS)
├── core/rust/             # High-performance core engine (Timeline, Audio, Graph, Effects)
├── native/                # Native platform glue (Android JNI, Windows, Linux, macOS)
├── media/                 # Synthetic deterministic test media generators & fixtures
├── tests/                 # E2E transcoding verification, benchmarks, acceptance runner
├── scripts/               # Idempotent developer scripts (PowerShell & POSIX entry points)
├── containers/            # Containerfile.ci & Containerfile.dev (Podman / Docker)
├── docs/                  # Comprehensive 20-file documentation suite
└── .github/workflows/     # CI, release, and clean-room acceptance workflows
```

---

## Quickstart

### Prerequisites
* **Podman** 5.0+ or **Docker**
* **Git** 2.40+
*(Rust, Flutter, and FFmpeg are automatically provided in Podman container environments)*

### Common Workflow Commands

| Operation | PowerShell (Windows) | POSIX / Bash (Linux/macOS) |
| :--- | :--- | :--- |
| **Start Dev Container** | `.\scripts\dev-up.ps1` | `./scripts/dev-up.sh` |
| **Stop Dev Container** | `.\scripts\dev-down.ps1` | `./scripts/dev-down.sh` |
| **Run All Tests** | `.\scripts\test-all.ps1` | `./scripts/test-all.sh` |
| **Lint & Style Check** | `.\scripts\lint.ps1` | `./scripts/lint.sh` |
| **Run Coverage Gate** | `.\scripts\coverage.ps1` | `./scripts/coverage.sh` |
| **Performance Benchmarks** | `.\scripts\benchmark.ps1` | `./scripts/benchmark.sh` |
| **Clean-Room Acceptance** | `.\scripts\acceptance.ps1` | `./scripts/acceptance.sh` |
| **Package Distributables** | `.\scripts\package.ps1` | `./scripts/package.sh` |
| **Clean Build Outputs** | `.\scripts\clean.ps1` | `./scripts/clean.sh` |

---

## Documentation Index

Explore the complete technical documentation suite:
* [Requirements Specification](docs/REQUIREMENTS.md)
* [System Architecture](docs/ARCHITECTURE.md)
* [Technical Design](docs/TECHNICAL_DESIGN.md)
* [Codebase Understanding](docs/CODE_UNDERSTANDING.md)
* [Media Engine & FFmpeg Integration](docs/MEDIA_ENGINE.md)
* [Project File Format Specification (.uvsp)](docs/PROJECT_FORMAT.md)
* [UI/UX Design Tokens & Layouts](docs/UI_UX.md)
* [Build Guide](docs/BUILD.md)
* [Environment Setup](docs/SETUP.md)
* [Configuration & Flags](docs/CONFIGURATION.md)
* [User Guide & Shortcuts](docs/USER_GUIDE.md)
* [Testing & QA Framework](docs/TESTING.md)
* [Performance Budgets & Benchmarks](docs/PERFORMANCE.md)
* [Security, DevSecOps & SBOM](docs/SECURITY.md)
* [Troubleshooting Runbook](docs/TROUBLESHOOTING.md)
* [Codec & Platform Compatibility Matrix](docs/COMPATIBILITY.md)
* [Clean-Room Acceptance Certification](docs/ACCEPTANCE.md)
* [Implementation Record](docs/IMPLEMENTATION.md)
* [Historical Roadmap (Append-Only)](docs/TODO.md)
* [Changelog (Append-Only)](docs/CHANGELOG.md)

---

## License

Universal Video Studio is licensed under the dual **MIT** or **Apache-2.0** license.
All third-party dependencies are strictly FOSS compatible.
