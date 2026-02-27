import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:skycase/models/flight.dart';
import 'package:skycase/models/waypoints.dart';
import '../models/airport.dart';

class RouteBuilderProvider extends ChangeNotifier {
  List<Airport> airports = [];
  List<Waypoint> waypoints = [];
  List<RouteLeg> route = [];

  bool loaded = false;

  Future<void> loadData() async {
    final apRaw = await rootBundle.loadString("assets/data/airports.json");
    final wpRaw = await rootBundle.loadString("assets/data/waypoints.json");

    airports = (jsonDecode(apRaw) as List)
        .map((e) => Airport.fromJson(e))
        .toList();

    waypoints = (jsonDecode(wpRaw) as List)
        .map((e) => Waypoint.fromJson(e))
        .toList();

    loaded = true;
    notifyListeners();
  }

  List<dynamic> search(String q) {
    q = q.toUpperCase().trim();
    if (q.isEmpty) return [];

    return [
      ...airports.where((a) => a.icao.contains(q)),
      ...waypoints.where((w) => w.ident.contains(q)),
    ];
  }

  void add(dynamic item) {
    if (item is Airport) {
      route.add(RouteLeg(
        id: item.icao,
        lat: item.lat,
        lon: item.lon,
        type: "airport",
      ));
    } else if (item is Waypoint) {
      route.add(RouteLeg(
        id: item.ident,
        lat: item.lat,
        lon: item.lon,
        type: item.type,
      ));
    }
    notifyListeners();
  }

  void remove(int i) {
    route.removeAt(i);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final leg = route.removeAt(oldIndex);
    route.insert(newIndex, leg);
    notifyListeners();
  }

  double get totalDistanceNm {
    if (route.length < 2) return 0;

    final d = Distance();
    double sum = 0;

    for (int i = 0; i < route.length - 1; i++) {
      final km = d.as(
        LengthUnit.Kilometer,
        route[i].coord,
        route[i + 1].coord,
      );
      sum += km / 1.852;
    }

    return sum;
  }

void clear() {
  route.clear();
  notifyListeners();
}

dynamic findExact(String ident) {
  final id = ident.toUpperCase();

  // ---------------------- AIRPORT MATCH ----------------------
  try {
    Airport a = airports.firstWhere(
      (x) => x.icao.toUpperCase() == id,
    );
    return a;
  } catch (e) {
    // No airport found
  }

  // ---------------------- WAYPOINT MATCH ----------------------
  try {
    Waypoint w = waypoints.firstWhere(
      (x) => x.ident.toUpperCase() == id,
    );
    return w;
  } catch (e) {
    // No waypoint found
  }

  return null;                // may be null
}

Flight buildFlight(
  String aircraftType,
  int cruiseAltitude,
  double plannedFuel,
) {
  if (route.isEmpty) {
    throw Exception("Route is empty — cannot build Flight");
  }

  final origin = route.first;
  final destination = route.last;

  final nm = totalDistanceNm;

  // Simple estimated time based on TAS 120kt
  const double tas = 120;
  final double hours = nm / tas;
  final estimatedTime = Duration(minutes: (hours * 60).round());

  // -----------------------------
  // BUILD WAYPOINT LIST
  // (CONVERT RouteLeg TO Waypoint)
  // -----------------------------
final List<Waypoint> wpList = route.map((w) {
  return Waypoint(
    id: null,           // runtime waypoint
    ident: w.id,
    name: null,
    lat: w.lat,
    lon: w.lon,
    type: w.type,
  );
}).toList();
  

  return Flight(
    id: "manual_route",
    originIcao: origin.id,
    destinationIcao: destination.id,
    generatedAt: DateTime.now(),
    aircraftType: aircraftType,
    estimatedDistanceNm: nm,
    estimatedTime: estimatedTime,
    originLat: origin.lat,
    originLng: origin.lon,
    destinationLat: destination.lat,
    destinationLng: destination.lon,
    cruiseAltitude: cruiseAltitude,
    plannedFuel: plannedFuel,
    missionId: null,
    waypoints: wpList.isEmpty ? null : wpList,
  );
}



}

class RouteLeg {
  final String id;
  final double lat;
  final double lon;
  final String type;

  RouteLeg({
    required this.id,
    required this.lat,
    required this.lon,
    required this.type,
  });

  LatLng get coord => LatLng(lat, lon);
}
