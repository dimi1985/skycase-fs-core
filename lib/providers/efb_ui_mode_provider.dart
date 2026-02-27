import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EfbUiMode {
  minimal,
  cinematic,
}

class EfbUiModeProvider extends ChangeNotifier {
  static const String _prefsKey = 'efb_ui_mode';

  EfbUiMode _mode = EfbUiMode.minimal;
  bool _loaded = false;

  EfbUiMode get mode => _mode;
  bool get isCinematic => _mode == EfbUiMode.cinematic;
  bool get isMinimal => _mode == EfbUiMode.minimal;
  bool get isLoaded => _loaded;

  /// Call ONCE during app startup
  Future<void> load() async {
    if (_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    if (raw == 'cinematic') {
      _mode = EfbUiMode.cinematic;
    } else {
      _mode = EfbUiMode.minimal;
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(EfbUiMode mode) async {
    if (_mode == mode) return;

    _mode = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      mode == EfbUiMode.cinematic ? 'cinematic' : 'minimal',
    );

    notifyListeners();
  }

  Future<void> toggle() async {
    await setMode(
      _mode == EfbUiMode.minimal
          ? EfbUiMode.cinematic
          : EfbUiMode.minimal,
    );
  }
}

