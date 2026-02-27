import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:skycase/models/flight.dart';

class FlightPlanService {
  static const String base = "http://38.242.241.46:3000/api/flightplan";

  // =========================================================
  // 🔥 SAFELY LOAD CURRENT FLIGHT (with waypoints support)
  // =========================================================
  static Future<Flight?> getCurrentFlight(String userId) async {
    final uri = Uri.parse("$base/current/$userId");
    final res = await http.get(uri);

    if (res.statusCode != 200) return null;
    if (res.body.isEmpty) return null;
    if (res.body == "null") return null;

    final decoded = jsonDecode(res.body);

    if (decoded is! Map<String, dynamic>) return null;
    if (decoded.isEmpty) return null;

    if (decoded['originIcao'] == null || decoded['destinationIcao'] == null) {
      return null;
    }

    return Flight.fromJson(decoded);
  }

  // =========================================================
  // 🔥 SAVE FLIGHT PLAN (supports nullable waypoints)
  // =========================================================
  static Future<void> saveFlightPlan(Flight f, String userId) async {
    final uri = Uri.parse("$base/save");

    // ⭐ waypoints may be null OR a list — both allowed
    final body = {
      ...f.toJson(),
      "userId": userId,
    };

    await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
  }

  // =========================================================
  // 🔥 GET HISTORY (waypoint-compatible)
  // =========================================================
  static Future<List<Flight>> getHistory(String userId) async {
    final uri = Uri.parse("$base/history/$userId");
    final res = await http.get(uri);

    if (res.statusCode != 200) return [];
    if (res.body.isEmpty) return [];

    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];

    return decoded.map((e) => Flight.fromJson(e)).toList();
  }

  // =========================================================
  // 🔥 DELETE HISTORY ENTRY
  // =========================================================
  static Future<void> deleteHistory(String id) async {
    final uri = Uri.parse("$base/history/$id");
    await http.delete(uri);
  }

  // =========================================================
  // 🔥 DELETE CURRENT FLIGHT PLAN
  // =========================================================
  static Future<void> deleteCurrentFlight(String userId) async {
    final uri = Uri.parse("$base/current/$userId");
    await http.delete(uri);
  }
}
