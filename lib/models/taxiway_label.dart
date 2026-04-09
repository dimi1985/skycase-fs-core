import 'package:latlong2/latlong.dart';

class TaxiwayLabel {
  final String name;
  final LatLng position;
  final int segmentCount;

  const TaxiwayLabel({
    required this.name,
    required this.position,
    required this.segmentCount,
  });

  factory TaxiwayLabel.fromJson(Map<String, dynamic> json) {
    return TaxiwayLabel(
      name: (json['name'] ?? '').toString(),
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lon'] as num).toDouble(),
      ),
      segmentCount: (json['segment_count'] as num?)?.toInt() ?? 0,
    );
  }
}