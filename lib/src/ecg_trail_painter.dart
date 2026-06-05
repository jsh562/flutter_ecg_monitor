// (c) 2026 James Han. All rights reserved.
// Distributed under the Han Conditional Fair Source (HCFS) v1.0.
// See LICENSE file in the root directory for full terms.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'ecg_monitor_config.dart';

/// Animated ECG trail painter.
///
/// ## Architecture — zero per-frame allocations
/// - **Ring buffer** (`_trailBuffer`): a `Float64List` of length == screen width
///   storing the Y-position for every X pixel. Written to each frame, read
///   during draw. `double.nan` marks an empty / gap slot.
/// - **Heartbeat LUT** (`_heartbeatLUT`): 1000-element pre-computed PQRST shape
///   built once at class load time.  Indexed by beat-progress (0.0–1.0).
/// - **Distance-to-paint LUT** (`_distanceToPaintLUT`): maps integer pixel
///   distance-behind-cursor → paint bucket index (0–99). Rebuilt only when
///   screen width changes.
/// - **Pre-built paint lists** (`_corePaints`, `_glowPaints`): 100 Paint
///   objects covering the full dim-to-bright gradient, built once in the
///   constructor.  During draw we just index into these lists.
class EcgTrailPainter extends CustomPainter {
  // Configuration for the ECG monitor
  final EcgMonitorConfig config;

  // Resolved tip color (calculated from config.color and brightness)
  final Color resolvedTipColor;

  // Elapsed microseconds since the animation started
  final int elapsedMicroseconds;

  // 1. THE RANDOM FIX: Shared PRNG to prevent frame-by-frame allocation
  static final _random = math.Random(42);

  // --- Pre-computed PQRST LUT (built once, shared across all instances) ---
  static final Float64List _heartbeatLUT = _buildHeartbeatLUT();

  // Builds the pre-computed PQRST LUT (1000 elements)
  static Float64List _buildHeartbeatLUT() {
    // Local buffer for the LUT
    final lut = Float64List(1000);

    // Gaussian helper — no math.pow needed
    double gaussian(double x, double a, double b, double c) {
      final d = x - b;
      return a * math.exp(-(d * d) / (2.0 * c * c));
    }

    for (int i = 0; i < 1000; i++) {
      // Progress through the heartbeat (0.0 to 1.0)
      final p = i / 1000.0;

      // Accumulated Y value for this point
      double y = 0.0;

      // P-Wave
      y += gaussian(p, 0.15, 0.15, 0.030);

      // Q-Dip
      y += gaussian(p, -0.15, 0.25, 0.015);

      // R-Spike (tall)
      y += gaussian(p, 1.20, 0.35, 0.020);

      // S-Dip
      y += gaussian(p, -0.40, 0.45, 0.020);

      // T-Wave
      y += gaussian(p, 0.35, 0.70, 0.060);
      lut[i] = y;
    }
    return lut;
  }

  // --- Per-screen-width state (static so it survives painter recreation) ---
  static Float64List _trailBuffer = Float64List(0);

  // Distance-to-paint LUT: maps integer pixel distance → paint bucket index (0–99)
  static Int32List _distanceToPaintLUT = Int32List(0);

  // Last integer cursor X position (used to detect width changes)
  static int _lastIntCursorX = -1;

  // --- Per-instance paint lists (built in constructor, reused every frame) ---
  final List<Paint> _corePaints;

  // Glow paint list (100 paints for gradient)
  final List<Paint> _glowPaints;

  // Cursor glow paint
  final Paint _cursorGlowPaint;

  // Cursor core paint
  final Paint _cursorCorePaint;

  // Flash paint
  final Paint _flashPaint;

  // Breath frequency (radians per second)
  final double _breathFreq;

  // Seconds per beat
  final double _secondsPerBeat;

  // Inverse of beat duration (for fast multiplication)
  final double _invBeatDuration;

  // Constructor for the ECG trail painter
  EcgTrailPainter({
    required this.config,
    required this.resolvedTipColor,
    required this.elapsedMicroseconds,
  })  : _corePaints = _buildPaints(
          config.color,
          resolvedTipColor,
          config.lineThickness,
          0.9,
        ),
        _glowPaints = _buildPaints(
          config.color,
          resolvedTipColor,
          config.glowThickness * 2.0,
          0.3,
        ),

