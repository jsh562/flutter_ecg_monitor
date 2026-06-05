# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-15

### Added
- **EcgMonitor widget** — Drop-in animated ECG/heartbeat monitor for Flutter
- **EcgMonitorConfig** — Immutable configuration object with `copyWith()` support
- **EcgGridPainter** — Static ECG-paper grid background (GPU-cached via `RepaintBoundary`)
- **EcgTrailPainter** — Animated phosphor trail with cursor dot
- **Zero per-frame allocations** — Ring buffer + pre-baked LUTs for optimal performance
- **Authentic PQRST waveform** — 1000-point Gaussian lookup table for realistic cardiac events
- **Heart Rate Variability (HRV)** — Organic time-warping via dual sine waves
- **Breathing baseline** — Slow sinusoidal drift simulating respiratory artifact
- **Ambient screen flash** — Subtle radial glow when cursor spikes off baseline
- **Theme-aware tip color** — Auto white/black87 based on `Brightness`, fully overridable
- **Configurable parameters**:
  - `heartRateBPM` — Beats per minute (default: 60.0)
  - `beatDurationSeconds` — PQRST waveform duration (default: 0.35)
  - `cursorSpeedPixelsPerSecond` — Cursor travel speed (default: 40.0)
  - `lineThickness` — Trail stroke width (default: 1.0)
  - `cursorThickness` — Cursor dot radius (default: 1.0)
  - `glowThickness` — Cursor glow halo radius (default: 1.1)
  - `beatSpikeAmplitude` — R-spike height in pixels (default: 8.0)
  - `gapMinPixels` / `gapMaxPixels` — Gap distance constraints (default: 15/100)
  - `gridMinorSpacing` — Grid line spacing (default: 15.0)
  - `gridMajorEvery` — Major line frequency (default: 5)
  - `breathingAmplitude` — Baseline breathing wave amplitude (default: 0.8)
  - `breathsPerMinute` — Breathing rate (default: 15.0)
  - `color` — Trail base color (default: `Color(0xFF00FF00)`)
  - `tipColor` — Cursor tip color (default: null = light/dark mode-dependent)

### Documentation
- **README.md** — Quick start guide, configuration table, advanced usage examples
- **ARCHITECTURE.md** — Deep dive into optimization techniques (O1-O7), rendering pipeline, state management
- **MIGRATION.md** — Migration guide from inline implementation to package
- **Example app** — Three demo configurations (resting 60 BPM, elevated 100 BPM, bradycardia 27 BPM)

### Performance Optimizations
- **O1: Pre-baked Heartbeat LUT** — 1000-element `Float64List` computed once at class load
- **O2: Ring Buffer Trail Storage** — `Float64List` indexed by pixel X, `double.nan` for empty slots
- **O3: Distance-to-Paint LUT** — Pre-mapped integer distance → paint bucket index
- **O4: Pre-built Paint Lists** — 100 `Paint` objects covering full dim→bright gradient
- **O5: GPU-cached Static Grid** — `RepaintBoundary` wrapper for zero-repaint background
- **O6: Targeted Gap Cleanup** — O(gap) erase loop vs O(n) map scan
- **O7: Skipped-pixel History Fill** — Back-calculates missed pixels on dropped frames

### Technical Details
- Minimum SDK: Dart `>=3.0.0 <4.0.0`, Flutter `>=3.10.0`
- Zero external dependencies (Flutter SDK only)
- Wall-clock accurate timing via `DateTime.now()` — independent of frame rate
- Cursor wraps seamlessly from right edge to left edge
- Trail persists across painter recreation (static state)

[0.1.0]: https://github.com/jsh562/flutter_ecg_monitor/releases/tag/v0.1.0
