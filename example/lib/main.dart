import 'package:flutter/material.dart';
import 'package:flutter_ecg_monitor/flutter_ecg_monitor.dart';

void main() => runApp(const EcgExampleApp());

class EcgExampleApp extends StatelessWidget {
  const EcgExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Monitor Example',
      theme: ThemeData.dark(),
      home: const EcgDemoScreen(),
    );
  }
}

class EcgDemoScreen extends StatelessWidget {
  const EcgDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('flutter_ecg_monitor')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Resting (60 BPM)',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            EcgMonitor(
              height: 60,
              config: const EcgMonitorConfig(
                heartRateBPM: 60,
                color: Color(0xFF00FF88),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Elevated (100 BPM)',
                style: TextStyle(color: Color.fromARGB(255, 255, 0, 0))),
            const SizedBox(height: 8),
            EcgMonitor(
              height: 60,
              config: const EcgMonitorConfig(
                heartRateBPM: 100,
                cursorSpeedPixelsPerSecond: 60,
                color: Color(0xFFFFAA00),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Bradycardia (27 BPM)',
                style: TextStyle(color: Color.fromARGB(255, 0, 102, 255))),
            const SizedBox(height: 8),
            EcgMonitor(
              height: 60,
              config: const EcgMonitorConfig(
                heartRateBPM: 27,
                beatDurationSeconds: 0.8,
                color: Color(0xFF4488FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
