class Waypoint {
  final int? id;
  final String ident;
  final String? name;
  final double lat;
  final double lon;
  final String type;

  Waypoint({
    this.id,
    required this.ident,
    required this.name,
    required this.lat,
    required this.lon,
    required this.type,
  });

  static double _readDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  factory Waypoint.fromJson(Map<String, dynamic> j) {
    return Waypoint(
      id: j['waypoint_id'] is int ? j['waypoint_id'] : null,
      ident: (j['ident'] ?? j['icao'] ?? '').toString(),
      name: j['name']?.toString(),

      // ✅ support BOTH legacy and backend keys
      lat: _readDouble(j['lat'] ?? j['laty'] ?? j['latitude']),
      lon: _readDouble(j['lon'] ?? j['lonx'] ?? j['lng'] ?? j['longitude']),

      type: (j['type'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "waypoint_id": id,
      "ident": ident,
      "name": name,
      "lat": lat,
      "lon": lon,
      "type": type,
    };
  }
}