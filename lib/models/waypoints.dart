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

  factory Waypoint.fromJson(Map<String, dynamic> j) {
    return Waypoint(
      id: j['waypoint_id'] is int ? j['waypoint_id'] : null,
      ident: j['ident'] ?? '',
      name: j['name'],
      lat: (j['laty'] as num?)?.toDouble() ?? 0,
      lon: (j['lonx'] as num?)?.toDouble() ?? 0,
      type: j['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "waypoint_id": id, // may be null (OK)
      "ident": ident,
      "name": name,
      "lat": lat,
      "lon": lon,
      "type": type,
    };
  }
}
