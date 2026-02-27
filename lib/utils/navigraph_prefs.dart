import 'package:shared_preferences/shared_preferences.dart';

class NavigraphPrefs {
  static const _key = 'has_navigraph';

  static Future<bool> getHasPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setHasPremium(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
