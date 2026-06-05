// (c) 2026 James Han. All rights reserved.
// Distributed under the Han Conditional Fair Source (HCFS) v1.0.
// See LICENSE file in the root directory for full terms.

import 'package:flutter/material.dart';

/// All tunable parameters for [EcgMonitor] in one immutable config object.
///
/// Pass this to [EcgMonitor] to control every visual aspect of the widget.
///
/// ## Architecture note
/// Keeping params in a single value-object makes it easy to expose a
/// copyWith / compare pattern and to pass the same config to multiple widgets.
class EcgMonitorConfig {
  // ── Timing ──────────────────────────────────────────────────────────────────

  // Beats per minute — controls how often the QRS spike fires.
  final double heartRateBPM;

  // How many seconds the full PQRST waveform lasts (0.0–secondsPerBeat).
  final double beatDurationSeconds;

  // How many pixels the cursor advances every second (independent of width).
  final double cursorSpeedPixelsPerSecond;

  // ── Visual — lines ───────────────────────────────────────────────────────────

  // Thickness of the ECG trail line.
  final double lineThickness;

  // Radius of the cursor dot.
  final double cursorThickness;

  // Radius of the cursor glow halo.
  final double glowThickness;

  // Amplitude of the ECG spike in logical pixels.
  final double beatSpikeAmplitude;

  // ── Visual — gap & fade ──────────────────────────────────────────────────────

  // Minimum gap in pixels between cursor and the start of the visible trail.
  final int gapMinPixels;

  // Maximum gap in pixels (clamped upper bound).
  final int gapMaxPixels;

  // ── Visual — ECG grid background ─────────────────────────────────────────────

  // Spacing in logical pixels between minor grid lines.
  final double gridMinorSpacing;

  // Every Nth minor line is drawn as a major (brighter) line.
  final int gridMajorEvery;

  // ── Breathing baseline ───────────────────────────────────────────────────────

  // Amplitude of the slow breathing-wave that moves the baseline.
  final double breathingAmplitude;

  // Breaths per minute for the baseline breathing wave.
  final double breathsPerMinute;

  // ── Colors ──────────────────────────────────────────────────────────────────

  // Base ECG line color (dim end of the trail gradient).
  final Color color;

  // Tip/cursor color (bright end of the trail gradient).
  // If null, it is derived from brightness at build-time (white / black87).
  final Color? tipColor;

  // Constructor for the ECG monitor configuration
  const EcgMonitorConfig({
    // Heart rate in beats per minute
    this.heartRateBPM = 60.0,

    // Duration of a single heartbeat in seconds
    this.beatDurationSeconds = 0.35,

    // Speed of the cursor in pixels per second
    this.cursorSpeedPixelsPerSecond = 40.0,

    // Thickness of the ECG line
    this.lineThickness = 1.0,

    // Thickness of the cursor
    this.cursorThickness = 1.0,

    // Thickness of the glow around the cursor
    this.glowThickness = 1.1,

    // Amplitude of the heartbeat spike
    this.beatSpikeAmplitude = 8.0,

    // Minimum gap in pixels between beats
    this.gapMinPixels = 15,

    // Maximum gap in pixels between beats
    this.gapMaxPixels = 100,

    // Spacing in logical pixels between minor grid lines
    this.gridMinorSpacing = 15.0,

    // Every Nth minor line is drawn as a major (brighter) line
    this.gridMajorEvery = 5,

    // Amplitude of the slow breathing-wave that moves the baseline
    this.breathingAmplitude = 0.8,

    // Breaths per minute for the baseline breathing wave
    this.breathsPerMinute = 15.0,

    // Base ECG line color (dim end of the trail gradient)
    this.color = const Color(0xFF00FF00),

    // Tip/cursor color (bright end of the trail gradient)
    this.tipColor,
  });

  // Create a copy of this config with some fields overridden
  EcgMonitorConfig copyWith({
    // Heart rate in beats per minute
    double? heartRateBPM,

    // Duration of a single heartbeat in seconds
    double? beatDurationSeconds,

    // Speed of the cursor in pixels per second
    double? cursorSpeedPixelsPerSecond,

    // Thickness of the ECG line
    double? lineThickness,

    // Thickness of the cursor
    double? cursorThickness,

    // Thickness of the glow around the cursor
    double? glowThickness,

    // Amplitude of the heartbeat spike
    double? beatSpikeAmplitude,

    // Minimum gap in pixels between beats
    int? gapMinPixels,

    // Maximum gap in pixels between beats
    int? gapMaxPixels,

    // Spacing in logical pixels between minor grid lines
    double? gridMinorSpacing,

    // Every Nth minor line is drawn as a major (brighter) line
    int? gridMajorEvery,

    // Amplitude of the slow breathing-wave that moves the baseline
    double? breathingAmplitude,

    // Breaths per minute for the baseline breathing wave
    double? breathsPerMinute,

    // Base ECG line color (dim end of the trail gradient)
    Color? color,

    // Tip/cursor color (bright end of the trail gradient)
    Color? tipColor,
  }) {
    return EcgMonitorConfig(
      // Heart rate in beats per minute
      heartRateBPM: heartRateBPM ?? this.heartRateBPM,

      // Duration of a single heartbeat in seconds
      beatDurationSeconds: beatDurationSeconds ?? this.beatDurationSeconds,

      // Speed of the cursor in pixels per second
      cursorSpeedPixelsPerSecond:
          cursorSpeedPixelsPerSecond ?? this.cursorSpeedPixelsPerSecond,

      // Thickness of the ECG line
      lineThickness: lineThickness ?? this.lineThickness,

      // Thickness of the cursor
      cursorThickness: cursorThickness ?? this.cursorThickness,

      // Thickness of the glow around the cursor
      glowThickness: glowThickness ?? this.glowThickness,

      // Amplitude of the heartbeat spike
      beatSpikeAmplitude: beatSpikeAmplitude ?? this.beatSpikeAmplitude,

      // Minimum gap in pixels between beats
      gapMinPixels: gapMinPixels ?? this.gapMinPixels,

      // Maximum gap in pixels between beats
      gapMaxPixels: gapMaxPixels ?? this.gapMaxPixels,

      // Spacing in logical pixels between minor grid lines
      gridMinorSpacing: gridMinorSpacing ?? this.gridMinorSpacing,

      // Every Nth minor line is drawn as a major (brighter) line
      gridMajorEvery: gridMajorEvery ?? this.gridMajorEvery,

      // Amplitude of the slow breathing-wave that moves the baseline
      breathingAmplitude: breathingAmplitude ?? this.breathingAmplitude,

      // Breaths per minute for the baseline breathing wave
      breathsPerMinute: breathsPerMinute ?? this.breathsPerMinute,

      // Base ECG line color (dim end of the trail gradient)
      color: color ?? this.color,

      // Tip/cursor color (bright end of the trail gradient)
      tipColor: tipColor ?? this.tipColor,
    );
  }
}
