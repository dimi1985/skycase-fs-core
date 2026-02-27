import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DistanceTracker {
  static const String _key = "persistent_distance";
  static double _totalKm = 0.0;
  static LatLng? _lastPoint;
  static bool _active = false;

  // Distance calc
  static const Distance _dist = Distance();

  /// Load stored state on app start
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;

    try {
      final json = jsonDecode(raw);
      _totalKm = (json['km'] as num).toDouble();

      if (json['last'] != null) {
        _lastPoint = LatLng(
          json['last']['lat'],
          json['last']['lng'],
        );
      }
    } catch (_) {}
  }

  /// Start tracking — DOES NOT reset. Only enables calculation.
  static void start() {
    _active = true;
  }

  /// Reset distance and last point — use ONLY on NEW FLIGHT start.
  static Future<void> reset() async {
    _active = true;
    _totalKm = 0.0;
    _lastPoint = null;
    await _save();
  }

  /// Feed a new live location every sim tick.
  static Future<void> feed(LatLng p) async {
    if (!_active) return;

    // First ever point
    if (_lastPoint == null) {
      _lastPoint = p;
      await _save();
      return;
    }

    // Compute movement
    final meters = _dist.as(LengthUnit.Meter, _lastPoint!, p);

    // Noise filter
    if (meters >= 0.5) {
      _totalKm += (meters / 1000.0);
      _lastPoint = p;
      await _save();
    }
  }

  /// Get current NM
  static double getNm() => _totalKm * 0.539957;

  /// Finalize/stop without clearing
  static void stop() {
    _active = false;
  }

  /// Persist current state
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        "km": _totalKm,
        "last": _lastPoint == null
            ? null
            : {
                "lat": _lastPoint!.latitude,
                "lng": _lastPoint!.longitude,
              }
      }),
    );
  }
}
