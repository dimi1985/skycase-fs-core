import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigraphProvider with ChangeNotifier {
  static const _key = "navigraphPremium";

  bool _hasPremium = false;
  bool get hasPremium => _hasPremium;

  NavigraphProvider() {
    _load();
  }

  // -------------------------------------------------
  // LOAD FROM SHARED PREFERENCES
  // -------------------------------------------------
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _hasPremium = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  // -------------------------------------------------
  // SET VALUE + SAVE TO SHARED PREFS
  // -------------------------------------------------
  Future<void> setPremium(bool value) async {
    _hasPremium = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);

    notifyListeners();
  }
}
