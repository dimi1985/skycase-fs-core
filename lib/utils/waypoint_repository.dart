import 'dart:convert';
import 'package:flutter/foundation.dart'; // Απαραίτητο για το compute
import 'package:flutter/services.dart';
import 'package:skycase/models/waypoints.dart';

// 1. Η top-level function για το decode (ΕΚΤΟΣ της κλάσης)
List<Waypoint> _parseWaypoints(String jsonStr) {
  final List<dynamic> jsonList = json.decode(jsonStr);
  return jsonList.map((e) => Waypoint.fromJson(e)).toList();
}

class WaypointRepository {
  static final WaypointRepository _instance = WaypointRepository._internal();
  factory WaypointRepository() => _instance;
  WaypointRepository._internal();

  bool _loaded = false;
  final List<Waypoint> waypoints = [];

  Future<void> load() async {
    if (_loaded) return; // Αν έχει φορτώσει ήδη, μην ξανακάνεις τίποτα

    try {
      final jsonStr = await rootBundle.loadString('assets/data/waypoints.json');
      
      // 2. Η μαγεία του compute: Τρέχει στο παρασκήνιο
      final List<Waypoint> list = await compute(_parseWaypoints, jsonStr);

      waypoints.addAll(list);
      _loaded = true;
      print('🟢 WaypointRepository loaded (${waypoints.length} waypoints)');
    } catch (e) {
      print('❌ Error loading waypoints: $e');
    }
  }

  void clear() {
    waypoints.clear();
    _loaded = false;
  }
}