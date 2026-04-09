import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  dynamic _safeDecode(http.Response response, {required String tag}) {
    final body = response.body.trim();

    print('[$tag] STATUS: ${response.statusCode}');
    print('[$tag] CONTENT-TYPE: ${response.headers['content-type']}');
    print('[$tag] BODY: $body');

    if (body.isEmpty) {
      throw Exception('[$tag] Empty response body');
    }

    try {
      return jsonDecode(body);
    } catch (e) {
      throw Exception(
        '[$tag] Invalid JSON response. '
        'Status=${response.statusCode}, Body="$body"',
      );
    }
  }

  Future<User> register(String username, String email, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      throw Exception('Registration successful. Please login.');
    }

    final json = _safeDecode(response, tag: 'REGISTER');
    throw Exception(
      json is Map && json['message'] != null
          ? json['message']
          : 'Registration failed',
    );
  }

  Future<User> login(String usernameOrEmail, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usernameOrEmail': usernameOrEmail,
        'password': password,
      }),
    );

    final json = _safeDecode(response, tag: 'LOGIN');

    if (response.statusCode != 200) {
      throw Exception(
        json is Map && json['message'] != null
            ? json['message']
            : 'Login failed',
      );
    }

    if (json is! Map<String, dynamic>) {
      throw Exception('[LOGIN] Response is not a JSON object');
    }

    if (json['user'] == null || json['token'] == null) {
      throw Exception('[LOGIN] Missing user or token in response');
    }

    final user = User.fromJson({
      'user': json['user'],
      'token': json['token'],
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('auth_token', user.token);

    return user;
  }
}