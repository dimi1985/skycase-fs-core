import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:skycase/models/airspace.dart';

class AirspacePolygon {
  final Airspace airspace;
  final List<LatLng> points;

  const AirspacePolygon({
    required this.airspace,
    required this.points,
  });
}

class AirspaceRepository {
  final List<Airspace> _airspaces = [];
  final List<AirspacePolygon> _polygons = [];

  List<Airspace> get airspaces => List.unmodifiable(_airspaces);
  List<AirspacePolygon> get polygons => List.unmodifiable(_polygons);

  Future<void> load({String assetPath = 'assets/data/airspace.json'}) async {
    final raw = await rootBundle.loadString(assetPath);
    final List<dynamic> data = jsonDecode(raw) as List<dynamic>;

    _airspaces
      ..clear()
      ..addAll(
        data
            .map((e) => Airspace.fromJson(e as Map<String, dynamic>))
            .where((a) => a.geometry.isNotEmpty),
      );

    _polygons.clear();

    for (final a in _airspaces) {
      final points = decodeAirspaceGeometry(a.geometry);

      if (points.length >= 3) {
        _polygons.add(AirspacePolygon(airspace: a, points: points));
      }
    }
  }

  static List<LatLng> decodeAirspaceGeometry(String encoded) {
    try {
      final bytes = base64.decode(encoded);
      final points = _decodePolyline(bytes);

      // HARD SAFETY FILTER
      final valid =
          points.where((p) {
            return p.latitude >= -90 &&
                p.latitude <= 90 &&
                p.longitude >= -180 &&
                p.longitude <= 180;
          }).toList();

      if (valid.length < 3) {
        return const [];
      }

      return valid;
    } catch (e) {
      return const [];
    }
  }

  static List<LatLng> _decodePolyline(Uint8List bytes) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < bytes.length) {
      int result = 0;
      int shift = 0;
      int b;

      do {
        if (index >= bytes.length) return points;
        b = bytes[index++] - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;

      do {
        if (index >= bytes.length) return points;
        b = bytes[index++] - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final point = LatLng(lat / 1e5, lng / 1e5);

      // Reject impossible coordinates immediately
      if (point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180) {
        return const [];
      }

      points.add(point);
    }

    return points;
  }
}