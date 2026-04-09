class AircraftTemplate {
  final String id;
  final String name;
  final double cruiseSpeed;
  final double fuelBurn;
  final double maxRangeNm;

  final String fuelUnit;
  final double fuelDensity;

  final int? maxPax;

  AircraftTemplate({
    required this.id,
    required this.name,
    required this.cruiseSpeed,
    required this.fuelBurn,
    required this.maxRangeNm,
    required this.fuelUnit,
    required this.fuelDensity,
    this.maxPax,
  });

  factory AircraftTemplate.fromJson(Map<String, dynamic> json) {
    return AircraftTemplate(
      id: json['id'],
      name: json['name'],
      cruiseSpeed: (json['cruiseSpeed'] as num).toDouble(),
      fuelBurn: (json['fuelBurn'] as num).toDouble(),
      maxRangeNm: (json['maxRangeNm'] as num).toDouble(),
      fuelUnit: json['fuelUnit'] ?? 'gal',
      fuelDensity: (json['fuelDensity'] ?? 6.0).toDouble(),
      maxPax: json['maxPax'] == null
          ? null
          : (json['maxPax'] as num).toInt(),
    );
  }
}