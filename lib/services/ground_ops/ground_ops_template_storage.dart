import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/ground_ops/ground_ops_template_catalog.dart';

class GroundOpsTemplateStorage {
  static const _indexKey = 'ground_ops_template_index_v1';
  static const _prefix = 'ground_ops_template_v1_';

  static String normalizeAircraftId(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return 'unknown_aircraft';

    return text
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String keyForAircraft(String aircraftId) => '$_prefix${normalizeAircraftId(aircraftId)}';

  static Future<void> saveTemplate(GroundOpsTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final key = keyForAircraft(template.id);
    await prefs.setString(key, jsonEncode(template.toJson()));

    final ids = (prefs.getStringList(_indexKey) ?? <String>[]).toSet();
    ids.add(normalizeAircraftId(template.id));
    await prefs.setStringList(_indexKey, ids.toList()..sort());
  }

  static Future<GroundOpsTemplate?> loadTemplate(String aircraftId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyForAircraft(aircraftId));
    if (raw == null || raw.isEmpty) return null;

    try {
      return GroundOpsTemplate.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<GroundOpsTemplate> loadOrSeed({
    required String aircraftId,
    required String aircraftName,
    required GroundOpsAircraftFamily family,
  }) async {
    final saved = await loadTemplate(aircraftId);
    if (saved != null) return saved;

    return GroundOpsTemplateCatalog.buildSeed(
      aircraftId: normalizeAircraftId(aircraftId),
      aircraftName: aircraftName,
      family: family,
    );
  }
}
