import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/utils/session_manager.dart';

class AircraftService {
  static const String baseUrl = "http://38.242.241.46:3000/api/aircraft";

  // -----------------------------------------------------------
  // SAVE / UPDATE AIRCRAFT
  // -----------------------------------------------------------
  static Future<LearnedAircraft?> saveAircraft(LearnedAircraft ac) async {
    final token = await SessionManager.loadToken();

    final url = "$baseUrl/save";
    print("🟠 POST: $url (save aircraft ${ac.id})");

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"aircraftId": ac.id, "data": ac.toJson()}),
      );

      print("🟣 STATUS: ${res.statusCode}");
      if (res.body.isNotEmpty) print("🟣 BODY: ${res.body}");

      if (res.statusCode != 200) return null;

      return LearnedAircraft.fromJson(jsonDecode(res.body));
    } catch (err, st) {
      print("❌ ERROR saveAircraft: $err");
      print(st);
      return null;
    }
  }

  // -----------------------------------------------------------
  // GET ALL AIRCRAFT FOR USER
  // -----------------------------------------------------------
  static Future<List<LearnedAircraft>> getAll() async {
    final token = await SessionManager.loadToken();

    final url = baseUrl;
    print("🔵 GET: $url");

    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      print("🟣 STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return [];

      final List data = jsonDecode(res.body);
      return data.map((j) => LearnedAircraft.fromJson(j)).toList();
    } catch (err, st) {
      print("❌ ERROR getAllAircraft: $err");
      print(st);
      return [];
    }
  }

  // -----------------------------------------------------------
  // GET ONE AIRCRAFT BY aircraftId
  // -----------------------------------------------------------
  static Future<LearnedAircraft?> getOne(String aircraftId) async {
    final token = await SessionManager.loadToken();
    final url = "$baseUrl/$aircraftId";

    print("🔵 GET ONE: $url");

    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $token"},
      );

      print("🟣 STATUS: ${res.statusCode}");

      if (res.statusCode != 200) return null;
      if (res.body.trim().isEmpty) return null;

      final decoded = jsonDecode(res.body);

      if (decoded == null) return null; // <—— ADD THIS LINE

      return LearnedAircraft.fromJson(decoded);
    } catch (err, st) {
      print("❌ ERROR getOneAircraft: $err");
      print(st);
      return null;
    }
  }

  static Future<LearnedAircraft?> getMain() async {
  final token = await SessionManager.loadToken();

  final url = "$baseUrl/main";
  print("🔵 GET MAIN AIRCRAFT: $url");

  try {
    final res = await http.get(
      Uri.parse(url),
      headers: {"Authorization": "Bearer $token"},
    );

    print("🟣 STATUS: ${res.statusCode}");
    if (res.statusCode != 200) return null;
    if (res.body.trim().isEmpty || res.body == "null") return null;

    final decoded = jsonDecode(res.body);
    return LearnedAircraft.fromJson(decoded);
  } catch (err, st) {
    print("❌ ERROR getMainAircraft: $err");
    print(st);
    return null;
  }
}

static Future<void> addHours({
  required String aircraftUuid,
  required int minutes,
}) async {
  final token = await SessionManager.loadToken();

  final url = "$baseUrl/add-hours";
  print("⏱️ POST: $url ($minutes min)");

  await http.post(
    Uri.parse(url),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode({
      "aircraftUuid": aircraftUuid,
      "minutes": minutes,
    }),
  );
}

}
