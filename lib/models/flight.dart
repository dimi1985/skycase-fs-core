import 'package:skycase/models/waypoints.dart';

class Flight {
  final String id;
  final String originIcao;
  final String destinationIcao;
  final DateTime generatedAt;



  final String aircraftType;
  final double estimatedDistanceNm;
  final Duration estimatedTime;

  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;

 final List<Waypoint>? waypoints;

  final String? missionId;
  final int cruiseAltitude;
  final double plannedFuel;

  Flight({
    required this.id,
    required this.originIcao,
    required this.destinationIcao,
    required this.generatedAt,
    required this.aircraftType,
    required this.estimatedDistanceNm,
    required this.estimatedTime,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.waypoints,             // ⭐ nullable list
    this.missionId,
    required this.cruiseAltitude,
    required this.plannedFuel,
  });

  // ---------------------------------------------------------
  // PARSE JSON → FLIGHT
  // ---------------------------------------------------------
  factory Flight.fromJson(Map<String, dynamic> json) {
    // Handle Mongo _id safely
    final idValue = json['_id'] is String
        ? json['_id']
        : json['_id']?['\$oid'] ??
          json['id'] ??
          'unknown';

    // Clean conversion for generatedAt
    final genRaw = json['generatedAt'];
    final genDate = genRaw is String
        ? DateTime.parse(genRaw)
        : DateTime.tryParse(genRaw?['\$date'] ?? '') ??
          DateTime.now();

    // Waypoints may or may not exist
   List<Waypoint>? wpList;
if (json['waypoints'] is List) {
  wpList = (json['waypoints'] as List)
      .map((e) => Waypoint.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

    return Flight(
      id: idValue,
      originIcao: json['originIcao'] ?? '',
      destinationIcao: json['destinationIcao'] ?? '',
      generatedAt: genDate,
      aircraftType: json['aircraftType'] ?? 'unknown',
      estimatedDistanceNm:
          (json['estimatedDistanceNm'] as num?)?.toDouble() ?? 0.0,

      estimatedTime: Duration(
        seconds: json['estimatedTimeSec'] ??
                 json['estimatedTime'] ??
                 0,
      ),

      originLat: (json['originLat'] as num?)?.toDouble(),
      originLng: (json['originLng'] as num?)?.toDouble(),
      destinationLat: (json['destinationLat'] as num?)?.toDouble(),
      destinationLng: (json['destinationLng'] as num?)?.toDouble(),

      waypoints: wpList,          // ⭐ Now supported

      missionId: json['missionId'],
      cruiseAltitude: json['cruiseAltitude'] ?? 0,
      plannedFuel: (json['plannedFuel'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ---------------------------------------------------------
  // FLIGHT → JSON
  // ---------------------------------------------------------
Map<String, dynamic> toJson() {
  return {
    'id': id,
    'originIcao': originIcao,
    'destinationIcao': destinationIcao,
    'generatedAt': generatedAt.toIso8601String(),
    'aircraftType': aircraftType,
    'estimatedDistanceNm': estimatedDistanceNm,
    'estimatedTimeSec': estimatedTime.inSeconds,

    'originLat': originLat,
    'originLng': originLng,
    'destinationLat': destinationLat,
    'destinationLng': destinationLng,

    // ✅ THIS IS THE FIX
    'waypoints': waypoints?.map((w) => w.toJson()).toList(),

    'missionId': missionId,
    'cruiseAltitude': cruiseAltitude,
    'plannedFuel': plannedFuel,
  };
}

}
