import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SessionManager {
  static const _tokenKey = 'jwt_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    return token;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

 static Future<String?> getUserId() async {
  final token = await loadToken();
  if (token != null && !JwtDecoder.isExpired(token)) {
    final decoded = JwtDecoder.decode(token);

    // your backend uses "id", NOT "userId"
    return decoded['id'];  
  }
  return null;
}

}
