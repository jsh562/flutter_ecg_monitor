# flutter_ecg_monitor

A realistic, animated ECG / heartbeat-monitor widget for Flutter.
Renders a moving phosphor-dot cursor that draws an authentic-looking PQRST waveform gaussian trail behind it — simulating a bedside cardiac ECG monitor.

## Disclaimer

This is not a real ECG, but rather a realistic-looking cosmetic animation. It's for fun and entertainment purposes - Not designed for use in a medical or professional context. If you would like modifications for a medical or professional use, please contact James Han (jsh562@gmail.com).

## License Summary - Conditional Fair Source
tldr: Free for free use. Paid for commercial use.

This project is licensed under the [HAN CONDITIONAL FAIR SOURCE 1.0](LICENSE).

The Licensor (James Han) grants you a license to the Software ONLY under the following conditions. Your legal right to use this software is determined by your status:

1. FREE NON-COMMERCIAL USERS (Personal, Hobbyist, Student, Research)
   - You may CHOOSE between:
     a) Prosperity Public License 3.0.0 (Default, Non-viral)
     b) AGPL-3.0 (Standard open-source terms, viral)

2. PAID/TRIAL COMMERCIAL USERS (Businesses)
   - Trial: 30 day free trial begins on first commercial use.
   - Post-trial, a paid agreement is required to remain authorized.
     Contact James Han (jsh562@gmail.com) for licensing terms.

3. UNPAID COMMERCIAL USERS (Businesses using the software without a paid agreement, post-trial)
   - You elect to be bound exclusively by:
     a) Parity License 7.0.0 (open-source terms, viral)
     *Note: Requires you to open-source your entire software stack.*

* Hobbyists/Students: Free for non-commercial purposes, personal use.
* Commercial: 30-day trial period per organization. You must purchase a license to continue after the trial. Contact James Han (jsh562@gmail.com) for licensing.
* Contributors: Submitting a PR does not count as commercial use.

## Features

- **Accurate PQRST waveform** — pre-baked 1000-point Gaussian LUT for each P-wave, Q-dip, R-spike, S-dip, and T-wave.
- **Organic HRV jitter** — sine-wave time-warping for a natural, non-robotic heartbeat rhythm
- **Breathing baseline** — slow sinusoidal drift simulating respiratory movement
- **Zero per-frame allocations** — ring buffer + pre-baked paint list; paint() does no heap allocations
- **Phosphor trail fade** — pre-baked distance-to-paint LUT for instant colour lookup
- **Ambient screen flash** — subtle radial phosphor glow that follows the the cursor spikes
- **GPU-cached grid** — static ECG-paper background wrapped in `RepaintBoundary`
- **Theme-aware tip colour** — auto theme/black based on brightness, or overridable
- **Configurable** — Most features are configurable
- **Optimized** — Zero per-frame allocations, pre-baked paint list, GPU-cached grid, CPU & Memory, widgets, 

## Quick start

```dart
import 'package:flutter_ecg_monitor/flutter_ecg_monitor.dart';

EcgMonitor(
  height: 40,
  config: EcgMonitorConfig(
    heartRateBPM: 72,
    color: Colors.green,
  ),
)
```

## Configuration

All parameters live in `EcgMonitorConfig`:

| Parameter | Default | Description |
|---|---|---|
| `heartRateBPM` | 60.0 | Beats per minute |
| `beatDurationSeconds` | 0.35 | Duration of PQRST waveform |
| `cursorSpeedPixelsPerSecond` | 40.0 | Cursor travel speed (independent of screen width) |
| `lineThickness` | 1.0 | Trail line stroke width |
| `cursorThickness` | 1.0 | Cursor dot radius |
| `glowThickness` | 1.1 | Cursor glow halo radius |
| `beatSpikeAmplitude` | 8.0 | R-spike height in logical pixels |
| `gapMinPixels` | 15 | Minimum gap between cursor and trail |
| `gapMaxPixels` | 100 | Maximum gap (clamped) |
| `gridMinorSpacing` | 15.0 | Grid line spacing |
| `gridMajorEvery` | 5 | Major grid line every N minor lines |
| `breathingAmplitude` | 0.8 | Baseline breathing-wave amplitude |
| `breathsPerMinute` | 15.0 | Baseline breathing rate |
| `color` | `Color(0xFF00FF00)` | Trail base colour (dim end of gradient) |
| `tipColor` | null (auto) | Cursor tip colour (bright end); null = theme-derived |
a lot more ready to be configured but not exposed yet

## Advanced usage

The individual painters are exported for custom composition:

```dart
// Static grid only (put inside RepaintBoundary for performance)
CustomPaint(
  painter: EcgGridPainter(config: config, isDarkMode: true),
)

// Animated trail only
CustomPaint(
  painter: EcgTrailPainter(config: config, resolvedTipColor: Colors.white),
)
```

## TODO
- [ ] Add a way to configure more variability of the beat
- [ ] Add a way to receive/plug in input data (e.g. from a sensor or mock data)
- [ ] Add more configuration options
- [ ] Add more examples
- [ ] Add more documentation