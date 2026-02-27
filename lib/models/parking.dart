class ParkingSpot {
  final bool hasJetway;
  final double heading;
  final String icao;
  final double lat;
  final double lon;
  final String name;
  final int number;
  final String type;

  ParkingSpot({
    required this.hasJetway,
    required this.heading,
    required this.icao,
    required this.lat,
    required this.lon,
    required this.name,
    required this.number,
    required this.type,
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> j) {
    return ParkingSpot(
      hasJetway: (j['has_jetway'] ?? 0) == 1,
      heading: (j['heading'] ?? 0).toDouble(),
      icao: j['icao'] ?? '',
      lat: (j['laty'] ?? 0).toDouble(),
      lon: (j['lonx'] ?? 0).toDouble(),
      name: j['parking_name'] ?? '',
      number: j['parking_number'],
      type: j['parking_type'] ?? '',
    );
  }
}
