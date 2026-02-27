import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';

class AirportRepository {
  static final AirportRepository _instance = AirportRepository._internal();
  factory AirportRepository() => _instance;
  AirportRepository._internal();

  bool _loaded = false;

  final List<Airport> airports = [];
  final Map<String, Airport> byIcao = {};
  final Map<String, LatLng> coordsByIcao = {};

  Future<void> load() async {
    if (_loaded) return;

    final jsonStr = await rootBundle.loadString('assets/data/airports.json');
    final List<dynamic> jsonList = json.decode(jsonStr);

    for (final e in jsonList) {
      final airport = Airport.fromJson(e);
      airports.add(airport);
      byIcao[airport.icao] = airport;
      coordsByIcao[airport.icao] = LatLng(airport.lat, airport.lon);
    }

    _loaded = true;
    print('✈️ AirportRepository loaded (${airports.length} airports)');
  }

  Airport? find(String icao) => byIcao[icao.toUpperCase()];
}
