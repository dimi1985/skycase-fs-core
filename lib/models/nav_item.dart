import 'package:latlong2/latlong.dart';

class NavItem {
  final String id;      // ICAO or FIX ident
  final String name;    // Airport name or empty
  final LatLng coord;
  final String type;    // airport, WU, VOR, NDB...

  NavItem({
    required this.id,
    required this.name,
    required this.coord,
    required this.type,
  });
}
