class Airport {
  final String icao;
  final String name;
  final double lat;
  final double lon;
  final String country;         // Actually region
  final double elevation;
  final bool isMilitary;

  Airport({
    required this.icao,
    required this.name,
    required this.lat,
    required this.lon,
    required this.country,
    required this.elevation,
    required this.isMilitary,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    try {
      return Airport(
        icao: json['icao'] ?? 'UNKNOWN',
        name: json['name'] ?? 'Unnamed',
        lat: (json['lat'] ?? 0.0).toDouble(),
        lon: (json['lon'] ?? 0.0).toDouble(),
        country: json['country'] ?? 'N/A',
        elevation: (json['elevation'] ?? 0.0).toDouble(),
        isMilitary: (json['is_military'] ?? 0) == 1,
      );
    } catch (e) {
      print('❌ Error parsing airport: $json\n$e');
      rethrow;
    }
  }
}
