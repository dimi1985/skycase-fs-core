import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:skycase/models/parking.dart';
import 'package:skycase/models/runways.dart';

// --- Background Parsers ---
List<Runway> _parseRunways(String jsonStr) {
  final List<dynamic> jsonList = json.decode(jsonStr);
  return jsonList.map((e) => Runway.fromJson(e)).toList();
}

List<ParkingSpot> _parseParking(String jsonStr) {
  final List<dynamic> jsonList = json.decode(jsonStr);
  return jsonList.map((e) => ParkingSpot.fromJson(e)).toList();
}

class AirportDetailsRepository {
  static final AirportDetailsRepository _instance = AirportDetailsRepository._internal();
  factory AirportDetailsRepository() => _instance;
  AirportDetailsRepository._internal();

  bool _runwaysLoaded = false;
  bool _parkingLoaded = false;

  final List<Runway> runways = [];
  final List<ParkingSpot> parkingSpots = [];

  Future<void> loadRunways() async {
    if (_runwaysLoaded) return;
    final jsonStr = await rootBundle.loadString('assets/data/runways.json');
    final list = await compute(_parseRunways, jsonStr);
    runways.addAll(list);
    _runwaysLoaded = true;
  }

  Future<void> loadParking() async {
    if (_parkingLoaded) return;
    final jsonStr = await rootBundle.loadString('assets/data/parking.json');
    final list = await compute(_parseParking, jsonStr);
    parkingSpots.addAll(list);
    _parkingLoaded = true;
  }
}