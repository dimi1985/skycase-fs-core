import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class UserService {
  final String baseUrl;
  final http.Client? client;

  UserService({
    required this.baseUrl,
    this.client,
  });

  http.Client get _client => client ?? http.Client();

  Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _client.get(url, headers: headers);
  }

  Future<http.Response> _post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client.post(url, headers: headers, body: body);
  }

  Future<http.Response> _patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client.patch(url, headers: headers, body: body);
  }

  Future<User> getProfile(String token) async {
    final url = Uri.parse('$baseUrl/api/user/profile');

    print('[getProfile] GET $url');

    final response = await _get(
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

    if (body.isEmpty || !body.startsWith('{')) {
      throw Exception('Invalid profile response format');
    }

    final decoded = jsonDecode(body);

    if (decoded is! Map || decoded['user'] == null) {
      throw Exception('Malformed profile payload');
    }

    return User.fromJson({
      'user': decoded['user'],
      'token': token,
    });
  }

Future<HqLocation?> getHq(String token) async {
  try {
    final url = Uri.parse('$baseUrl/api/user/hq');
    final response = await _get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final body = response.body.trim();
    print('[getHq] Status: ${response.statusCode} | Body: $body');

    if (response.statusCode != 200 || body.isEmpty || body == 'null') {
      return null;
    }

    try {
      final json = jsonDecode(body);
      
      // Έλεγχος αν το json είναι Map και αν το 'hq' δεν είναι null
      if (json is Map<String, dynamic> && json['hq'] != null) {
        final hq = HqLocation.fromJson(Map<String, dynamic>.from(json['hq']));

        final prefs = await SharedPreferences.getInstance();
        if (hq.icao.isNotEmpty) {
          await prefs.setString('homebase_icao', hq.icao);
        }
        return hq;
      }
    } catch (parseError) {
      print('[UserService] HQ JSON Parse Error: $parseError');
      return null;
    }

    print('[UserService] HQ fetch succeeded but no HQ found in payload');
    return null;
  } catch (e) {
    print('[UserService] HQ fetch exception: $e');
    return null;
  }
}

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

    try {
      final response = await _post(url, headers: headers, body: body);

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
      final response = await _patch(url, headers: headers, body: body);
      print('[updateStats] Status: ${response.statusCode}');
      print('[updateStats] Body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('[updateStats] ❌ Exception: $e');
      return false;
    }
  }

  Future<bool> recordPoiVisit({
    required String token,
    required String poiId,
    required double dwellMinutes,
  }) async {
    final url = Uri.parse('$baseUrl/api/user/stats/poi-visit');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'poiId': poiId,
      'dwellMinutes': dwellMinutes,
    });

    try {
      final response = await _post(url, headers: headers, body: body);
      print('[recordPoiVisit] Status: ${response.statusCode}');
      print('[recordPoiVisit] Body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('[recordPoiVisit] ❌ Exception: $e');
      return false;
    }
  }
}