import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class AirportService {
  static final List<Map<String, dynamic>> _airports = [];

  static Future<void> loadAirports() async {
    final String jsonString = await rootBundle.loadString('assets/data/airports.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    _airports.clear();
    _airports.addAll(jsonList.cast<Map<String, dynamic>>());
    print("🛫 Loaded ${_airports.length} airports");
  }

  static String? findNearestICAO(double lat, double lng) {
    if (_airports.isEmpty) return null;

    final Distance distance = const Distance();
    final current = LatLng(lat, lng);

    double closestDistance = double.infinity;
    String? closestICAO;

    for (var airport in _airports) {
      final airportLat = (airport['lat'] as num).toDouble();
      final airportLng = (airport['lng'] as num).toDouble();
      final d = distance.as(LengthUnit.Kilometer, current, LatLng(airportLat, airportLng));

      if (d < closestDistance) {
        closestDistance = d;
        closestICAO = airport['icao'] ?? '';
      }
    }

    return closestICAO;
  }
}
