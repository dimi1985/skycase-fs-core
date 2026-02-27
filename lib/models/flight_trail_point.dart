class FlightTrailPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;

  FlightTrailPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  factory FlightTrailPoint.fromJson(Map<String, dynamic> json) {
    return FlightTrailPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'timestamp': timestamp.toIso8601String(),
      };
}
