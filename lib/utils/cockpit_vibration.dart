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
      Platform.isAndroid || Platform.isIOS;

  /// 🔁 ENTRY POINT
  static Future<void> onPhaseChange(GroundPhase phase) async {
    if (!_supported) return;
    if (_lastPhase == phase) return;

    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    // Stop any existing rumble
    _stopRumble();

    switch (phase) {
      case GroundPhase.parked:
        // 🅿️ full silence
        break;

      case GroundPhase.taxi:
        _startRumble(
          intervalMs: 600,
          durationMs: 35,
          amplitude: 70,
        );
        break;

      case GroundPhase.roll:
        _startRumble(
          intervalMs: 220,
          durationMs: 50,
          amplitude: 140,
        );
        break;

      case GroundPhase.airborne:
        _startRumble(
          intervalMs: 900,
          durationMs: 25,
          amplitude: 50,
        );
        break;
    }

    _lastPhase = phase;
    debugPrint('🧠 CockpitVibration → $phase');
  }

  /// 🌊 CONTINUOUS SAFE RUMBLE
  static void _startRumble({
    required int intervalMs,
    required int durationMs,
    required int amplitude,
  }) {
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

  /// 🛑 STOP EVERYTHING
  static void _stopRumble() {
    _rumbleTimer?.cancel();
    _rumbleTimer = null;
    Vibration.cancel();
  }

  /// 🌬 TURBULENCE OVERLAY (burst-based, safe)
  static Future<void> onTurbulence(TurbulenceLevel level) async {
    if (!_supported) return;
    if (!(await Vibration.hasVibrator() ?? false)) return;

    switch (level) {
      case TurbulenceLevel.none:
        break;

      case TurbulenceLevel.light:
        Vibration.vibrate(duration: 40, amplitude: 100);
        break;

      case TurbulenceLevel.moderate:
        Vibration.vibrate(pattern: [0, 40, 40, 40]);
        break;

      case TurbulenceLevel.severe:
        Vibration.vibrate(pattern: [0, 60, 40, 60, 40, 60]);
        break;
    }
  }
}
