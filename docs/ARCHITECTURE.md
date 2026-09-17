# System Architecture

Universal Video Studio (UVS) uses a layered, multi-engine architecture that cleanly decouples UI representation from high-throughput media processing, memory-bounded caching, and non-linear timeline mathematics.

---

## 1. High-Level Architecture Diagram

```mermaid
graph TD
    subgraph UI_Layer["Adaptive Flutter UI Layer"]
        Shell["Main Studio Shell"]
        PlayerUI["Player Mode View"]
        MultiViewUI["Multi-View Matrix View"]
        QuickEditUI["Quick Edit View"]
        StudioUI["Studio Editor NLE View"]
        MixerUI["Audio Mixer & DSP Panel"]
        ColorUI["Color Grading Inspector"]
    end

    subgraph FFI_Boundary["Safe C / Dart FFI Boundary"]
        Bridge["C-ABI Packet Exchange (JSON & Raw Buffers)"]
    end

    subgraph Rust_Core["High-Performance Rust Core (uvs_core)"]
        TimeEngine["Rational Timecode & Math"]
        TimelineEngine["Tracks, Clips, Transitions, Keyframes"]
        ProjectEngine["Atomic I/O, Recovery, Relinking"]
        GraphEngine["DAG Compositor, Blend Modes, Transforms"]
        AudioEngine["48kHz Bus, 5-Band EQ, Compressor, LUFS"]
        EffectsEngine["Color Grading, 3D LUT, Chroma Key"]
        SubtitlesEngine["SRT, WebVTT, ASS Engine"]
        ProxyEngine["Proxy Manager & Transcode Rules"]
        RenderQueueEngine["Priority Scheduler & Progress Stream"]
        UndoEngine["Reversible Delta Action Stack"]
    end

    subgraph Native_Layer["Native Platform & Acceleration"]
        FFmpegCore["FFmpeg 9.0.1 / libav* Engine"]
        HW_Dec["Nvidia NVENC / Intel QSV / Apple VideoToolbox / MediaCodec"]
        OS_Runners["Windows C++ / Linux GTK / Android NDK / macOS Swift"]
    end

    Shell --> PlayerUI & MultiViewUI & QuickEditUI & StudioUI
    StudioUI --> MixerUI & ColorUI
    UI_Layer <-->|Async Events & JSON/Buffers| Bridge
    Bridge <--> Rust_Core
    Rust_Core <--> Native_Layer
    FFmpegCore <--> HW_Dec
```

---

## 2. Thread and Execution Model

To guarantee the user interface never blocks or drops frames during playback, scrub, or heavy background export:

1. **UI Thread (Flutter Main Isolate)**:
   - Handles gesture input, user interactions, layout rendering, and widget animations.
   - Zero decoding or file I/O operations occur on this isolate.
2. **Core Computation Thread Pool (Rayon)**:
   - Parallel pixel composition, transform matrix calculations, 3D LUT interpolation, and biquad audio filtering run on a worker pool scaled to `logical_cpus`.
3. **Decoded Frame Cache Worker**:
   - Asynchronously pre-fetches and decodes video frames into a bounded LRU memory pool.
   - Enforces configurable RAM limits (256MB on Android, 1GB on Desktop) with instantaneous eviction.
4. **Background Render Queue Isolates**:
   - Independent background threads that spawn and supervise FFmpeg worker processes for project rendering, proxy generation, and batch transcode without contending with playback.

---

## 3. Safe FFI Boundary Specification

The FFI boundary uses standard C-ABI calling conventions:
* `uvs_core_version()`: Returns library build version string.
* `uvs_detect_hardware()`: Serializes detected GPU and hardware encoders to JSON.
* `uvs_project_new(name, width, height, fps_num, fps_den, drop_frame)`: Initializes project.
* `uvs_project_save_atomic(project_json, target_path)`: Atomically commits project to disk.
* `uvs_project_load(path)`: Loads, validates, and migrates `.uvsp` project files.
* `uvs_free_string(ptr)`: Reclaims allocated C-string buffers with zero memory leaks.
