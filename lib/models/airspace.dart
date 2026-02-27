class Airspace {
  final int boundaryId;
  final String geometry;
  final int maxAlt;
  final int minAlt;
  final String? multipleCode;
  final String name;
  final String? restrictiveDesignation;
  final String? restrictiveType;
  final String type;

  Airspace({
    required this.boundaryId,
    required this.geometry,
    required this.maxAlt,
    required this.minAlt,
    required this.multipleCode,
    required this.name,
    required this.restrictiveDesignation,
    required this.restrictiveType,
    required this.type,
  });

  factory Airspace.fromJson(Map<String, dynamic> j) {
    return Airspace(
      boundaryId: j['boundary_id'],
      geometry: j['geometry'],
      maxAlt: j['max_altitude'],
      minAlt: j['min_altitude'],
      multipleCode: j['multiple_code'],
      name: j['name'] ?? '',
      restrictiveDesignation: j['restrictive_designation'],
      restrictiveType: j['restrictive_type'],
      type: j['type'] ?? '',
    );
  }
}
