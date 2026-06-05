# Migration from zigzag_gap_line.dart to flutter_ecg_monitor package

## What Was Moved

The heartbeat monitor display logic was extracted from `lib/screens/zigzag_gap_line.dart` into a standalone Flutter package at `packages/flutter_ecg_monitor/`.

### Code Removed from zigzag_gap_line.dart

**Total lines deleted: ~450**

1. **`_StaticBackgroundPainter` class** (lines 38-114)
   - Static ECG-paper grid background
   - Now: `EcgGridPainter` in package

2. **Heartbeat-specific static members in `_GapLinePainter`**:
   - `_heartbeatLUT` + `_precomputeHeartbeat()` — PQRST waveform lookup table
   - `_trailBuffer` — ring buffer for trail storage
   - `_distanceToPaintLUT` — pre-baked distance-to-paint-index mapping
   - `_corePaints`, `_glowPaints` — pre-built paint lists
   - `_lastCursorX`, `_lastIntCursorX` — cursor tracking state

3. **`_drawHeartbeatMonitor()` method** (~260 lines)
   - Entire heartbeat rendering logic
   - Now: `EcgTrailPainter.paint()` in package

4. **Unused imports**:
   - `dart:typed_data` (only used by deleted heartbeat code)

5. **Removed constructor parameters**:
   - `tipColor` from `_GapLinePainter` (only used by heartbeat)

### Code Added to Package

**New package structure:**

```
packages/flutter_ecg_monitor/
├── lib/
│   ├── flutter_ecg_monitor.dart          — barrel export
│   └── src/
│       ├── ecg_monitor_config.dart       — all tunable params
│       ├── ecg_monitor.dart              — EcgMonitor widget
│       ├── ecg_grid_painter.dart         — static grid (was _StaticBackgroundPainter)
│       └── ecg_trail_painter.dart        — trail + cursor (was _drawHeartbeatMonitor)
├── example/lib/main.dart                 — demo app
├── pubspec.yaml
├── README.md
└── ARCHITECTURE.md                       — optimization techniques documentation
```

## How zigzag_gap_line.dart Now Uses the Package

### Before (inline implementation)

```dart
// build() method created _GapLinePainter which called _drawHeartbeatMonitor()
return Stack([
  RepaintBoundary(child: CustomPaint(painter: _StaticBackgroundPainter(...))),
  CustomPaint(painter: _GapLinePainter(...)), // calls _drawHeartbeatMonitor
]);
```

### After (package delegation)

```dart
@override
Widget build(BuildContext context) {
  // Short-circuit for heartbeat style
  if (widget.style == GapVisualizationStyle.heartbeatMonitor) {
    return EcgMonitor(
      height: widget.height,
      config: EcgMonitorConfig(
        heartRateBPM: 27.0,
        beatDurationSeconds: 0.8,
        cursorSpeedPixelsPerSecond: 40.0,
        color: widget.color ?? CalendarGridTheme.subtleGrid(context),
      ),
    );
  }
  
  // Other styles still use _GapLinePainter
  return SizedBox(
    child: AnimatedBuilder(
      builder: (context, child) => CustomPaint(painter: _GapLinePainter(...)),
    ),
  );
}
```

The `case GapVisualizationStyle.heartbeatMonitor:` in `_GapLinePainter.paint()` is now unreachable (the build method returns early), but left as a comment for clarity.

## Benefits of Extraction

1. **Reusability** — `EcgMonitor` can be used in any Flutter app, not just where_when
2. **Separation of concerns** — Gap visualization styles vs ECG rendering are now independent
3. **Cleaner codebase** — Removed ~450 lines from zigzag_gap_line.dart
4. **Better documentation** — Package has dedicated README + ARCHITECTURE.md
5. **Independent versioning** — Package can be published to pub.dev separately
6. **Testability** — Package can have its own unit/widget tests

## Files Modified in where_when

- `lib/screens/zigzag_gap_line.dart` — removed heartbeat code, added package import + short-circuit
- `pubspec.yaml` — added `flutter_ecg_monitor: path: packages/flutter_ecg_monitor`

## Verification

Run `flutter pub get` to resolve the package dependency. The heartbeat monitor style should work identically to before the migration.
