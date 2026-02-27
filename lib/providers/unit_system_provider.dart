// lib/providers/unit_system_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UnitSystem { metric, imperial }

class UnitSystemProvider with ChangeNotifier {
  UnitSystem _unitSystem = UnitSystem.imperial;

  UnitSystem get unitSystem => _unitSystem;

  bool get isMetric => _unitSystem == UnitSystem.metric;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString("unitSystem");
    _unitSystem = stored == "metric" ? UnitSystem.metric : UnitSystem.imperial;
    notifyListeners();
  }

  Future<void> toggleUnitSystem() async {
    _unitSystem =
        _unitSystem == UnitSystem.metric ? UnitSystem.imperial : UnitSystem.metric;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("unitSystem",
        _unitSystem == UnitSystem.metric ? "metric" : "imperial");
    notifyListeners();
  }
}
