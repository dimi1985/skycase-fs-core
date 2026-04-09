import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';

// 1. Η top-level function για το background parsing
List<Airport> _parseAirports(String jsonStr) {
  final List<dynamic> jsonList = json.decode(jsonStr);
  return jsonList.map((e) => Airport.fromJson(e)).toList();
}

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

    try {
      final jsonStr = await rootBundle.loadString('assets/data/airports.json');
      
      // 2. ΕΔΩ ΕΙΝΑΙ Η ΑΛΛΑΓΗ: Χρησιμοποιούμε compute
      final List<Airport> list = await compute(_parseAirports, jsonStr);

      for (final airport in list) {
        airports.add(airport);
        byIcao[airport.icao] = airport;
        coordsByIcao[airport.icao] = LatLng(airport.lat, airport.lon);
      }

      _loaded = true;
      print('✈️ AirportRepository loaded via Isolate (${airports.length} airports)');
    } catch (e) {
      print('❌ Error loading airports: $e');
    }
  }

  Airport? find(String icao) => byIcao[icao.toUpperCase()];
}