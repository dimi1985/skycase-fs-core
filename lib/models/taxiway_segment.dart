import 'package:latlong2/latlong.dart';

class TaxiwaySegment {
  final String airportIcao;
  final String type;
  final String surface;
  final double width;
  final bool drawSurface;
  final bool drawDetail;
  final LatLng start;
  final LatLng end;

  TaxiwaySegment({
    required this.airportIcao,
    required this.type,
    required this.surface,
    required this.width,
    required this.drawSurface,
    required this.drawDetail,
    required this.start,
    required this.end,
  });

  factory TaxiwaySegment.fromJson(Map<String, dynamic> json) {
    return TaxiwaySegment(
      airportIcao: json['airport_icao'],
      type: json['type'],
      surface: json['surface'],
      width: (json['width'] as num).toDouble(),
      drawSurface: json['is_draw_surface'] == 1,
      drawDetail: json['is_draw_detail'] == 1,
      start: LatLng(
        (json['start_lat'] as num).toDouble(),
        (json['start_lon'] as num).toDouble(),
      ),
      end: LatLng(
        (json['end_lat'] as num).toDouble(),
        (json['end_lon'] as num).toDouble(),
      ),
    );
  }
}
