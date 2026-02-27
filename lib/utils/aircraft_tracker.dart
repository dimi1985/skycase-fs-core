import 'package:shared_preferences/shared_preferences.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/services/aircraft_service.dart';

class AircraftTracker {
  // ============================================================
  // RUNTIME CACHE (fast, in-memory)
  // ============================================================
  static String? _lastAircraftId;
  static String? _lastAircraftUuid;
  static DateTime? _lastChangeTime;

  static const _debounceSeconds = 2;

  // ============================================================
  // UPDATE FROM TELEMETRY
  // ============================================================
  /// Called on every SimLink frame.
  /// Saves aircraft ONLY when it truly changes.
  // ============================================================
  static Future<void> updateFromTelemetry(SimLinkData d) async {
    final title = d.title.trim();
    if (title.isEmpty || title == "—") return;

    final aircraftId = _normalizeAircraftId(title);
    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();

    // ------------------------------------------------------------
    // Restore cached state ONCE (cold start safe)
    // ------------------------------------------------------------
    _lastAircraftId ??= prefs.getString("current_aircraft_id");
    _lastAircraftUuid ??= prefs.getString("current_aircraft_uuid");

    // Always expose current aircraftId for UI
    await prefs.setString("current_aircraft_id", aircraftId);

    // ------------------------------------------------------------
    // Same aircraft → hard stop
    // ------------------------------------------------------------
    if (_lastAircraftId == aircraftId) return;

    // ------------------------------------------------------------
    // Debounce SimLink hiccups / reload spam
    // ------------------------------------------------------------
    if (_lastChangeTime != null &&
        now.difference(_lastChangeTime!).inSeconds < _debounceSeconds) {
      return;
    }

    _lastChangeTime = now;
    _lastAircraftId = aircraftId;

    print("✈️ AircraftTracker → NEW aircraft detected: $aircraftId");

    // ------------------------------------------------------------
    // Build payload for backend
    // ------------------------------------------------------------
    final aircraft = LearnedAircraft(
      id: aircraftId,
      title: title,

      emptyWeight: d.weights.emptyWeight,
      mtow: d.weights.maxTakeoffWeight,
      mzfw: d.weights.maxZeroFuelWeight,
      mlgw: d.weights.maxGrossWeight,

      fuelCapacityGallons: d.fuelCapacityGallons,

      retractable: d.gear.retractable,
      floats: d.gear.floats,
      skids: d.gear.skids,
      skis: d.gear.skis,
      wheels: d.gear.wheels,

      updatedAt: now,
    );

    // ------------------------------------------------------------
    // Persist ONLY on change
    // ------------------------------------------------------------
    final saved = await AircraftService.saveAircraft(aircraft);

    if (saved == null) {
      print("⚠️ AircraftTracker → save failed");
      return;
    }

    // ------------------------------------------------------------
    // Lock UUID once (never changes)
    // ------------------------------------------------------------
    if (saved.aircraftUuid != null &&
        saved.aircraftUuid != _lastAircraftUuid) {
      _lastAircraftUuid = saved.aircraftUuid;

      await prefs.setString(
        "current_aircraft_uuid",
        saved.aircraftUuid!,
      );

      print("🔐 Aircraft UUID locked → ${saved.aircraftUuid}");
    }

    print("💾 AircraftTracker → aircraft saved ($aircraftId)");
  }

  // ============================================================
  // HELPERS
  // ============================================================
  static String _normalizeAircraftId(String title) {
    return title.toLowerCase().replaceAll(RegExp(r"\s+"), "_");
  }

  /// Optional: fuel burn estimate (future use)
  static double estimateFuelBurn(SimLinkData d) {
    try {
      if (d.rpm > 500 && d.airspeed > 20) {
        return (d.rpm / 1000) * 5;
      }
    } catch (_) {}
    return 8.0;
  }
}
