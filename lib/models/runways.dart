class Runway {
  final int airportId;
  final int runwayId;
  final double length;
  final double width;
  final String surface;

  final String end1Ident;
  final double end1Lat;
  final double end1Lon;
  final double end1Heading;
  final double end1Altitude;

  final String end2Ident;
  final double end2Lat;
  final double end2Lon;
  final double end2Heading;
  final double end2Altitude;

  Runway({
    required this.airportId,
    required this.runwayId,
    required this.length,
    required this.width,
    required this.surface,
    required this.end1Ident,
    required this.end1Lat,
    required this.end1Lon,
    required this.end1Heading,
    required this.end1Altitude,
    required this.end2Ident,
    required this.end2Lat,
    required this.end2Lon,
    required this.end2Heading,
    required this.end2Altitude,
  });

  factory Runway.fromJson(Map<String, dynamic> j) {
    return Runway(
      airportId: j['airport_id'],
      runwayId: j['runway_id'],
      length: (j['length'] ?? 0).toDouble(),
      width: (j['width'] ?? 0).toDouble(),
      surface: j['surface'] ?? '',

      end1Ident: j['end1_ident'] ?? '',
      end1Lat: (j['end1_lat'] ?? 0).toDouble(),
      end1Lon: (j['end1_lon'] ?? 0).toDouble(),
      end1Heading: (j['end1_heading'] ?? 0).toDouble(),
      end1Altitude: (j['end1_altitude'] ?? 0).toDouble(),

      end2Ident: j['end2_ident'] ?? '',
      end2Lat: (j['end2_lat'] ?? 0).toDouble(),
      end2Lon: (j['end2_lon'] ?? 0).toDouble(),
      end2Heading: (j['end2_heading'] ?? 0).toDouble(),
      end2Altitude: (j['end2_altitude'] ?? 0).toDouble(),
    );
  }
}
