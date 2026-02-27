import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class UserService {
  final String baseUrl;

  UserService({required this.baseUrl});

  /// ✅ Fetch full user profile including stats and HQ
Future<User> getProfile(String token) async {
  final url = Uri.parse('$baseUrl/api/user/profile');

  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    },
  );

  final status = response.statusCode;
  final body = response.body.trim();

  print('[getProfile] Status: $status');
  print('[getProfile] Raw body: $body');

  // ❌ Non-200 → NEVER attempt jsonDecode blindly
  if (status != 200) {
    if (body.startsWith('{')) {
      try {
        final err = jsonDecode(body);
        throw Exception(err['message'] ?? 'Request failed');
      } catch (_) {
        throw Exception('Request failed ($status)');
      }
    } else {
      throw Exception('Non-JSON error response ($status)');
    }
  }

  // 🛑 200 but empty or not JSON
  if (body.isEmpty || !body.startsWith('{')) {
    throw Exception('Invalid profile response format');
  }

  // ✅ Safe decode
  final decoded = jsonDecode(body);

  if (decoded is! Map || decoded['user'] == null) {
    throw Exception('Malformed profile payload');
  }

  return User.fromJson({
    'user': decoded['user'],
    'token': token,
  });
}


  /// ✅ Fetch HQ (token identifies user, no userId needed)
  Future<HqLocation?> getHq(String token) async {
    try {
      final url = Uri.parse('$baseUrl/api/user/hq');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['hq'] != null) {
          final hq = HqLocation.fromJson(json['hq']);

          // 💾 Save ICAO for Flight Generator defaults
          final prefs = await SharedPreferences.getInstance();
          if (hq.icao.isNotEmpty) {
            await prefs.setString('homebase_icao', hq.icao);
          }

          return hq;
        } else {
          print('[UserService] HQ fetch succeeded but no data returned');
          return null;
        }
      } else {
        print(
          '[UserService] HQ fetch failed (${response.statusCode}) → ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('[UserService] HQ fetch exception: $e');
      return null;
    }
  }

  /// ✅ Update HQ (again, token handles the user)
  Future<bool> updateHq(HqLocation hq, String token) async {
    final url = Uri.parse('$baseUrl/api/user/hq');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode(hq.toJson());

    print('🚀 Updating HQ');
    print('🔗 URL: $url');
    print('📦 Body: $body');
    print('🔐 Token: $token');

    try {
      final response = await http.post(url, headers: headers, body: body);

      print('📡 Response status: ${response.statusCode}');
      print('📨 Response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('🚨 Exception during HQ update: $e');
      return false;
    }
  }

  Future<bool> updateStats(String token, int durationMinutes) async {
    final url = Uri.parse('$baseUrl/api/user/stats');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({'duration': durationMinutes});

    try {
      final response = await http.patch(url, headers: headers, body: body);
      print('[updateStats] Status: ${response.statusCode}');
      print('[updateStats] Body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('[updateStats] ❌ Exception: $e');
      return false;
    }
  }
}
