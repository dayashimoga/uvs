# Developer Environment Setup

This document guides new contributors through setting up their workstation for Universal Video Studio development.

---

## 1. Zero-Install Podman Setup

The only required tools on the host system are:
* **Git** 2.40+
* **Podman** 5.0+ (with WSL2 backend on Windows, or native rootless on Linux)

Launch the isolated development environment:
```bash
# Windows
.\scripts\dev-up.ps1

# Linux / macOS
./scripts/dev-up.sh
```

---

## 2. Host Development Setup (Optional)

For engineers wishing to develop natively on the host:
* **Rust**: Install via rustup (`rustup default stable`).
* **FFmpeg**: Install FFmpeg 7.0+ or 9.0+ and ensure `ffmpeg` and `ffprobe` are on your PATH.
* **Flutter**: Flutter 3.24.3+ on the stable channel.
* **Python**: Python 3.10+ for test runners and deterministic media generation.
