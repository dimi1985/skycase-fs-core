import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class WeatherOverlays {
  static List<Widget> build({
    required LatLng point,
    required Map<String, dynamic> wx,
  }) {
    final List<Widget> layers = [];

    // SAFE EXTRACTIONS
    final raw = (wx["raw"] ?? "").toString();
    final clouds = (wx["clouds"] ?? const []) as List<dynamic>;
    final visMeters = wx["visibilityMeters"] ?? 9999;

    // 🌧️ RAIN
    if (raw.contains("RA") || raw.contains("SHRA") || raw.contains("+RA")) {
      layers.add(_circle(
        point,
        9000,
        Colors.blue.withOpacity(0.18),
        Colors.blueAccent,
      ));
    }

    // ⛈️ THUNDERSTORM
    if (raw.contains("TS")) {
      layers.add(_circle(
        point,
        12000,
        Colors.orange.withOpacity(0.20),
        Colors.deepOrangeAccent,
      ));
    }

    // 🌫️ FOG (low visibility)
    if (visMeters < 2000) {
      layers.add(_circle(
        point,
        15000,
        Colors.grey.withOpacity(0.15),
        Colors.grey,
      ));
    }

    // ☁️ CLOUDS
    for (final c in clouds) {
      if (c is! String || c.length < 6) continue;

      final code = c.substring(0, 3);
      final base = c.substring(3, 6);

      layers.add(_cloudMarker(point, "$code $base", code));
    }

    return layers;
  }

  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------

  static Widget _circle(
    LatLng p,
    double radius,
    Color fill,
    Color border,
  ) {
    return CircleLayer(
      circles: [
        CircleMarker(
          point: p,
          radius: radius,
          useRadiusInMeter: true,
          color: fill,
          borderColor: border,
          borderStrokeWidth: 2,
        ),
      ],
    );
  }

  static Widget _cloudMarker(LatLng p, String text, String code) {
    final color = switch (code) {
      "FEW" => Colors.white70,
      "SCT" => Colors.white,
      "BKN" => Colors.orangeAccent,
      "OVC" => Colors.redAccent,
      _ => Colors.white,
    };

    return MarkerLayer(
      markers: [
        Marker(
          point: p,
          width: 52,
          height: 52,
          child: Column(
            children: [
              Icon(Icons.cloud, color: color, size: 38),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