        // Breath frequency (radians per second)
        _breathFreq = (2.0 * math.pi) * (config.breathsPerMinute / 60.0),

        // Seconds per beat
        _secondsPerBeat = 60.0 / config.heartRateBPM,

        // Inverse of beat duration (for fast multiplication)
        _invBeatDuration = 1.0 / config.beatDurationSeconds,

        // Pre-allocate the cursor and flash paints to prevent GC jitter
        _cursorGlowPaint = Paint()
          ..color = config.color.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill,
        _cursorCorePaint = Paint()
          ..color = resolvedTipColor.withValues(alpha: 1.0)
          ..style = PaintingStyle.fill,
        _flashPaint = Paint();

  // Builds 100 Paint objects from dim (index 0) to bright (index 99).
  static List<Paint> _buildPaints(
    Color from,
    Color to,
    double strokeWidth,
    double maxAlpha,
  ) {
    return List.generate(100, (i) {
      // Intensity (0.0 to 1.0)
      final intensity = i / 99.0;

      // Heat (cubic for smoother gradient)
      final heat = intensity * intensity * intensity;

      // Opacity (cubic for smoother fade)
      final opacity = intensity * intensity * maxAlpha;
      return Paint()
        ..color = Color.lerp(from, to, heat)!.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
    });
  }

  // ---------------------------------------------------------------------------
  // paint()
  // ---------------------------------------------------------------------------
  ///
  // X coordinates lookup table
  static Float64List _xCoordsLUT = Float64List(0);

  // Paint the trail on the canvas
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Local variable hoisting for L1 CPU cache speed
    final width = size.width;

    // Integer width (for array indexing)
    final intWidth = width.toInt();

    // Center Y position
    final centerY = size.height / 2;

    // Configuration reference
    final cfg = config;

    // Gap in pixels between cursor dot and the start of the visible trail.
    final int gapDistance =
        (width * 0.08).round().clamp(cfg.gapMinPixels, cfg.gapMaxPixels);

    // --- Rebuild ring buffer & distance LUT when screen width changes ---
    if (_trailBuffer.length != intWidth) {
      // Allocate new buffers
      _trailBuffer = Float64List(intWidth);

      // Distance to paint lookup table
      _distanceToPaintLUT = Int32List(intWidth);

      // X coordinates lookup table
      _xCoordsLUT = Float64List(intWidth);

      // Calculate max visible distance
      final double maxVisible = intWidth - gapDistance.toDouble();

      // Inverse of max visible distance
      final double invMax = 1.0 / maxVisible;

      for (int i = 0; i < intWidth; i++) {
        // Initialize trail buffer with NaN
        _trailBuffer[i] = double.nan;

        // X coordinates lookup table
        _xCoordsLUT[i] = i.toDouble();

        // Distance to paint lookup table
        if (i >= maxVisible) {
          _distanceToPaintLUT[i] = 0;
        } else {
          _distanceToPaintLUT[i] =
              ((1.0 - i * invMax) * 99).toInt().clamp(0, 99);
        }
      }
      _lastIntCursorX = -1;
    }

    // --- Cursor X position (Synced natively to Flutter Engine Ticker) ---
    final nowSeconds = elapsedMicroseconds / 1000000.0;

    // Cursor X position
    final cursorX = (nowSeconds * cfg.cursorSpeedPixelsPerSecond) % width;

    // Integer cursor X position
    final intCursorX = cursorX.toInt();

    // --- 3. Fill any pixels skipped since the last frame (No Modulo) ---
    if (_lastIntCursorX != -1 && intCursorX != _lastIntCursorX) {
      // Seconds per pixel
      final double secondsPerPixel = 1.0 / cfg.cursorSpeedPixelsPerSecond;

      // Start index after last cursor position
      int i = _lastIntCursorX + 1;
      if (i >= intWidth) i = 0;

      // Safety counter to prevent infinite loop
      int safety = 0;
      while (i != intCursorX && safety < intWidth) {
        // Calculate distance behind cursor
        int behind = intCursorX - i;
        if (behind < 0) behind += intWidth;
        _trailBuffer[i] =
            _yForTime(nowSeconds - behind * secondsPerPixel, centerY);
        //i = (i + 1) % intWidth;
        if (++i >= intWidth) i = 0;
        safety++;
      }
    }

