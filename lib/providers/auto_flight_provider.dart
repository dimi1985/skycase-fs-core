import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoFlightProvider extends ChangeNotifier {
  bool _autoFlight = true;

  bool get autoFlight => _autoFlight;

  AutoFlightProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _autoFlight = prefs.getBool('auto_flight_detection') ?? true;
    notifyListeners();
  }

  Future<void> setAutoFlight(bool value) async {
    _autoFlight = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_flight_detection', value);
  }
}
