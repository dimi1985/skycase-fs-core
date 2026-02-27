class AirportLocation {
  final String icao;
  final String name;
  final double lat;
  final double lng;

  // 🆕 ADD THESE
  final String runway;
  final String parking;

  AirportLocation({
    required this.icao,
    required this.name,
    required this.lat,
    required this.lng,
    this.runway = '',
    this.parking = '',
  });

  factory AirportLocation.fromJson(Map<String, dynamic> json) {
    return AirportLocation(
      icao: json['icao'] ?? '',
      name: json['name'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      runway: json['runway'] ?? '',
      parking: json['parking'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'icao': icao,
        'name': name,
        'lat': lat,
        'lng': lng,
        'runway': runway,
        'parking': parking,
      };

  AirportLocation copyWith({
    String? runway,
    String? parking,
  }) {
    return AirportLocation(
      icao: icao,
      name: name,
      lat: lat,
      lng: lng,
      runway: runway ?? this.runway,
      parking: parking ?? this.parking,
    );
  }
}
