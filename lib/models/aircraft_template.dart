class AircraftTemplate {
  final String id;
  final String name;
  final double cruiseSpeed;
  final double fuelBurn;
  final double maxRangeNm;

  // NEW ✨
  final String fuelUnit;       // "gal", "lbs", "kg"
  final double fuelDensity;    // 6.0 (Avgas) / 6.7 (Jet-A)

  AircraftTemplate({
    required this.id,
    required this.name,
    required this.cruiseSpeed,
    required this.fuelBurn,
    required this.maxRangeNm,
    required this.fuelUnit,
    required this.fuelDensity,
  });

  factory AircraftTemplate.fromJson(Map<String, dynamic> json) {
    return AircraftTemplate(
      id: json['id'],
      name: json['name'],
      cruiseSpeed: json['cruiseSpeed'].toDouble(),
      fuelBurn: json['fuelBurn'].toDouble(),
      maxRangeNm: json['maxRangeNm'].toDouble(),

      // NEW (with fallback defaults)
      fuelUnit: json['fuelUnit'] ?? "gal",
      fuelDensity: (json['fuelDensity'] ?? 6.0).toDouble(),
    );
  }
}
