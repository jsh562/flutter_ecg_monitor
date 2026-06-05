// (c) 2026 James Han. All rights reserved.
// Distributed under the Han Conditional Fair Source (HCFS) v1.0.
// See LICENSE file in the root directory for full terms.

import 'package:flutter/material.dart';
import 'ecg_monitor_config.dart';
import 'ecg_grid_painter.dart';
import 'ecg_trail_painter.dart';

/// A drop-in animated ECG / heartbeat-monitor widget.
///
/// Renders a moving phosphor-dot cursor that draws an authentic PQRST
/// waveform trail behind it, exactly like a real bedside cardiac monitor.
///
/// ## Quick start
/// ```dart
/// EcgMonitor(
///   height: 40,
///   config: EcgMonitorConfig(
///     heartRateBPM: 72,
///     color: Colors.green,
///   ),
/// )
/// ```
///
/// ## Architecture overview
/// The widget is composed of two stacked [CustomPaint] layers:
/// 1. **[EcgGridPainter]** — static ECG-paper grid, wrapped in [RepaintBoundary]
///    so the GPU can cache it and skip redraws on every animation tick.
/// 2. **[EcgTrailPainter]** — animated trail + cursor.  Uses a ring buffer
///    and pre-baked LUTs so the paint() call does zero heap allocations.
///
/// The [AnimationController] drives repaint at the display refresh rate; it
/// does not affect timing — beat timing uses [DateTime.now] so it is always
/// wall-clock accurate regardless of frame rate.
class EcgMonitor extends StatefulWidget {
  // Visual / timing configuration. See [EcgMonitorConfig] for all options.
  final EcgMonitorConfig config;

  // Height of the widget in logical pixels.
  final double height;

  const EcgMonitor({
    super.key,
    this.height = 40.0,
    this.config = const EcgMonitorConfig(),
  });

  @override
  State<EcgMonitor> createState() => _EcgMonitorState();
}

/// State class for the ECG monitor widget
class _EcgMonitorState extends State<EcgMonitor>
    with SingleTickerProviderStateMixin {
  // Animation controller for the cursor movement
  late final AnimationController _controller;

  // Last input color to check if we need to recalculate the tip color
  Color? _lastInputColor;

  // Last isDark value to check if we need to recalculate the tip color
  bool? _lastIsDark;

  // Cached tip color to avoid recalculation
  late Color _cachedTipColor;

  // Optimized tip color calculation with caching
  // Returns cached color if nothing changed, otherwise recalculates and caches
  Color _getOptimizedTipColor(Color source, bool isDark) {
    // If nothing changed, return the cached version instantly (Zero Math, Zero Allocations)
    if (source == _lastInputColor && isDark == _lastIsDark) {
      return _cachedTipColor;
    }

    // Update cache trackers
    _lastInputColor = source;
    _lastIsDark = isDark;

    // Perform the expensive calculation ONLY when necessary
    if (isDark) {
      _cachedTipColor = const Color(0xFFFFFFFF); // Use const for white
    } else {
      _cachedTipColor = HSLColor.fromColor(source)
          .withLightness(0.7)
          .withSaturation(1.0)
          .toColor();
    }

    return _cachedTipColor;
  }

  // Initialize the animation controller
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  // Dispose the animation controller
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Build the widget
  @override
  Widget build(BuildContext context) {
    // "Bare Metal" Brightness check (Zero overhead)
    final isDark = View.of(context).platformDispatcher.platformBrightness ==
        Brightness.dark;

    // Get configuration
    final config = widget.config;

    // Memoized color calculation (Remains highly efficient)
    final tipColor =
        config.tipColor ?? _getOptimizedTipColor(config.color, isDark);

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // LAYER 1: The Static Background
          // We put this OUTSIDE the AnimatedBuilder so it is never visited by the ticker
          RepaintBoundary(
            child: CustomPaint(
              painter: EcgGridPainter(
                config: config,
                isDarkMode: isDark,
              ),
              size: Size.infinite,
            ),
          ),

          // LAYER 2: The Animated trail + cursor
          // ONLY the trail is wrapped in the builder
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: EcgTrailPainter(
                  config: config,
                  resolvedTipColor: tipColor,
                  elapsedMicroseconds:
                      _controller.lastElapsedDuration?.inMicroseconds ?? 0,
                ),
                size: Size.infinite,
                willChange: true,
                isComplex: false,
              );
            },
          ),
        ],
      ),
    );
  }
}
