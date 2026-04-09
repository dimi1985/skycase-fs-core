// lib/providers/simbrief_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SimBriefProvider extends ChangeNotifier {
  static const _usernameKey = 'simbrief_username';
  static const _pilotIdKey = 'simbrief_pilot_id';

  String _username = '';
  String _pilotId = '';
  bool _loaded = false;

  String get username => _username;
  String get pilotId => _pilotId;
  bool get loaded => _loaded;

  bool get hasCredentials =>
      _username.trim().isNotEmpty || _pilotId.trim().isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_usernameKey) ?? '';
    _pilotId = prefs.getString(_pilotIdKey) ?? '';
    _loaded = true;
    notifyListeners();
  }

  Future<void> save({
    required String username,
    required String pilotId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    _username = username.trim();
    _pilotId = pilotId.trim();

    await prefs.setString(_usernameKey, _username);
    await prefs.setString(_pilotIdKey, _pilotId);

    notifyListeners();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_pilotIdKey);

    _username = '';
    _pilotId = '';
    notifyListeners();
  }
}