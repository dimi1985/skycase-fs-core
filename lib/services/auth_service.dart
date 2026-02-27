import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

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
    print('Response body: ${response.body}');

    if (response.statusCode == 201) {
      // Backend just sends message on success, no user/token
      // So after register, you usually login to get token
      return Future.error('Registration successful. Please login.');
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Registration failed');
    }
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

    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(response.body);

      final user = User.fromJson({
        'user': json['user'],
        'token': json['token'],
      });

      // ✅ Save user ID and token to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.id);
      await prefs.setString('auth_token', user.token);

      return user;
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Login failed');
    }
  }
}
