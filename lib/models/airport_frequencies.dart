class AirportFrequency {
  final String airportIdent;
  final String airportName;
  final String? description;
  final int frequency; // in kHz * 100?
  final String type;

  AirportFrequency({
    required this.airportIdent,
    required this.airportName,
    required this.description,
    required this.frequency,
    required this.type,
  });

  factory AirportFrequency.fromJson(Map<String, dynamic> j) {
    return AirportFrequency(
      airportIdent: j['airport_ident'] ?? '',
      airportName: j['airport_name'] ?? '',
      description: j['description'],
      frequency: j['frequency'] ?? 0,
      type: j['frequency_type'] ?? '',
    );
  }
}
