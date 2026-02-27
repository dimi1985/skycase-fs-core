import 'package:latlong2/latlong.dart';

// 1. TurbulenceEvent Model
class TurbulenceEvent {
  final LatLng location;
  final String severity; // 'light', 'moderate', 'severe'
  final DateTime timestamp;

  TurbulenceEvent(this.location, this.severity, this.timestamp);

  Map<String, dynamic> toJson() => {
        'lat': location.latitude,
        'lng': location.longitude,
        'severity': severity,
        'timestamp': timestamp.toIso8601String(),
      };

 static TurbulenceEvent fromJson(Map<String, dynamic> json) => TurbulenceEvent(
  LatLng(
    (json['lat'] as num).toDouble(),
    (json['lng'] as num).toDouble(),
  ),
  json['severity'],
  DateTime.parse(json['timestamp']),
);
}
