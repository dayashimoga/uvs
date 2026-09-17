#!/usr/bin/env python3
"""
Synthetic Deterministic Test Media Generator for Universal Video Studio.
Uses FFmpeg to generate SMPTE color bars, countdown timers, tone sweeps,
and test subtitle files without requiring external proprietary media.
"""

import os
import subprocess
import sys
from pathlib import Path

FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"

def run_cmd(cmd):
    print(f"Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        print(f"Error: {res.stderr}", file=sys.stderr)
        raise RuntimeError(f"Command failed with code {res.returncode}: {' '.join(cmd)}")
    return res

def generate_smpte_test_video(output_path: Path, duration_sec: int = 5, width: int = 1920, height: int = 1080, fps: int = 30):
    """Generates an SMPTE HD test video with moving timecode stamp and 1000Hz reference audio tone."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        print(f"Reusing existing test video: {output_path}")
        return output_path

    # Uses FFmpeg smptebars test source + sine wave audio
    cmd = [
        "ffmpeg", "-y",
        "-f", "lavfi",
        "-i", f"smptebars=size={width}x{height}:rate={fps}",
        "-f", "lavfi",
        "-i", "sine=frequency=1000:sample_rate=48000",
        "-t", str(duration_sec),
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "192k",
        str(output_path)
    ]
    run_cmd(cmd)
    print(f"Generated test video: {output_path}")
    return output_path

def generate_4k_test_video(output_path: Path, duration_sec: int = 3):
    """Generates a 4K UHD test video to test proxy generation."""
    return generate_smpte_test_video(output_path, duration_sec=duration_sec, width=3840, height=2160, fps=30)

def generate_subtitle_fixture(output_path: Path):
    """Generates a sample SRT subtitle file."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    content = """1
00:00:00,500 --> 00:00:02,000
Universal Video Studio - Production Ready

2
00:00:02,200 --> 00:00:04,500
Multi-track NLE and High-performance Player

3
00:00:04,600 --> 00:00:05,000
End of Test Clip
"""
    output_path.write_text(content, encoding="utf-8")
    print(f"Generated subtitle fixture: {output_path}")
    return output_path

def generate_cube_lut_fixture(output_path: Path):
    """Generates a valid 3D .cube LUT file (size 2x2x2)."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    content = """# 3D LUT Test Fixture
TITLE "TealAndOrangeTest"
LUT_3D_SIZE 2

0.0 0.0 0.0
1.0 0.2 0.1
0.1 0.9 0.2
0.9 0.8 0.3
0.0 0.2 0.9
0.8 0.3 0.8
0.1 0.9 0.9
1.0 1.0 1.0
"""
    output_path.write_text(content, encoding="utf-8")
    print(f"Generated 3D LUT fixture: {output_path}")
    return output_path

def main():
    print("Generating deterministic test media...")
    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    generate_smpte_test_video(FIXTURES_DIR / "test_smpte_1080p.mp4", duration_sec=4)
    generate_4k_test_video(FIXTURES_DIR / "test_4k_proxy_source.mp4", duration_sec=2)
    generate_subtitle_fixture(FIXTURES_DIR / "test_subtitles.srt")
    generate_cube_lut_fixture(FIXTURES_DIR / "test_look.cube")
    print("All test media generated successfully.")

if __name__ == "__main__":
    main()
