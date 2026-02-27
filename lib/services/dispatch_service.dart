import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dispatch_job.dart';

class DispatchService {
  static const baseUrl = "http://38.242.241.46:3000";

  // ---------------------------------------------------
  // GET OPEN JOBS → optional airport filter
  // ---------------------------------------------------
  static Future<List<DispatchJob>> getOpenJobs({String? airport}) async {
    final query = airport != null && airport.isNotEmpty
        ? "?airport=${Uri.encodeComponent(airport.toUpperCase())}"
        : "";

    final url = "$baseUrl/dispatch/open$query";

    print("🔵 GET: $url");

    try {
      final res = await http.get(Uri.parse(url));

      print("🟣 STATUS: ${res.statusCode}");
    print("🟣 RAW BODY: '${res.body}'");

      if (res.statusCode != 200) return [];

      final List list = jsonDecode(res.body);
      return list.map((json) => DispatchJob.fromJson(json)).toList();
    } catch (err, st) {
      print("❌ ERROR getOpenJobs: $err");
      print(st);
      return [];
    }
  }

  // ---------------------------------------------------
  // ACCEPT JOB
  // ---------------------------------------------------
  static Future<DispatchJob?> acceptJob(String jobId, String userId) async {
    final url = "$baseUrl/dispatch/accept/$jobId";
    print("🟡 POST: $url  userId=$userId");

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      );

      print("🟣 STATUS: ${res.statusCode}");
      print("🟣 BODY: ${res.body}");

      if (res.statusCode != 200) return null;

      return DispatchJob.fromJson(jsonDecode(res.body));
    } catch (err, st) {
      print("❌ ERROR acceptJob: $err");
      print(st);
      return null;
    }
  }

  // ---------------------------------------------------
  // GENERATE JOBS
  // ---------------------------------------------------
  static Future<void> generateJobs(String userId, {String? airport}) async {
    final url = "$baseUrl/dispatch/generate";
    print("🟠 POST: $url  airport=$airport");

    final body = {
      "userId": userId,
    };

    if (airport != null && airport.isNotEmpty) {
      body["airport"] = airport.toUpperCase();
    }

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print("🟣 STATUS: ${res.statusCode}");
     print("🟣 RAW BODY: '${res.body}'");
    } catch (err, st) {
      print("❌ ERROR generateJobs: $err");
      print(st);
    }
  }

  // ---------------------------------------------------
  // GET ACTIVE JOB
  // ---------------------------------------------------
  static Future<Map<String, dynamic>?> getActiveJob(String userId) async {
    final url = "$baseUrl/dispatch/active/$userId";
    print("🔵 GET ACTIVE: $url");

    try {
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) return null;
      if (res.body.isEmpty) return null;

      final json = jsonDecode(res.body);
      if (json == null) return null;

      return Map<String, dynamic>.from(json);
    } catch (err) {
      print("❌ ERROR getActiveJob: $err");
      return null;
    }
  }

  // ---------------------------------------------------
  // COMPLETE JOB
  // ---------------------------------------------------
  static Future<bool> completeJob(String jobId, String userId) async {
    final url = "$baseUrl/dispatch/complete/$jobId";
    print("🟢 POST COMPLETE: $url");

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      );

      print("🟣 STATUS: ${res.statusCode}");
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
    final url = "$baseUrl/dispatch/cancel/$jobId";
    print("🔴 PUT CANCEL: $url");

    try {
      final res = await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      );

      print("🟣 STATUS: ${res.statusCode}");
      return res.statusCode == 200;
    } catch (err, st) {
      print("❌ ERROR cancelJob: $err");
      print(st);
      return false;
    }
  }

  // ---------------------------------------------------
  // LAST DESTINATION (local only)
  // ---------------------------------------------------
  static Future<String?> getLastDestination() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("last_destination_icao");
  }
}
