# Clean-Room Acceptance & Certification Policy

Universal Video Studio enforces honest, evidence-based acceptance certification. Features are never claimed to work without empirical validation.

---

## 1. Classification Taxonomy

In accordance with core project governance, every capability is classified strictly into one of five categories:

1. **`PROVEN`**:
   - Directly executed and proven by automated test suites or benchmarks on physical host hardware.
   - Example: Rust rational timeline math, project atomic save/relink, audio DSP (EQ/Compressor/LUFS), FFmpeg software encoding/decoding, 720p proxy generation, and benchmark thresholds.
2. **`EMULATOR-PROVEN`**:
   - Validated inside containerized or virtualized environments (e.g. Podman Ubuntu 24.04 container executing Flutter 3.24.3 tests).
3. **`SIMULATED`**:
   - Validated using synthetic media feeds or software mocks replicating external devices (e.g. multi-view 6-tile live matrix monitoring).
4. **`IMPLEMENTED-UNPROVEN`**:
   - Complete production-grade source code, CMake/JNI bridges, and unit test harnesses implemented, awaiting physical hardware execution.
5. **`HARDWARE-REQUIRED`**:
   - Platform-dependent silicon features that require specific physical hardware (e.g. Apple VideoToolbox on Apple Silicon, Android MediaCodec on physical ARM devices, NVENC on physical Nvidia RTX GPUs).

---

## 2. Mandatory Quality Criteria for Release

To achieve certification:
* **Zero Failing Tests**: 100% pass rate across all Rust, Flutter, and E2E media test suites.
* **Coverage Threshold**: $>90.0\%$ line coverage across testable first-party code.
* **Performance Compliance**: All benchmarks must meet or exceed target budgets.
* **Clean-Room Generation**: `acceptance.json` and `acceptance.html` must be generated automatically from clean repository state.
