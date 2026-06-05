// (c) 2026 James Han. All rights reserved.
// Distributed under the Han Conditional Fair Source (HCFS) v1.0.
// See LICENSE file in the root directory for full terms.

/// flutter_ecg_monitor
///
/// A realistic animated ECG / heartbeat-monitor widget.
///
/// ## Public API
/// - [EcgMonitor]            — the drop-in widget
/// - [EcgMonitorConfig]      — all tunable parameters in one place
/// - [EcgGridPainter]        — static ECG-paper background (exported for advanced use)
/// - [EcgTrailPainter]       — the animated trail painter (exported for advanced use)
library flutter_ecg_monitor;

export 'src/ecg_monitor.dart';
export 'src/ecg_monitor_config.dart';
export 'src/ecg_grid_painter.dart';
export 'src/ecg_trail_painter.dart';
