class Vor {
  final int id;
  final String ident;
  final String name;
  final int frequency;
  final double lat;
  final double lon;
  final double altitude;
  final double magVar;
  final double range;
  final String region;
  final String type;

  Vor({
    required this.id,
    required this.ident,
    required this.name,
    required this.frequency,
    required this.lat,
    required this.lon,
    required this.altitude,
    required this.magVar,
    required this.range,
    required this.region,
    required this.type,
  });

  factory Vor.fromJson(Map<String, dynamic> j) {
    return Vor(
      id: j['vor_id'],
      ident: j['ident'] ?? '',
      name: j['name'] ?? '',
      frequency: j['frequency'] ?? 0,
      lat: (j['laty'] ?? 0).toDouble(),
      lon: (j['lonx'] ?? 0).toDouble(),
      altitude: (j['altitude'] ?? 0).toDouble(),
      magVar: (j['mag_var'] ?? 0).toDouble(),
      range: (j['range'] ?? 0).toDouble(),
      region: j['region'] ?? '',
      type: j['type'] ?? '',
    );
  }
}
