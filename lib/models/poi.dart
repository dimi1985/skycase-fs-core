class Poi {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String type; // historic | landmark | natural | weird
  final String shortDescription;
  final String description;
  final String? country;
  final String? era;

  const Poi({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    required this.shortDescription,
    required this.description,
    this.country,
    this.era,
  });
}