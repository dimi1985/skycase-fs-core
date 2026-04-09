import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SessionManager {
  static const _tokenKey = 'jwt_token';

  // -----------------------------
  // SAVE TOKEN
  // -----------------------------
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // -----------------------------
  // LOAD TOKEN (SAFE)
  // -----------------------------
  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    try {
      // Validate structure before using it
      if (JwtDecoder.isExpired(token)) {
        print('[SESSION] Token expired → clearing');
        await clearToken();
        return null;
      }

      // Decode just to verify it's valid JSON
      JwtDecoder.decode(token);

      return token;
    } catch (e) {
      print('[SESSION] ❌ Invalid token detected → clearing');
      print('[SESSION] Token value: $token');

      await clearToken();
      return null;
    }
  }

  // -----------------------------
  // CLEAR TOKEN
  // -----------------------------
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // -----------------------------
  // HARD RESET (FOR DEBUG / WINDOWS)
  // -----------------------------
  static Future<void> clearAllSession() async {
    final prefs = await SharedPreferences.getInstance();

    print('[SESSION] 🔥 Clearing full session');

    await prefs.remove(_tokenKey);

    // optional: clear related junk if needed
    await prefs.remove('user_id');
    await prefs.remove('remember_me');
  }

  // -----------------------------
  // GET USER ID (SAFE)
  // -----------------------------
  static Future<String?> getUserId() async {
    final token = await loadToken();

    if (token == null) return null;

    try {
      final decoded = JwtDecoder.decode(token);

      final id = decoded['id'];
      if (id == null) {
        print('[SESSION] ⚠️ Token has no id field');
        return null;
      }

      return id.toString();
    } catch (e) {
      print('[SESSION] ❌ Failed to decode token for userId');
      await clearToken();
      return null;
    }
  }
}