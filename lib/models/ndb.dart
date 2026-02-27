class Ndb {
  final double altitude;
  final int fileId;
  final int frequency;
  final String ident;
  final double lat;
  final double lon;
  final double magVar;
  final String name;
  final int id;
  final double range;
  final String region;
  final String type;

  Ndb({
    required this.altitude,
    required this.fileId,
    required this.frequency,
    required this.ident,
    required this.lat,
    required this.lon,
    required this.magVar,
    required this.name,
    required this.id,
    required this.range,
    required this.region,
    required this.type,
  });

  factory Ndb.fromJson(Map<String, dynamic> j) {
    return Ndb(
      altitude: (j['altitude'] ?? 0).toDouble(),
      fileId: j['file_id'],
      frequency: j['frequency'],
      ident: j['ident'],
      lat: (j['laty'] ?? 0).toDouble(),
      lon: (j['lonx'] ?? 0).toDouble(),
      magVar: (j['mag_var'] ?? 0).toDouble(),
      name: j['name'] ?? '',
      id: j['ndb_id'],
      range: (j['range'] ?? 0).toDouble(),
      region: j['region'] ?? '',
      type: j['type'] ?? '',
    );
  }
}
