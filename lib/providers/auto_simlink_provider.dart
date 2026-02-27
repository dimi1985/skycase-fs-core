import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoSimLinkProvider extends ChangeNotifier {
  bool _autoConnect = true;

  bool get autoConnect => _autoConnect;

  AutoSimLinkProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _autoConnect = prefs.getBool('auto_connect_simlink') ?? true;
    notifyListeners();
  }

  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_connect_simlink', value);
  }
}