    // --- Write current cursor position ---
    final double cursorY = _yForTime(nowSeconds, centerY);
    _trailBuffer[intCursorX] = cursorY;

    // --- Erase gap zone ahead of cursor ---
    // int del = (intCursorX + 1) % intWidth;
    int del = intCursorX + 1;
    if (del >= intWidth) del = 0;
    for (int k = 0; k < gapDistance + 5; k++) {
      _trailBuffer[del] = double.nan;
      //del = (del + 1) % intWidth;
      if (++del >= intWidth) del = 0;
    }

    // --- Ambient flash when cursor is off-baseline ---
    final double intensity =
        (cursorY - centerY).abs() / (cfg.beatSpikeAmplitude * 2.0);

    // Calculate flash alpha
    final double flashAlpha = intensity.clamp(0.0, 0.15);
    if (flashAlpha > 0.01) {
      // Direct dart:ui Shader assignment - bypasses Flutter Widget layer allocations
      // Use ui.Gradient (low-level) to avoid conflict with Material's Gradient
      _flashPaint.shader = ui.Gradient.radial(
        Offset(cursorX, cursorY),
        size.height * 2.5,
        [resolvedTipColor.withValues(alpha: flashAlpha), Colors.transparent],
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, width, size.height), _flashPaint);
    }

    // --- 5. Draw fading trail (Zero Allocations & Bounds Check Elision) ---
    for (int x = 1; x < _trailBuffer.length; x++) {
      // Get current and previous Y values
      final double y = _trailBuffer[x];

      // Get previous Y value
      final double py = _trailBuffer[x - 1];

      // Skip if either value is NaN
      if (y.isNaN || py.isNaN) continue;

      // Calculate distance from cursor
      int dist = intCursorX - x;
      if (dist < 0) dist += intWidth;

      // Get paint index and coordinates
      final int pi = _distanceToPaintLUT[dist];

      // Get X coordinates
      final double fx = _xCoordsLUT[x];

      // Get previous X coordinate
      final double pfx = _xCoordsLUT[x - 1];

      // Draw glow lines
      canvas.drawLine(Offset(pfx, py), Offset(fx, y), _glowPaints[pi]);

      // Draw core line
      canvas.drawLine(Offset(pfx, py), Offset(fx, y), _corePaints[pi]);
    }

    // --- Cursor dot (Cached Paints) ---
    if (cursorX >= 0 && cursorX <= width) {
      canvas.drawCircle(
          Offset(cursorX, cursorY), cfg.glowThickness * 1.5, _cursorGlowPaint);
      canvas.drawCircle(
          Offset(cursorX, cursorY), cfg.cursorThickness, _cursorCorePaint);
    }

    // Track cursor for next frame
    _lastIntCursorX = intCursorX;
  }

  // Computes the Y value for a given absolute time (used for history fill).
  // We pass in centerY because it's a layout-dependent variable from the paint() method
  double _yForTime(double t, double centerY) {
    // HRV: slightly warp time to feel organic
    final organic = t + (math.sin(t * 0.4) + math.sin(t * 0.7)) * 0.15;

    // Calculate cycle time
    final cycle = organic % _secondsPerBeat;
    //final beating = cycle < cfg.beatDurationSeconds;
    //// Instead of final p = beating ? (cycle / cfg.beatDurationSeconds) : 0.0;
    //final p = beating ? (cycle * _invBeatDuration) : 0.0;
    //if (p > 0.0) {
    //  final index = (p * 999).toInt();
    //  return centerY - (_heartbeatLUT[index] * cfg.beatSpikeAmplitude);
    //}

    if (cycle < config.beatDurationSeconds) {
      // Calculate progress through beat
      final p = cycle * _invBeatDuration; // Fast multiplication!
      // Get lookup table index
      final index = (p * 999).toInt();

      // Return Y value
      return centerY - (_heartbeatLUT[index] * config.beatSpikeAmplitude);
    }

    // Baseline + breathing wave + tiny jitter
    final noise = _random.nextDouble() * 2.0 - 1.0;
    return centerY +
        math.sin(t * _breathFreq) * config.breathingAmplitude +
        noise * 0.5;
  }

  // ---------------------------------------------------------------------------
  // shouldRepaint()
  // ---------------------------------------------------------------------------
  ///
  // Always return true to ensure continuous animation
  @override
  bool shouldRepaint(covariant EcgTrailPainter old) => true; // Always animate
}
