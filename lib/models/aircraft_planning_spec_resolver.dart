import 'package:skycase/models/aircraft_planning_spec.dart';
import 'package:skycase/models/aircraft_template.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/models/simlink_data.dart';

class AircraftPlanningSpecResolver {
  const AircraftPlanningSpecResolver._();

  static AircraftPlanningSpec? resolve({
    required SimLinkData? sim,
    required LearnedAircraft? hangarAircraft,
    required AircraftTemplate? matchedTemplate,
    required String title,
  }) {
    final learned = hangarAircraft;
    final template = matchedTemplate;
    final cleanTitle = title.trim();

    if (learned == null && template == null && cleanTitle.isEmpty && sim == null) {
      return null;
    }

    final cruiseSpeedKts =
        _positive(template?.cruiseSpeed) ?? _fallbackCruiseFromSim(sim);

    final fuelBurnPerHour =
        _positive(template?.fuelBurn) ?? _fallbackBurnFromSim(sim);

    final fuelBurnUnit = _normalizeFuelUnit(template?.fuelUnit);

    final fuelDensity =
        _positive(template?.fuelDensity) ?? _fallbackDensityFromSim(sim);

    final usableFuelGallons = _resolveUsableFuelGallons(
      learned: learned,
      density: fuelDensity,
    );

    final isHelicopter = _resolveIsHelicopter(
      learned: learned,
      sim: sim,
      title: cleanTitle,
      template: template,
    );

    return AircraftPlanningSpec(
      aircraftId: _resolveAircraftId(
        learned: learned,
        template: template,
        title: cleanTitle,
      ),
      title: _resolveTitle(
        learned: learned,
        template: template,
        title: cleanTitle,
      ),
      cruiseSpeedKts: cruiseSpeedKts,
      fuelBurnPerHour: fuelBurnPerHour,
      fuelBurnUnit: fuelBurnUnit,
      fuelDensity: fuelDensity,
      usableFuelGallons: usableFuelGallons,
      maxStillAirRangeNm: _positive(template?.maxRangeNm),
      emptyWeightLbs: _positive(learned?.emptyWeight),
      mtowLbs: _positive(learned?.mtow),
      mzfwLbs: _positive(learned?.mzfw),
      payloadCapacityLbs: _positive(learned?.payloadCapacityLbs),
      maxPax: template?.maxPax,
      isHelicopter: isHelicopter,
      isFloatplane: learned?.isFloatplane == true,
      isAmphibious: learned?.isAmphibious == true,
      isRetractable: learned?.isRetractableGear == true,
    );
  }

  static String _resolveAircraftId({
    required LearnedAircraft? learned,
    required AircraftTemplate? template,
    required String title,
  }) {
    final learnedId = learned?.id.trim();
    if (learnedId != null && learnedId.isNotEmpty) return learnedId;

    final templateId = template?.id.trim();
    if (templateId != null && templateId.isNotEmpty) return templateId;

    if (title.isNotEmpty) return title;
    return 'unknown_aircraft';
  }

  static String _resolveTitle({
    required LearnedAircraft? learned,
    required AircraftTemplate? template,
    required String title,
  }) {
    final learnedTitle = learned?.title.trim();
    if (learnedTitle != null && learnedTitle.isNotEmpty) return learnedTitle;

    if (title.isNotEmpty) return title;

    final templateName = template?.name.trim();
    if (templateName != null && templateName.isNotEmpty) return templateName;

    final templateId = template?.id.trim();
    if (templateId != null && templateId.isNotEmpty) return templateId;

    return 'Unknown Aircraft';
  }

  static bool _resolveIsHelicopter({
    required LearnedAircraft? learned,
    required SimLinkData? sim,
    required String title,
    required AircraftTemplate? template,
  }) {
    if (learned?.isHelicopter == true) return true;
    if (sim?.engineType == 3) return true;

    final t = title.toLowerCase();
    if (t.contains('heli') || t.contains('helicopter')) return true;

    final templateId = (template?.id ?? '').toLowerCase();
    final templateName = (template?.name ?? '').toLowerCase();

    const heliIds = {'r44', 'h125', 'h135'};

    if (heliIds.contains(templateId)) return true;
    if (templateName.contains('helicopter')) return true;

    return false;
  }

  static double? _resolveUsableFuelGallons({
    required LearnedAircraft? learned,
    required double density,
  }) {
    if (learned == null) return null;

    final gallons = _positive(learned.fuelCapacityGallons);
    if (gallons != null) return gallons;

    // Future-safe place:
    // if later LearnedAircraft gets fuelCapacity + fuelCapacityUnit,
    // normalize it here and keep the rest of the app untouched.

    return null;
  }

  static String _normalizeFuelUnit(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();

    switch (value) {
      case 'gal':
      case 'gallon':
      case 'gallons':
        return 'gal';
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return 'lbs';
      case 'kg':
      case 'kilogram':
      case 'kilograms':
        return 'kg';
      default:
        return 'gal';
    }
  }

  static double? _positive(num? value) {
    if (value == null) return null;
    final asDouble = value.toDouble();
    if (asDouble <= 0) return null;
    return asDouble;
  }

  static double _fallbackCruiseFromSim(SimLinkData? sim) {
    switch (sim?.engineType) {
      case 0:
        return 110; // piston
      case 1:
        return 450; // jet
      case 3:
        return 120; // helicopter
      case 5:
        return 230; // turboprop
      default:
        return 150;
    }
  }

  static double _fallbackDensityFromSim(SimLinkData? sim) {
    return sim?.engineType == 0 ? 6.0 : 6.7;
  }

  static double _fallbackBurnFromSim(SimLinkData? sim) {
    switch (sim?.engineType) {
      case 0:
        return 14; // gal/hr-ish
      case 1:
        return 180; // lbs/hr-ish fallback
      case 3:
        return 32; // gal/hr-ish fallback
      case 5:
        return 60; // lbs/hr-ish fallback
      default:
        return 46;
    }
  }
}