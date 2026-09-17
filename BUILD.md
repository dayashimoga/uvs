# Build Guide

Universal Video Studio can be built both natively and inside reproducible Podman containers without host SDK dependencies.

---

## 1. Containerized Build (Recommended)

To build the complete solution using Podman:

```bash
# PowerShell (Windows)
.\scripts\build-all.ps1

# POSIX (Linux / macOS)
./scripts/build-all.sh
```

This compiles:
1. `core/rust`: Rust core library in release profile (`target/release/uvs_core.dll` / `.so`).
2. `apps/flutter_app`: Flutter release asset bundle and compiled code.

---

## 2. Native Compilation

### Rust Core
```bash
cd core/rust
cargo build --release
cargo test --all-targets
```

### Flutter Application
```bash
cd apps/flutter_app
flutter pub get
flutter build bundle
```
