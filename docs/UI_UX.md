# UI/UX Design System & Adaptive Layouts

Universal Video Studio implements a minimalist, modern, distraction-free aesthetic designed for high-focus multimedia editing.

---

## 1. Color Palette (Obsidian Studio)

| Token | Hex Value | Semantic Purpose |
| :--- | :--- | :--- |
| `background` | `#0D1117` | Canvas and app background |
| `surface` | `#161B22` | Navigation bars, toolbars, panels |
| `surfaceElevated` | `#21262D` | Cards, monitors, dialogue surfaces |
| `border` | `#30363D` | Crisp dividers and panel boundaries |
| `accentCyan` | `#00D2FF` | Active selection, playheads, primary buttons |
| `accentBlue` | `#3A7BD5` | Video clip tracks, secondary actions |
| `accentEmerald` | `#00E676` | Audio tracks, success status, live badges |
| `accentAmber` | `#FFB74D` | Subtitles, warnings, solo indicators |
| `accentRed` | `#FF5252` | Recording, mute indicators, errors |

---

## 2. Adaptive Responsive Breakpoints

* **Phone (< 600px width)**:
  - Bottom navigation bar with 5 primary mode tabs.
  - Fullscreen touch preview with contextual bottom sheets.
  - Single/dual-track timeline with pinch-to-zoom.
* **Tablet (600px – 1024px width)**:
  - Split-screen preview + multi-track timeline.
  - Expandable right-hand inspector panel.
* **Desktop (> 1024px width)**:
  - Top mode selector bar.
  - Dual Program/Source monitors.
  - Multi-track non-linear timeline with zoom ruler.
  - 5-tab inspector panel (Transform, Color, Audio Mixer, Subtitles, Render Queue).
