import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:skycase/models/ground_phase.dart';

enum TurbulenceLevel { none, light, moderate, severe }

class CockpitVibration {
  static GroundPhase? _lastPhase;
  static Timer? _rumbleTimer;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> onPhaseChange(GroundPhase phase) async {
    if (!_supported) return;
    if (_lastPhase == phase) return;

    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    _stopRumble();

    switch (phase) {
      case GroundPhase.pushback:
        _startRumble(
          intervalMs: 950,
          durationMs: 45,
          amplitude: 80,
        );
        break;

      case GroundPhase.taxi:
        _startRumble(
          intervalMs: 700,
          durationMs: 28,
          amplitude: 55,
        );
        break;

      case GroundPhase.stopped:
        // silence
        break;

      case GroundPhase.takeoff:
        _startRumble(
          intervalMs: 180,
          durationMs: 45,
          amplitude: 130,
        );
        break;

      case GroundPhase.airborne:
        // no continuous rumble
        break;

      case GroundPhase.landed:
        _startBurst([0, 50, 45, 50]);
        break;

      case GroundPhase.parked:
        // silence
        break;
    }

    _lastPhase = phase;
    debugPrint('🧠 CockpitVibration → $phase');
  }

  static void _startRumble({
    required int intervalMs,
    required int durationMs,
    required int amplitude,
  }) {
    _rumbleTimer?.cancel();
    _rumbleTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) {
        Vibration.vibrate(
          duration: durationMs,
          amplitude: amplitude,
        );
      },
    );
  }

  static void _startBurst(List<int> pattern) {
    Vibration.vibrate(pattern: pattern);
  }

  static void _stopRumble() {
    _rumbleTimer?.cancel();
    _rumbleTimer = null;
    Vibration.cancel();
  }

  static Future<void> onTurbulence(TurbulenceLevel level) async {
    if (!_supported) return;

    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    switch (level) {
      case TurbulenceLevel.none:
        break;

      case TurbulenceLevel.light:
        Vibration.vibrate(duration: 35, amplitude: 90);
        break;

      case TurbulenceLevel.moderate:
        Vibration.vibrate(pattern: [0, 35, 30, 35]);
        break;

      case TurbulenceLevel.severe:
        Vibration.vibrate(pattern: [0, 55, 35, 55, 35, 55]);
        break;
    }
  }

  static void dispose() {
    _stopRumble();
    _lastPhase = null;
  }
}