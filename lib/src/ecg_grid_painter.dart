// (c) 2026 James Han. All rights reserved.
// Distributed under the Han Conditional Fair Source (HCFS) v1.0.
// See LICENSE file in the root directory for full terms.

import 'package:flutter/material.dart';
import 'ecg_monitor_config.dart';

/// Draws the static ECG-paper grid background.
///
/// This painter is intended to be wrapped in a [RepaintBoundary] so Flutter
/// can cache it on the GPU and skip redrawing it every animation frame.
///
/// Grid pattern: minor lines every [EcgMonitorConfig.gridMinorSpacing] px,
/// major (brighter) line every [EcgMonitorConfig.gridMajorEvery] minor lines.
class EcgGridPainter extends CustomPainter {
  // Configuration for the ECG monitor
  final EcgMonitorConfig config;

  // Whether the app is in dark mode
  final bool isDarkMode;

  // Constructor for the ECG grid painter
  const EcgGridPainter({required this.config, required this.isDarkMode});

  // Paint the grid on the canvas
  @override
  void paint(Canvas canvas, Size size) {
    // Set up paints based on dark mode
    final minorPaint = Paint()
      ..color = config.color.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    // Major paint
    final majorPaint = Paint()
      ..color = config.color.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    // Spacing
    final spacing = config.gridMinorSpacing;

    // Major every
    final every = config.gridMajorEvery;

    // --- Vertical lines ---
    int vCounter = 0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        vCounter == 0 ? majorPaint : minorPaint,
      );
      vCounter = (vCounter + 1) % every;
    }

    // --- Horizontal lines ---
    int hCounter = 0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        hCounter == 0 ? majorPaint : minorPaint,
      );
      hCounter = (hCounter + 1) % every;
    }
  }

  // Determine if the painter should repaint
  @override
  bool shouldRepaint(covariant EcgGridPainter old) =>
      old.config.color != config.color ||
      old.config.gridMinorSpacing != config.gridMinorSpacing ||
      old.config.gridMajorEvery != config.gridMajorEvery ||
      old.isDarkMode != isDarkMode;
}
