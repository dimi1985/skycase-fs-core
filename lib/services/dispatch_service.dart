import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/aircraft_planning_spec.dart';
import '../models/dispatch_job.dart';

class DispatchService {
  static const String baseUrl = "http://38.242.241.46:3000";

  static Uri _uri(String path, [Map<String, String>? queryParams]) {
    return Uri.parse("$baseUrl$path").replace(queryParameters: queryParams);
  }

  static Map<String, String> get _jsonHeaders => {
        "Content-Type": "application/json",
      };

  static String _resolveAircraftType(AircraftPlanningSpec? spec) {
    if (spec == null) return "airplane";
    if (spec.isHelicopter) return "helicopter";
    return "airplane";
  }

  static Map<String, dynamic> _buildAircraftProfilePayload(
    AircraftPlanningSpec? spec,
  ) {
    if (spec == null) return {};

    final payload = <String, dynamic>{
      "aircraftType": _resolveAircraftType(spec),
    };

    if (spec.maxPax != null && spec.maxPax! > 0) {
      payload["maxPax"] = spec.maxPax;
    }

    if (spec.payloadCapacityLbs != null && spec.payloadCapacityLbs! > 0) {
      payload["payloadCapacityLbs"] = spec.payloadCapacityLbs;
    }

    if (spec.usableRangeNm != null && spec.usableRangeNm! > 0) {
      payload["usableRangeNm"] = spec.usableRangeNm;
    }

    return payload;
  }

  // ---------------------------------------------------
  // GET OPEN JOBS
  // ---------------------------------------------------
  static Future<List<DispatchJob>> getOpenJobs({String? airport}) async {
    final queryParams = <String, String>{};

    if (airport != null && airport.trim().isNotEmpty) {
      queryParams["airport"] = airport.trim().toUpperCase();
    }

    final uri = _uri("/dispatch/open", queryParams.isEmpty ? null : queryParams);
    print("🔵 GET OPEN JOBS: $uri");

    try {
      final res = await http.get(uri);
      final body = res.body.trim();

      if (res.statusCode != 200 || body.isEmpty) {
        print("⚠️ getOpenJobs error: Status ${res.statusCode}");
        return [];
      }

      try {
        final decoded = jsonDecode(body);
        if (decoded is! List) return [];

        return decoded
            .map((e) => DispatchJob.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (parseError) {
        print("❌ FormatException in getOpenJobs: $parseError. Body was: $body");
        return [];
      }
    } catch (err) {
      print("❌ Connection ERROR in getOpenJobs: $err");
      return [];
    }
  }

  // ---------------------------------------------------
  // ACCEPT JOB
  // ---------------------------------------------------
  static Future<DispatchJob?> acceptJob(String jobId, String userId) async {
    final uri = _uri("/dispatch/accept/$jobId");

    print("🟡 POST ACCEPT JOB: $uri  userId=$userId");

    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({"userId": userId}),
      );

      print("🟣 STATUS: ${res.statusCode}");
      print("🟣 BODY: ${res.body}");

      if (res.statusCode != 200 || res.body.isEmpty) {
        return null;
      }

      return DispatchJob.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body)),
      );
    } catch (err, st) {
      print("❌ ERROR acceptJob: $err");
      print(st);
      return null;
    }
  }

  // ---------------------------------------------------
  // GENERATE JOBS
  // ---------------------------------------------------
static Future<Map<String, dynamic>?> generateJobs(
  String userId, {
  String? airport,
  AircraftPlanningSpec? planningSpec,
}) async {
  final uri = _uri("/dispatch/generate");

  final body = <String, dynamic>{
    "userId": userId,
    ..._buildAircraftProfilePayload(planningSpec),
  };

  if (airport != null && airport.trim().isNotEmpty) {
    body["airport"] = airport.trim().toUpperCase();
  }

  print("🟠 POST GENERATE JOBS: $uri body=$body");

  try {
    final res = await http.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    print("🟣 STATUS: ${res.statusCode}");
    print("🟣 RAW BODY: '${res.body}'");

    if (res.statusCode != 200 || res.body.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;

    return decoded;
  } catch (err, st) {
    print("❌ ERROR generateJobs: $err");
    print(st);
    return null;
  }
}
  // ---------------------------------------------------
  // GET ACTIVE JOB
  // ---------------------------------------------------
  static Future<DispatchJob?> getActiveJob(String userId) async {
    final uri = _uri("/dispatch/active/$userId");
    print("🔵 GET ACTIVE JOB: $uri");

    try {
      final res = await http.get(uri);
      final body = res.body.trim();

      if (res.statusCode != 200) {
        print("⚠️ getActiveJob failed with status ${res.statusCode}");
        return null;
      }

      if (body.isEmpty || body == 'null' || !body.startsWith('{')) {
        print("⚪ No active job found or invalid JSON start");
        return null;
      }

      try {
        final decoded = jsonDecode(body);
        if (decoded == null || decoded is! Map<String, dynamic>) return null;
        return DispatchJob.fromJson(decoded);
      } catch (parseError) {
        print("❌ FormatException in getActiveJob: $parseError. Body was: $body");
        return null;
      }
    } catch (err) {
      print("❌ Connection ERROR in getActiveJob: $err");
      return null;
    }
  }

  // ---------------------------------------------------
  // UPDATE JOB PHASE
  // ---------------------------------------------------
  static Future<DispatchJob?> updatePhase(
    String jobId,
    String userId,
    String phase,
  ) async {
    final uri = _uri("/dispatch/$jobId/phase");

    print("🟦 PATCH UPDATE PHASE: $uri  userId=$userId  phase=$phase");

    try {
      final res = await http.patch(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({
          "userId": userId,
          "phase": phase,
        }),
      );

      print("🟣 STATUS: ${res.statusCode}");
      print("🟣 BODY: ${res.body}");

      if (res.statusCode != 200 || res.body.isEmpty) {
        return null;
      }

      return DispatchJob.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body)),
      );
    } catch (err, st) {
      print("❌ ERROR updatePhase: $err");
      print(st);
      return null;
    }
  }

  // ---------------------------------------------------
  // COMPLETE JOB
  // ---------------------------------------------------
  static Future<bool> completeJob(String jobId, String userId) async {
    final uri = _uri("/dispatch/complete/$jobId");

    print("🟢 POST COMPLETE JOB: $uri  userId=$userId");

    try {
      final res = await http.post(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({"userId": userId}),
      );

      print("🟣 STATUS: ${res.statusCode}");
      print("🟣 BODY: ${res.body}");

      return res.statusCode == 200;
    } catch (err, st) {
      print("❌ ERROR completeJob: $err");
      print(st);
      return false;
    }
  }

  // ---------------------------------------------------
  // CANCEL JOB
  // ---------------------------------------------------
  static Future<bool> cancelJob(String jobId, String userId) async {
    final uri = _uri("/dispatch/cancel/$jobId");

    print("🔴 PUT CANCEL JOB: $uri  userId=$userId");

    try {
      final res = await http.put(
        uri,
        headers: _jsonHeaders,
        body: jsonEncode({"userId": userId}),
      );

      print("🟣 STATUS: ${res.statusCode}");
      print("🟣 BODY: ${res.body}");

      return res.statusCode == 200;
    } catch (err, st) {
      print("❌ ERROR cancelJob: $err");
      print(st);
      return false;
    }
  }

  // ---------------------------------------------------
  // LOCAL LAST DESTINATION
  // ---------------------------------------------------
  static Future<String?> getLastDestination() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("last_destination_icao");
  }
}