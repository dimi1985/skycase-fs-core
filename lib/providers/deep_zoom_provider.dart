import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DeepZoomMode {
  keepTiles,
  cleanBackground,
}

class DeepZoomProvider extends ChangeNotifier {
  static const String _prefsKey = 'deep_zoom_mode';

  DeepZoomMode _mode = DeepZoomMode.cleanBackground;

  DeepZoomMode get mode => _mode;

  bool get keepTiles => _mode == DeepZoomMode.keepTiles;
  bool get cleanBackground => _mode == DeepZoomMode.cleanBackground;

  DeepZoomProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    if (raw != null) {
      _mode = DeepZoomMode.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => DeepZoomMode.cleanBackground,
      );
    }

    notifyListeners();
  }

  Future<void> setMode(DeepZoomMode value) async {
    if (_mode == value) return;

    _mode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.name);
  }
}