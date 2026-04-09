class AircraftPlanningSpec {
  final String aircraftId;
  final String title;

  final double cruiseSpeedKts;
  final double fuelBurnPerHour;
  final String fuelBurnUnit;
  final double fuelDensity;

  final double? usableFuelGallons;
  final double? maxStillAirRangeNm;

  final double? emptyWeightLbs;
  final double? mtowLbs;
  final double? mzfwLbs;
  final double? payloadCapacityLbs;

  final int? maxPax;

  final bool isHelicopter;
  final bool isFloatplane;
  final bool isAmphibious;
  final bool isRetractable;

  const AircraftPlanningSpec({
    required this.aircraftId,
    required this.title,
    required this.cruiseSpeedKts,
    required this.fuelBurnPerHour,
    required this.fuelBurnUnit,
    required this.fuelDensity,
    required this.usableFuelGallons,
    required this.maxStillAirRangeNm,
    required this.emptyWeightLbs,
    required this.mtowLbs,
    required this.mzfwLbs,
    required this.payloadCapacityLbs,
    required this.maxPax,
    required this.isHelicopter,
    required this.isFloatplane,
    required this.isAmphibious,
    required this.isRetractable,
  });

  double get fuelBurnGph {
    final unit = fuelBurnUnit.toLowerCase();

    if (unit == 'gal') return fuelBurnPerHour;
    if (unit == 'lbs') return fuelBurnPerHour / fuelDensity;
    if (unit == 'kg') return (fuelBurnPerHour * 2.20462) / fuelDensity;

    return fuelBurnPerHour;
  }

  double? get usableRangeNm {
    if (usableFuelGallons != null &&
        usableFuelGallons! > 0 &&
        fuelBurnGph > 0 &&
        cruiseSpeedKts > 0) {
      const reserveGallons = 30.0;
      const taxiGallons = 3.0;
      const climbGallons = 5.0;

      final tripFuelAvailable =
          usableFuelGallons! - reserveGallons - taxiGallons - climbGallons;

      if (tripFuelAvailable > 0) {
        final hours = tripFuelAvailable / fuelBurnGph;
        final range = hours * cruiseSpeedKts;
        if (range > 0) return range;
      }
    }

    if (maxStillAirRangeNm != null && maxStillAirRangeNm! > 0) {
      return maxStillAirRangeNm! * 0.80;
    }

    return null;
  }

  bool canFlyDistanceNm(double distanceNm) {
    final range = usableRangeNm;
    if (range == null || range <= 0) return true;
    return distanceNm <= range;
  }
}