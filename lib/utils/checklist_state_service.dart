import 'package:shared_preferences/shared_preferences.dart';

/// Cleans ICAO names and section IDs so SharedPreferences never screams.
String _clean(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]'), '_') // only safe chars
      .replaceAll(RegExp('_+'), '_')          // collapse multiple underscores
      .trim();
}

/// Generates final storage key for this aircraft + checklist section.
String _key(String icao, String sectionId) {
  final safeIcao = _clean(icao);
  final safeSection = _clean(sectionId);
  return "chk_${safeIcao}_${safeSection}";
}

class ChecklistStateService {
  /// Save (or remove) progress for a given checklist step.
  static Future<void> saveProgress({
    required String icao,
    required String sectionId,
    required int index,
    required bool checked,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(icao, sectionId);

    // Load existing saved list
    List<String> saved = prefs.getStringList(key) ?? [];

    final idx = index.toString();

    if (checked) {
      if (!saved.contains(idx)) {
        saved.add(idx);
      }
    } else {
      saved.remove(idx);
    }

    await prefs.setStringList(key, saved);
  }

  /// Load all checked indices for this aircraft + section.
  static Future<Set<int>> loadProgress(
    String icao,
    String sectionId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(icao, sectionId);

    final list = prefs.getStringList(key) ?? [];

    // Safe integer parsing
    return list
        .map((e) {
          final n = int.tryParse(e);
          return n ?? -1;
        })
        .where((v) => v >= 0)
        .toSet();
  }
}
