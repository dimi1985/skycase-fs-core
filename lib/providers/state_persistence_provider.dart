import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatePersistenceProvider extends ChangeNotifier {
  bool _saveState = true;

  bool get saveState => _saveState;

  StatePersistenceProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _saveState = prefs.getBool('save_aircraft_state') ?? true;
    notifyListeners();
  }

  Future<void> setSaveState(bool value) async {
    _saveState = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('save_aircraft_state', value);
  }
}
