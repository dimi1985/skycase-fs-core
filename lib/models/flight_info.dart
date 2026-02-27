class FlightInfo {
  final String? origin;
  final String? destination;

  FlightInfo({this.origin, this.destination});

  factory FlightInfo.fromJson(Map<String, dynamic> j) {
    return FlightInfo(
      origin: j["origin"],
      destination: j["destination"],
    );
  }
}
