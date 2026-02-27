import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:skycase/models/checklist.dart';

class ChecklistService {
  static final Map<String, Checklist> _cache = {};

  /// Load checklist by ICAO code (e.g. "KODI", "C172")
  static Future<Checklist?> load(String icao) async {
    // return cached version instantly
    if (_cache.containsKey(icao)) return _cache[icao];

    final path = "assets/checklists/${icao.toLowerCase()}.json";

    try {
      final jsonString = await rootBundle.loadString(path);
      final data = jsonDecode(jsonString);

      final checklist = Checklist.fromJson(data);
      _cache[icao] = checklist;

      return checklist;
    } catch (e) {
      print("❌ Checklist load failed for $icao → $e");
      return null;
    }
  }

  /// Clear cached data (rarely needed)
  static void clearCache() => _cache.clear();
}
