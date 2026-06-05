# flutter_ecg_monitor — Architecture & Implementation Notes

## Table of Contents
1. [Overview](#overview)
2. [File Map](#file-map)
3. [Core Optimization Techniques](#core-optimization-techniques)
   - [O1 — Pre-baked Heartbeat LUT](#o1--pre-baked-heartbeat-lut)
   - [O2 — Ring Buffer Trail Storage](#o2--ring-buffer-trail-storage)
   - [O3 — Distance-to-Paint LUT](#o3--distance-to-paint-lut)
   - [O4 — Pre-built Paint Lists](#o4--pre-built-paint-lists)
   - [O5 — GPU-cached Static Grid](#o5--gpu-cached-static-grid)
   - [O6 — Targeted Gap Cleanup](#o6--targeted-gap-cleanup)
   - [O7 — Skipped-pixel History Fill](#o7--skipped-pixel-history-fill)
4. [Animation & Timing Architecture](#animation--timing-architecture)
5. [ECG Waveform Design](#ecg-waveform-design)
   - [PQRST Shape via Gaussians](#pqrst-shape-via-gaussians)
   - [HRV Organic Time-Warping](#hrv-organic-time-warping)
   - [Breathing Baseline](#breathing-baseline)
6. [Rendering Pipeline (Per-Frame)](#rendering-pipeline-per-frame)
7. [State Management](#state-management)
8. [Known Limitations & Future Work](#known-limitations--future-work)

---

## Overview

`flutter_ecg_monitor` renders a moving phosphor-dot cursor that writes an authentic PQRST
ECG waveform trail behind it — like a real bedside cardiac monitor.

The primary challenge is that `CustomPainter.paint()` is called every frame (~60–120 Hz). 
Every allocation in `paint()` adds pressure to the Dart GC and can cause dropped frames. 
The entire implementation is designed around **zero per-frame heap allocations**.

---

## File Map

```
lib/
├── flutter_ecg_monitor.dart      — Public barrel export
└── src/
    ├── ecg_monitor_config.dart   — All tunable parameters (immutable value object)
    ├── ecg_monitor.dart          — EcgMonitor StatefulWidget (animation controller + layer stack)
    ├── ecg_grid_painter.dart     — EcgGridPainter (static ECG-paper background)
    └── ecg_trail_painter.dart    — EcgTrailPainter (ring buffer + LUT + trail + cursor dot)
```

---

## Core Optimization Techniques

### O1 — Pre-baked Heartbeat LUT

**File:** `ecg_trail_painter.dart` — `_buildHeartbeatLUT()`

**Problem:** Computing a realistic PQRST waveform in real-time for every pixel every frame
would require multiple `math.exp()` calls per pixel — extremely expensive.

**Solution:** Pre-compute the entire PQRST shape once at class load time into a 1000-element
`Float64List`. During `paint()`, the waveform value at any beat-progress `p` (0.0–1.0) is
just a single array lookup:

```dart
// Built ONCE at class load (static final):
static final Float64List _heartbeatLUT = _buildHeartbeatLUT();

// Used each frame — zero math, just a lookup:
final index = (beatProgress * 999).toInt();
final yOffset = _heartbeatLUT[index] * cfg.beatSpikeAmplitude;
```

**Cost:** ~8 KB of RAM (1000 × 8 bytes). Paid once, never again.

---

### O2 — Ring Buffer Trail Storage

**File:** `ecg_trail_painter.dart` — `_trailBuffer`

**Problem:** The naive approach (a `Map<double, double>` of stored positions) requires
sorting and iterating a growing collection each frame. The old `_heartbeatTrail` map
was O(n log n) to sort and caused the "freaking out" trail bug because every lookup
recalculated positions.

**Solution:** A `Float64List` of length exactly equal to the pixel-width of the canvas.
Index = X pixel coordinate. Value = Y position at that pixel. Empty slots = `double.nan`.

```
_trailBuffer[0..width-1]
  Index = pixel X position
  Value = Y position drawn at that X   (double.nan = empty / gap)
```

This is a **ring buffer** — the cursor writes to index `cursorX`, wrapping from
`width-1` back to `0`. No sorting, no map overhead, O(1) writes and reads.

**Key:** `double.nan` as the sentinel for empty slots avoids any conditional branch —
`y.isNaN` is a single CPU instruction.

---

### O3 — Distance-to-Paint LUT

**File:** `ecg_trail_painter.dart` — `_distanceToPaintLUT`

**Problem:** The trail fades from dim (oldest) to bright (newest). Computing
`opacity = 1.0 - (distanceBehind / maxVisible)` per segment every frame involves
a division and a multiply for every single pixel drawn.

**Solution:** Pre-bake the answer for every possible integer distance (0 to width) into
an `Int32List`. Value = index into the pre-built paint list (0–99).

```dart
// Built once when screen width is known:
_distanceToPaintLUT[i] = ((1.0 - i * invMax) * 99).toInt().clamp(0, 99);

// Per-pixel during draw — zero math:
final int paintIndex = _distanceToPaintLUT[distanceBehind];
canvas.drawLine(..., _corePaints[paintIndex]);
```

This LUT is rebuilt only when `size.width` changes (e.g. orientation change), not every frame.

---

### O4 — Pre-built Paint Lists

**File:** `ecg_trail_painter.dart` — `_corePaints`, `_glowPaints`

**Problem:** `Paint` objects are small but creating 100 of them per frame (one per fade step)
with `Color.lerp()` and `withValues()` is wasteful allocation.

**Solution:** Build exactly 100 `Paint` objects in the constructor, covering the full
dim→bright gradient from `config.color` to `resolvedTipColor`. Stored in `List<Paint>`.

```dart
// Built ONCE in constructor:
_corePaints = List.generate(100, (i) {
  final intensity = i / 99.0;
  final heat = intensity * intensity * intensity; // cubic for more "phosphor" feel
  final opacity = intensity * intensity;
  return Paint()
    ..color = Color.lerp(from, to, heat)!.withValues(alpha: opacity * maxAlpha)
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round;
});

// Per-pixel during draw — just index lookup, zero allocation:
canvas.drawLine(..., _corePaints[paintIndex]);
```

The cubic `heat` curve makes the trail feel like a real phosphor screen —
dim for most of its length, then rapidly brightening right before the cursor.

---

### O5 — GPU-cached Static Grid

**File:** `ecg_grid_painter.dart`, `ecg_monitor.dart`

**Problem:** The ECG-paper grid (minor + major lines) never changes. Repainting it every
animation frame wastes GPU bandwidth.

**Solution:** Wrap `EcgGridPainter` in a `RepaintBoundary`. Flutter rasterizes it once
and caches the texture on the GPU. It is only re-rasterized if `shouldRepaint` returns
`true` (i.e. theme colour changes).

```dart
RepaintBoundary(
  child: CustomPaint(
    painter: EcgGridPainter(config: config, isDarkMode: isDark),
    size: Size.infinite,
  ),
),
// Trail layer on top — repaints every frame, grid layer does NOT
CustomPaint(painter: EcgTrailPainter(...), size: Size.infinite, willChange: true),
```

---

### O6 — Targeted Gap Cleanup

**File:** `ecg_trail_painter.dart` — gap cleanup loop

**Problem:** The old implementation used `Map.removeWhere()` which scanned every entry
in the map to find gap candidates — O(n) over the entire trail on every frame.

**Solution:** Since the gap is always exactly `gapDistance` pixels ahead of `cursorX`,
we can compute the exact indices to erase and write `double.nan` directly:

```dart
// Erase exactly gapDistance+5 pixels ahead of cursor — O(gap) not O(width)
int del = (intCursorX + 1) % intWidth;
for (int k = 0; k < gapDistance + 5; k++) {
  _trailBuffer[del] = double.nan;
  del = (del + 1) % intWidth;
}
```

The `+ 5` buffer guards against lag-spike frames where the cursor jumps
multiple pixels and the gap might not have been cleared in time.

---

### O7 — Skipped-pixel History Fill

**File:** `ecg_trail_painter.dart` — history fill loop

**Problem:** On slower devices (or when the app is backgrounded), the cursor might jump
several pixels between frames, leaving unfilled NaN slots in the ring buffer. These
appear as gaps in the trail that shouldn't be there.

**Solution:** If `_lastIntCursorX != intCursorX`, fill every skipped pixel by
back-calculating what the Y value *would have been* at that time using:

```
historicalTime = nowSeconds - (pixelsBehind * secondsPerPixel)
```

`secondsPerPixel = 1.0 / cursorSpeedPixelsPerSecond` is computed **once outside**
the loop (the expensive division), then only a multiplication is needed per pixel inside.

```dart
final double secondsPerPixel = 1.0 / cfg.cursorSpeedPixelsPerSecond; // once
while (i != intCursorX && safety < intWidth) {
  int behind = intCursorX - i;
  if (behind < 0) behind += intWidth;
  _trailBuffer[i] = yForTime(nowSeconds - behind * secondsPerPixel); // multiply only
  i = (i + 1) % intWidth;
  safety++;
}
```

---

## Animation & Timing Architecture

**Key insight:** The `AnimationController` is used *only* to trigger repaints at the
display refresh rate. It does **not** drive timing.

All timing uses `DateTime.now().millisecondsSinceEpoch`:

```dart
final nowSeconds = DateTime.now().millisecondsSinceEpoch / 1000.0;
final cursorX = (nowSeconds * cfg.cursorSpeedPixelsPerSecond) % width;
```

**Why this matters:**
- Cursor speed is truly constant in pixels/second regardless of screen width or frame rate
- Beat timing is wall-clock accurate — pausing/resuming the app doesn't cause drift
- If a frame is dropped, the cursor jumps to the correct position and the history fill
  (O7) reconstructs any missing trail pixels

---

## ECG Waveform Design

### PQRST Shape via Gaussians

The waveform is built from 5 summed Gaussian functions — one per cardiac event:

```dart
y += gaussian(p, 0.15,  0.15, 0.030);  // P-Wave  (small atrial bump)
y += gaussian(p, -0.15, 0.25, 0.015);  // Q-Dip   (small negative dip)
y += gaussian(p,  1.20, 0.35, 0.020);  // R-Spike (tall ventricular spike)
y += gaussian(p, -0.40, 0.45, 0.020);  // S-Dip   (negative after R)
y += gaussian(p,  0.35, 0.70, 0.060);  // T-Wave  (broad recovery bump)
```

Gaussian parameters: `(x, amplitude, centre, width)`.
The shape is computed once into a 1000-point LUT (see O1).

### HRV Organic Time-Warping

Real heartbeats are not perfectly metronomic. Heart Rate Variability (HRV) is
simulated by slightly warping time before computing beat position:

```dart
final organic = t + (math.sin(t * 0.4) + math.sin(t * 0.7)) * 0.15;
final cycle = organic % secondsPerBeat;
```

Two slow sine waves with incommensurate frequencies (0.4 and 0.7 rad/s) create
a pseudo-random drift that never exactly repeats, giving the monitor a live feel.

### Breathing Baseline

The flat baseline between beats is not truly flat. A slow sine wave (default 15
breaths/min) shifts the centerline up and down, simulating respiratory baseline
wander — a real artifact seen on clinical ECG monitors.

```dart
final breathFreq = 2.0 * math.pi * (cfg.breathsPerMinute / 60.0);
return centerY + math.sin(t * breathFreq) * cfg.breathingAmplitude + noise;
```

A tiny noise term (`±0.5 px`) adds electrode contact jitter for realism.

---

## Rendering Pipeline (Per-Frame)

```
paint() called by Flutter at ~60–120 Hz
│
├─ 1. Resize check: if width changed → rebuild _trailBuffer + _distanceToPaintLUT
│
├─ 2. Compute cursorX = (nowSeconds × speed) % width          [O(1)]
│
├─ 3. History fill: write any skipped pixels to _trailBuffer  [O(skipped px)]
│
├─ 4. Write current cursor Y to _trailBuffer[cursorX]         [O(1)]
│
├─ 5. Erase gap zone ahead of cursor                          [O(gap px)]
│
├─ 6. Ambient flash (RadialGradient rect) if off-baseline     [O(1)]
│
├─ 7. Draw trail: iterate _trailBuffer, skip NaN, LUT lookup  [O(width)]
│    └─ 2 drawLine calls per pixel (glow + core)
│
└─ 8. Draw cursor dot (2 drawCircle calls)                    [O(1)]
```

Total allocations in steps 2–8: **zero** (all state is reused `static` typed arrays
and pre-built `Paint` objects).

---

## State Management

All mutable render state is `static` on `EcgTrailPainter`. This means state persists
across painter instances (Flutter recreates the painter object every `AnimatedBuilder`
frame), which is intentional — the trail must survive painter recreation.

| Field | Type | Purpose |
|---|---|---|
| `_heartbeatLUT` | `Float64List(1000)` | Pre-baked PQRST waveform shape |
| `_trailBuffer` | `Float64List(width)` | Y-position for every X pixel |
| `_distanceToPaintLUT` | `Int32List(width)` | Distance → paint index mapping |
| `_lastIntCursorX` | `int` | Previous frame's cursor X (for history fill) |

`_trailBuffer` and `_distanceToPaintLUT` are reset (rebuilt) when `size.width` changes.

---

## Known Limitations & Future Work

- **Multiple instances:** Because trail state is `static`, two `EcgMonitor` widgets on
  screen simultaneously will share the same `_trailBuffer`. Fix: use an instance key
  or per-instance state object passed from the widget level.
- **Canvas width mismatch:** If the widget is used in a layout where width changes
  frequently (e.g. inside an animated container), the buffer will be rebuilt often.
- **TODO:** Expose `beatSpikeAmplitude` as a fraction of widget height rather than
  absolute pixels so the widget scales naturally with `height`.
- **TODO:** Add a `showGrid` toggle to `EcgMonitorConfig` to disable the background
  grid for minimal/embedded use-cases.
- **TODO:** Consider making `_trailBuffer` an instance field (passed via the widget
  state) to support multiple simultaneous instances cleanly.
- **TODO:** Fragment Shader with CPU fallback implementation for even better, flexible performance
