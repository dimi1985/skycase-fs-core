import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flight_log.dart';

class FlightLogService {
  static Future<String?> uploadFlightLog(FlightLog log) async {
    final uri = Uri.parse('http://38.242.241.46:3000/api/flightlog');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(log.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final flightId = data['_id'];
        print('📡 Flight log uploaded! ID: $flightId');
        return flightId;
      } else {
        print('❌ Failed to upload: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception: $e');
      return null;
    }
  }

static Future<List<FlightLog>> getFlightLogs(String userId) async {
  final uri = Uri.parse('http://38.242.241.46:3000/api/flightlog/$userId');

  print('📡 [FlightLogService] Fetching logs');
  print('👤 User ID: $userId');
  print('🌍 URI: $uri');

  try {
    final response = await http.get(uri);

    final status = response.statusCode;
    final body = response.body.trim();

    print('📥 Status: $status');
    print('📥 Raw body: $body');

    // ❌ Non-200 → no crash, just bail out
    if (status != 200) {
      print('❌ [FlightLogService] HTTP error ($status)');
      return [];
    }

    // 🛑 Empty response
    if (body.isEmpty) {
      print('⚠️ [FlightLogService] Empty response body');
      return [];
    }

    // 🛑 Backend MUST return array
    if (!body.startsWith('[')) {
      print(
        '⚠️ [FlightLogService] Unexpected response format (not array)',
      );
      return [];
    }

    // ✅ Safe decode
    final decoded = jsonDecode(body);

    if (decoded is! List) {
      print(
        '⚠️ [FlightLogService] Decoded JSON is not a List',
      );
      return [];
    }

    final logs = decoded
        .map<FlightLog>(
          (e) => FlightLog.fromJson(e as Map<String, dynamic>),
        )
        .toList();

    print('✅ [FlightLogService] Logs fetched: ${logs.length}');
    return logs;
  } catch (e, stack) {
    print('🚨 [FlightLogService] Exception');
    print('❗ $e');
    print('🧵 Stack:\n$stack');
    return [];
  }
}

}
