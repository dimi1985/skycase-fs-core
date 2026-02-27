class OpenSkyAircraft {
  final String icao;
  final String callsign;
  final double lat;
  final double lon;
  final double altitude; // meters
  final double heading;  // degrees
  final double speed;    // m/s

  OpenSkyAircraft({
    required this.icao,
    required this.callsign,
    required this.lat,
    required this.lon,
    required this.altitude,
    required this.heading,
    required this.speed,
  });

  factory OpenSkyAircraft.fromState(List<dynamic> s) {
    return OpenSkyAircraft(
      icao: s[0] ?? "",
      callsign: (s[1] ?? "").trim(),
      lat: (s[6] ?? 0.0).toDouble(),
      lon: (s[5] ?? 0.0).toDouble(),
      altitude: (s[7] ?? 0.0).toDouble(),
      heading: (s[10] ?? 0.0).toDouble(),
      speed: (s[9] ?? 0.0).toDouble(),
    );
  }
}
