# Troubleshooting & Diagnostic Runbook

This runbook helps developers and users diagnose and resolve unexpected behavior in Universal Video Studio.

---

## 1. Common Issues & Solutions

### 1.1 `Container exits immediately or pub-cache missing`
* **Symptom**: `No such file or directory` reading packages inside container.
* **Root Cause**: Container root `/root/.pub-cache` is transient between separate `podman run --rm` invocations.
* **Resolution**: Ensure `-e PUB_CACHE=/workspace/.pub-cache` is passed to Podman, as configured in all project scripts.

### 1.2 `Hardware encoder unavailable`
* **Symptom**: `h264_nvenc` or `hevc_qsv` cannot open encoder.
* **Root Cause**: Virtualized container environment or driver mismatch.
* **Resolution**: UVS automatically falls back to `libx264` / `libx265`. You can also force software encoding in Render Settings.

### 1.3 `Missing media files after moving project`
* **Symptom**: Red offline media warning on timeline clips.
* **Resolution**: Use `Project -> Relink Missing Assets` or invoke `relink_missing_assets()` with candidate media directories. The engine matches assets by SHA-256 hash or filename + filesize.
