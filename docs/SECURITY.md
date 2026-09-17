# Security, DevSecOps & SBOM Policy

Universal Video Studio is committed to the highest standards of software supply chain security, privacy, and local-first execution.

---

## 1. Local-First & Privacy Guarantees

* **Zero Telemetry**: UVS never transmits project files, video thumbnails, media paths, or audio data over the internet.
* **Network Isolation**: Network access is solely utilized for explicit user actions (e.g. streaming RTSP/HLS feeds).
* **Safe Temporary Files**: All proxy, waveform, and cache files are stored in user-isolated directories and securely wiped on project close or via `clean.ps1`.

---

## 2. Secure Software Supply Chain

1. **Memory Safety**: The core media and timeline engines are written in **Rust**, eliminating buffer overflows, use-after-free, and data races.
2. **Path Traversal Protection**: Project load routines sanitize all relative asset paths to prevent directory traversal attacks (`../`).
3. **Automated Vulnerability Auditing**:
   - `cargo audit` checks all Rust dependencies against the RustSec Advisory Database.
   - Pinned container base images in `containers/Containerfile.ci`.
4. **FOSS License Compliance**: Only permissive and compatible open-source licenses (MIT, Apache-2.0, BSD-3, LGPL-2.1+) are permitted in the dependency tree.
