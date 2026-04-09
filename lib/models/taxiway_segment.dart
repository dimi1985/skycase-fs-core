import 'package:latlong2/latlong.dart';

class TaxiwaySegment {
  final String name;
  final String type;
  final LatLng start;
  final LatLng end;

  const TaxiwaySegment({
    required this.name,
    required this.type,
    required this.start,
    required this.end,
  });

  factory TaxiwaySegment.fromJson(Map<String, dynamic> json) {
    final start = (json['start'] as Map?)?.cast<String, dynamic>() ?? {};
    final end = (json['end'] as Map?)?.cast<String, dynamic>() ?? {};

    return TaxiwaySegment(
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      start: LatLng(
        ((start['lat'] ?? 0) as num).toDouble(),
        ((start['lon'] ?? 0) as num).toDouble(),
      ),
      end: LatLng(
        ((end['lat'] ?? 0) as num).toDouble(),
        ((end['lon'] ?? 0) as num).toDouble(),
      ),
    );
  }
}