class AirwaySegment {
  final int airwayId;
  final String airwayName;
  final String? airwayType;
  final String? routeType;
  final int fragmentNo;
  final int sequenceNo;
  final String? direction;
  final int? minimumAltitude;
  final int? maximumAltitude;

  final int fromWaypointId;
  final String fromIdent;
  final double fromLat;
  final double fromLon;

  final int toWaypointId;
  final String toIdent;
  final double toLat;
  final double toLon;

  AirwaySegment({
    required this.airwayId,
    required this.airwayName,
    required this.airwayType,
    required this.routeType,
    required this.fragmentNo,
    required this.sequenceNo,
    required this.direction,
    required this.minimumAltitude,
    required this.maximumAltitude,
    required this.fromWaypointId,
    required this.fromIdent,
    required this.fromLat,
    required this.fromLon,
    required this.toWaypointId,
    required this.toIdent,
    required this.toLat,
    required this.toLon,
  });

  factory AirwaySegment.fromJson(Map<String, dynamic> json) {
    return AirwaySegment(
      airwayId: json['airway_id'] as int,
      airwayName: json['airway_name'] as String,
      airwayType: json['airway_type'] as String?,
      routeType: json['route_type'] as String?,
      fragmentNo: json['airway_fragment_no'] as int? ?? 0,
      sequenceNo: json['sequence_no'] as int? ?? 0,
      direction: json['direction'] as String?,
      minimumAltitude: json['minimum_altitude'] as int?,
      maximumAltitude: json['maximum_altitude'] as int?,
      fromWaypointId: json['from_waypoint_id'] as int,
      fromIdent: json['from_ident'] as String? ?? '',
      fromLat: (json['from_laty'] as num).toDouble(),
      fromLon: (json['from_lonx'] as num).toDouble(),
      toWaypointId: json['to_waypoint_id'] as int,
      toIdent: json['to_ident'] as String? ?? '',
      toLat: (json['to_laty'] as num).toDouble(),
      toLon: (json['to_lonx'] as num).toDouble(),
    );
  }
}