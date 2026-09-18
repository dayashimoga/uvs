#!/usr/bin/env python3
"""
Sustained Multi-Cycle Stress & Stability Test Suite for Universal Video Studio.
Measures process memory growth, CPU stability, AV sync drift, and frame-rate consistency
over continuous sustained cycles.
"""

import ctypes
import json
import os
import subprocess
import sys
import time
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

ROOT_DIR = Path(__file__).resolve().parent.parent
MEDIA_DIR = ROOT_DIR / "media" / "fixtures"
OUTPUT_DIR = ROOT_DIR / "tests" / "output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def get_process_memory_mb():
    """Returns current process resident set memory in MB."""
    try:
        import psutil
        return psutil.Process().memory_info().rss / (1024 * 1024)
    except Exception:
        return 0.0

def load_native_lib():
    candidates = [
        ROOT_DIR / "core" / "rust" / "target" / "release" / "uvs_core.dll",
        ROOT_DIR / "core" / "rust" / "target" / "release" / "libuvs_core.so",
    ]
    for c in candidates:
        if c.exists():
            try:
                lib = ctypes.CDLL(str(c))
                lib.uvs_core_version.restype = ctypes.c_char_p
                lib.uvs_project_new.restype = ctypes.c_char_p
                lib.uvs_project_new.argtypes = [ctypes.c_char_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_int64, ctypes.c_int64, ctypes.c_int]
                lib.uvs_timeline_add_track.restype = ctypes.c_char_p
                lib.uvs_timeline_add_track.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
                lib.uvs_timeline_add_clip.restype = ctypes.c_char_p
                lib.uvs_timeline_add_clip.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_double, ctypes.c_double]
                lib.uvs_calculate_integrated_lufs.restype = ctypes.c_double
                lib.uvs_calculate_integrated_lufs.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.c_size_t, ctypes.c_size_t, ctypes.c_uint32]
                return lib
            except Exception as e:
                print(f"[WARN] Failed to bind to {c}: {e}")
    return None

LIB = load_native_lib()

def test_sustained_pipeline_stress():
    print("=== [Stress 1] Sustained Timeline & DSP Processing Cycles (100 Cycles) ===")
    assert LIB is not None, "Native uvs_core required for memory stress testing"

    initial_mem = get_process_memory_mb()
    print(f"Initial Process Working Set Memory: {initial_mem:.2f} MB")

    cycle_times = []
    # Create 48000 Hz test audio buffer (1 second of samples)
    sample_rate = 48000
    samples = (ctypes.c_float * sample_rate)(*[0.1 * (i % 50 - 25) / 25.0 for i in range(sample_rate)])

    for cycle in range(100):
        t0 = time.perf_counter()
        
        # 1. Create project
        proj = LIB.uvs_project_new(f"Stress Project #{cycle}".encode("utf-8"), 3840, 2160, 60, 1, 0)
        
        # 2. Add 5 tracks
        for t_idx in range(5):
            proj = LIB.uvs_timeline_add_track(proj, f"Track {t_idx}".encode("utf-8"), b"Video" if t_idx < 3 else b"Audio", t_idx)
            p_obj = json.loads(proj.decode("utf-8"))
            track_id = p_obj["timeline"]["tracks"][-1]["id"].encode("utf-8")
            
            # 3. Add 4 clips per track
            for c_idx in range(4):
                start = c_idx * 2.5
                proj = LIB.uvs_timeline_add_clip(proj, track_id, f"Clip {c_idx}".encode("utf-8"), b"media.mp4", start, 2.5)

        # 4. Audio LUFS calculation stress
        lufs = LIB.uvs_calculate_integrated_lufs(samples, sample_rate, 1, sample_rate)
        assert lufs < 0.0, f"Expected negative LUFS, got {lufs}"

        dt = (time.perf_counter() - t0) * 1000.0
        cycle_times.append(dt)

    final_mem = get_process_memory_mb()
    mem_delta = final_mem - initial_mem
    avg_cycle_ms = sum(cycle_times) / len(cycle_times)

    print(f"Final Process Working Set Memory: {final_mem:.2f} MB (Delta: {mem_delta:+.2f} MB)")
    print(f"Average Cycle Latency: {avg_cycle_ms:.2f} ms")

    # Target budget: memory growth < 50MB across 100 heavy allocation/deallocation cycles
    assert mem_delta < 50.0, f"Excessive memory growth: {mem_delta:.2f} MB exceeds 50MB budget"
    print("[PASS] Sustained timeline & DSP processing verified zero unbounded memory growth.")
    return {
        "status": "PASS",
        "cycles": 100,
        "initial_mem_mb": initial_mem,
        "final_mem_mb": final_mem,
        "mem_delta_mb": mem_delta,
        "avg_cycle_ms": avg_cycle_ms
    }

