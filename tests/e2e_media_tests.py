#!/usr/bin/env python3
"""
End-to-End Media & Transcoding Test Suite for Universal Video Studio.
Validates real media playback, decoding, proxy generation, and multi-format
export pipelines using FFmpeg and ffprobe.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# Ensure UTF-8 output on Windows console
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

ROOT_DIR = Path(__file__).resolve().parent.parent
MEDIA_DIR = ROOT_DIR / "media"
FIXTURES_DIR = MEDIA_DIR / "fixtures"
OUTPUT_DIR = ROOT_DIR / "tests" / "output"

def run_cmd(cmd):
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        print(f"Command failed: {' '.join(cmd)}\n{res.stderr}", file=sys.stderr)
        raise RuntimeError(f"Command error: {res.stderr}")
    return res

def probe_file(path: Path) -> dict:
    """Probes media file using ffprobe and returns parsed JSON metadata."""
    cmd = [
        "ffprobe", "-v", "quiet",
        "-print_format", "json",
        "-show_format", "-show_streams",
        str(path)
    ]
    res = run_cmd(cmd)
    return json.loads(res.stdout)

def test_media_generation():
    print("=== [Test 1] Generating Test Fixtures ===")
    generator_script = MEDIA_DIR / "test_generator.py"
    res = subprocess.run([sys.executable, str(generator_script)], check=True)
    assert (FIXTURES_DIR / "test_smpte_1080p.mp4").exists(), "SMPTE test video not generated"
    assert (FIXTURES_DIR / "test_4k_proxy_source.mp4").exists(), "4K test video not generated"
    assert (FIXTURES_DIR / "test_subtitles.srt").exists(), "Subtitle fixture not generated"
    print("[PASS] Media generation verified.")

def test_source_probing():
    print("=== [Test 2] Probing Source Media ===")
    info = probe_file(FIXTURES_DIR / "test_smpte_1080p.mp4")
    video_stream = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio_stream = next(s for s in info["streams"] if s["codec_type"] == "audio")

    assert video_stream["width"] == 1920, f"Expected 1920 width, got {video_stream['width']}"
    assert video_stream["height"] == 1080, f"Expected 1080 height, got {video_stream['height']}"
    assert video_stream["codec_name"] == "h264", f"Expected h264, got {video_stream['codec_name']}"
    assert audio_stream["codec_name"] == "aac", f"Expected aac, got {audio_stream['codec_name']}"
    assert float(info["format"]["duration"]) >= 3.9, "Duration too short"
    print("[PASS] Source probing verified (1920x1080 h264 + aac).")

def test_proxy_generation():
    print("=== [Test 3] Generating 720p Proxy from 4K ===")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    source_4k = FIXTURES_DIR / "test_4k_proxy_source.mp4"
    proxy_720p = OUTPUT_DIR / "proxy_720p.mp4"

    cmd = [
        "ffmpeg", "-y",
        "-i", str(source_4k),
        "-vf", "scale=1280:720",
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-crf", "26",
        "-c:a", "copy",
        str(proxy_720p)
    ]
    run_cmd(cmd)

    probe = probe_file(proxy_720p)
    video = next(s for s in probe["streams"] if s["codec_type"] == "video")
    assert video["width"] == 1280, f"Expected proxy width 1280, got {video['width']}"
    assert video["height"] == 720, f"Expected proxy height 720, got {video['height']}"
    print("[PASS] Proxy generation verified (1280x720 fast encode).")

def test_transcode_webm():
    print("=== [Test 4] Transcoding to WebM (VP9 + Opus) ===")
    source = FIXTURES_DIR / "test_smpte_1080p.mp4"
    out_webm = OUTPUT_DIR / "export_vp9.webm"

    cmd = [
        "ffmpeg", "-y",
        "-i", str(source),
        "-t", "2",
        "-c:v", "libvpx-vp9",
        "-b:v", "1500k",
        "-c:a", "libopus",
        "-b:a", "96k",
        str(out_webm)
    ]
    run_cmd(cmd)

    probe = probe_file(out_webm)
    video = next(s for s in probe["streams"] if s["codec_type"] == "video")
    audio = next(s for s in probe["streams"] if s["codec_type"] == "audio")
    assert video["codec_name"] == "vp9", f"Expected vp9, got {video['codec_name']}"
    assert audio["codec_name"] == "opus", f"Expected opus, got {audio['codec_name']}"
    print("[PASS] WebM export verified (VP9 + Opus).")

def test_audio_normalization_and_extract():
    print("=== [Test 5] Audio Normalization & Extraction ===")
    source = FIXTURES_DIR / "test_smpte_1080p.mp4"
    out_wav = OUTPUT_DIR / "extracted_audio.wav"

    cmd = [
        "ffmpeg", "-y",
        "-i", str(source),
        "-vn",
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
        "-ac", "2",
        "-ar", "48000",
        str(out_wav)
    ]
    run_cmd(cmd)

    probe = probe_file(out_wav)
    audio = next(s for s in probe["streams"] if s["codec_type"] == "audio")
    assert audio["codec_name"] == "pcm_s16le", f"Expected pcm_s16le, got {audio['codec_name']}"
    assert audio["channels"] == 2, f"Expected 2 channels, got {audio['channels']}"
    assert int(audio["sample_rate"]) == 48000, f"Expected 48000Hz, got {audio['sample_rate']}"
    print("[PASS] Audio normalization & extraction verified (48kHz 2-channel PCM WAV).")

def main():
    print("Running End-to-End Media Pipeline Verification...")
    test_media_generation()
    test_source_probing()
    test_proxy_generation()
    test_transcode_webm()
    test_audio_normalization_and_extract()
    print("\n[SUCCESS] All 5 End-to-End Media Tests PASSED with 100% success.")

if __name__ == "__main__":
    main()
