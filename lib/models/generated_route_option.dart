class GeneratedRouteOption {
  final String originIcao;
  final String destinationIcao;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final double distanceNm;
  final int etaMinutes;
  final int cruiseAltitude;
  final double plannedFuelGallons;
  final double plannedFuelLbs;
  final double plannedFuelKg;

  const GeneratedRouteOption({
    required this.originIcao,
    required this.destinationIcao,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.distanceNm,
    required this.etaMinutes,
    required this.cruiseAltitude,
    required this.plannedFuelGallons,
    required this.plannedFuelLbs,
    required this.plannedFuelKg,
  });

  Map<String, dynamic> toJson() => {
        'originIcao': originIcao,
        'destinationIcao': destinationIcao,
        'originLat': originLat,
        'originLng': originLng,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'distanceNm': distanceNm,
        'etaMinutes': etaMinutes,
        'cruiseAltitude': cruiseAltitude,
        'plannedFuelGallons': plannedFuelGallons,
        'plannedFuelLbs': plannedFuelLbs,
        'plannedFuelKg': plannedFuelKg,
      };

  factory GeneratedRouteOption.fromJson(Map<String, dynamic> json) {
    return GeneratedRouteOption(
      originIcao: (json['originIcao'] ?? '').toString(),
      destinationIcao: (json['destinationIcao'] ?? '').toString(),
      originLat: (json['originLat'] ?? 0).toDouble(),
      originLng: (json['originLng'] ?? 0).toDouble(),
      destinationLat: (json['destinationLat'] ?? 0).toDouble(),
      destinationLng: (json['destinationLng'] ?? 0).toDouble(),
      distanceNm: (json['distanceNm'] ?? 0).toDouble(),
      etaMinutes: (json['etaMinutes'] ?? 0) as int,
      cruiseAltitude: (json['cruiseAltitude'] ?? 0) as int,
      plannedFuelGallons: (json['plannedFuelGallons'] ?? 0).toDouble(),
      plannedFuelLbs: (json['plannedFuelLbs'] ?? 0).toDouble(),
      plannedFuelKg: (json['plannedFuelKg'] ?? 0).toDouble(),
    );
  }
}