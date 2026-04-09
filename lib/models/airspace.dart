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

  const Airspace({
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
      boundaryId: (j['boundary_id'] as num?)?.toInt() ?? 0,
      geometry: (j['geometry'] ?? '') as String,
      maxAlt: (j['max_altitude'] as num?)?.toInt() ?? 0,
      minAlt: (j['min_altitude'] as num?)?.toInt() ?? 0,
      multipleCode: j['multiple_code'] as String?,
      name: (j['name'] ?? '') as String,
      restrictiveDesignation: j['restrictive_designation'] as String?,
      restrictiveType: j['restrictive_type'] as String?,
      type: (j['type'] ?? '') as String,
    );
  }
}