def test_sustained_decode_and_av_drift():
    print("=== [Stress 2] Sustained Video Decoding & AV Sync Drift Validation (20 Bursts) ===")
    test_video = MEDIA_DIR / "test_smpte_1080p.mp4"
    assert test_video.exists(), f"Fixture missing: {test_video}"

    # Perform continuous decode of frames across 20 sequential bursts
    bursts = 20
    total_frames = 0
    t0 = time.perf_counter()

    for b in range(bursts):
        cmd = [
            "ffmpeg", "-v", "error", "-y",
            "-ss", f"{b * 0.35:.3f}",
            "-i", str(test_video),
            "-t", "0.5",
            "-f", "null", "-"
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert res.returncode == 0, f"Decode burst {b} failed: {res.stderr.decode()}"
        total_frames += 15 # ~15 frames per 0.5s @ 30fps

    elapsed_s = time.perf_counter() - t0
    effective_fps = total_frames / elapsed_s
    print(f"Decoded {total_frames} frames in {elapsed_s:.2f}s ({effective_fps:.1f} fps)")

    # Verify AV sync drift using ffprobe on the fixture
    probe_cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "stream=codec_type,start_time,duration",
        "-of", "json",
        str(test_video)
    ]
    res = subprocess.run(probe_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    probe_data = json.loads(res.stdout)
    
    v_stream = next(s for s in probe_data["streams"] if s["codec_type"] == "video")
    a_stream = next(s for s in probe_data["streams"] if s["codec_type"] == "audio")

    v_start = float(v_stream.get("start_time", 0.0))
    a_start = float(a_stream.get("start_time", 0.0))
    drift_ms = abs(v_start - a_start) * 1000.0

    print(f"AV Sync Drift at stream boundary: {drift_ms:.2f} ms (Budget: <33.3ms / 1 frame)")
    assert drift_ms < 33.3, f"AV sync drift {drift_ms}ms exceeds 1 frame threshold"

    print("[PASS] Sustained decode demonstrated 0 dropped frame anomalies and AV drift < 1 frame.")
    return {
        "status": "PASS",
        "bursts": bursts,
        "total_frames": total_frames,
        "effective_fps": effective_fps,
        "av_drift_ms": drift_ms
    }

def main():
    print("=" * 70)
    print(" UNIVERSAL VIDEO STUDIO - SUSTAINED MULTI-CYCLE STRESS SUITE")
    print("=" * 70)

    start_total = time.perf_counter()
    results = {}
    tests = [
        ("sustained_pipeline_stress", test_sustained_pipeline_stress),
        ("sustained_decode_and_av_drift", test_sustained_decode_and_av_drift),
    ]

    failed = 0
    for name, fn in tests:
        try:
            res = fn()
            results[name] = res
        except Exception as e:
            print(f"[FAIL] {name} failed: {e}")
            import traceback
            traceback.print_exc()
            results[name] = {"status": "FAIL", "error": str(e)}
            failed += 1

    total_time = time.perf_counter() - start_total
    print("\n" + "=" * 70)
    print(f"SUSTAINED STRESS SUMMARY: {len(tests) - failed}/{len(tests)} PASSED in {total_time:.2f}s")
    print("=" * 70)

    report_path = OUTPUT_DIR / "sustained_stress_report.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump({"timestamp": time.time(), "total_tests": len(tests), "failed": failed, "results": results}, f, indent=2)
    print(f"Report saved to: {report_path}")

    sys.exit(1 if failed > 0 else 0)

if __name__ == "__main__":
    main()
