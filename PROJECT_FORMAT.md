# Universal Video Studio Project Format (.uvsp)

The `.uvsp` (Universal Video Studio Project) format is a human-readable, versioned, portable JSON document specifying the complete non-destructive editing state of a project.

---

## 1. Top-Level Specification

```json
{
  "id": "c8f2b3e4-5a6b-4e12-89cd-7f3a8b1a9e2d",
  "name": "Cinematic Short 2026",
  "schema_version": 1,
  "created_at": "2026-09-17T14:30:00Z",
  "updated_at": "2026-09-17T14:45:00Z",
  "timeline": {
    "timecode_config": {
      "num": 30,
      "den": 1,
      "drop_frame": false
    },
    "canvas_width": 1920,
    "canvas_height": 1080,
    "tracks": [
      {
        "id": "track-v1",
        "name": "V1 - Video",
        "track_type": "Video",
        "z_index": 0,
        "muted": false,
        "solo": false,
        "locked": false,
        "opacity": 1.0,
        "volume": 1.0,
        "pan": 0.0,
        "clips": [
          {
            "id": "clip-001",
            "name": "Scene 1 Master",
            "media_path": "media/scene1.mp4",
            "in_point": { "seconds": [0, 1] },
            "out_point": { "seconds": [5, 1] },
            "start_time": { "seconds": [0, 1] },
            "duration": { "seconds": [5, 1] },
            "speed": 1.0,
            "volume": 1.0,
            "opacity": 1.0,
            "blend_mode": "Normal",
            "transform": {
              "position_x": 0.0,
              "position_y": 0.0,
              "scale_x": 1.0,
              "scale_y": 1.0,
              "rotation": 0.0,
              "anchor_x": 0.5,
              "anchor_y": 0.5,
              "crop_left": 0.0,
              "crop_right": 0.0,
              "crop_top": 0.0,
              "crop_bottom": 0.0
            }
          }
        ]
      }
    ],
    "markers": []
  },
  "render_settings": {
    "output_format": "mp4",
    "video_codec": "h264",
    "audio_codec": "aac",
    "width": 1920,
    "height": 1080,
    "fps_num": 30,
    "fps_den": 1,
    "video_bitrate_kbps": 8000,
    "audio_bitrate_kbps": 192,
    "use_hardware_accel": true
  },
  "assets": [],
  "metadata": {}
}
```

---

## 2. Atomic Saves & Recovery Journal

1. **Atomic Saves**:
   - Written to temporary file `<filename>.tmp.<uuid>`.
   - `fsync()` called to ensure disk buffers are flushed.
   - Atomic filesystem rename overwrites the previous version.
2. **Autosave Recovery**:
   - Checkpoints are automatically written to `<project_dir>/.uvsp.recovery` every 60 seconds.
   - If the application terminates abnormally, UVS prompts the user on next startup to recover uncommitted changes.
