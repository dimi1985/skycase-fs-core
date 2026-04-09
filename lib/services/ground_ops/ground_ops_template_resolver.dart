import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/ground_ops/ground_ops_template_catalog.dart';
import 'package:skycase/services/ground_ops/ground_ops_template_storage.dart';

class GroundOpsTemplateResolver {
  static Future<GroundOpsTemplate> resolve(String? aircraftTitle) async {
    final safeTitle =
        (aircraftTitle == null || aircraftTitle.trim().isEmpty)
            ? 'Unknown Aircraft'
            : aircraftTitle.trim();

    final family = GroundOpsTemplateCatalog.inferFamily(title: safeTitle);

    return GroundOpsTemplateStorage.loadOrSeed(
      aircraftId: _slugify(safeTitle),
      aircraftName: safeTitle,
      family: family,
    );
  }

  static Future<GroundOpsTemplate> resolveWithFamily({
    String? aircraftTitle,
    GroundOpsAircraftFamily? forcedFamily,
  }) async {
    final safeTitle =
        (aircraftTitle == null || aircraftTitle.trim().isEmpty)
            ? 'Unknown Aircraft'
            : aircraftTitle.trim();

    final family =
        forcedFamily ?? GroundOpsTemplateCatalog.inferFamily(title: safeTitle);

    return GroundOpsTemplateStorage.loadOrSeed(
      aircraftId: _slugify(safeTitle),
      aircraftName: safeTitle,
      family: family,
    );
  }

  static String _slugify(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return 'unknown_aircraft';

    return text
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
