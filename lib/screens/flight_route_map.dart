import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/flight_trail_point.dart';

class FlightRouteMap extends StatelessWidget {
  final List<FlightTrailPoint> trail;
  const FlightRouteMap({super.key, required this.trail});

  @override
  Widget build(BuildContext context) {
    if (trail.isEmpty) {
      return Center(
        child: Text(
          "🪂 No flight path data available",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final latLngPoints = trail.map((e) => LatLng(e.lat, e.lng)).toList();

    // SAFETY: Center point fallback
    final center =
        latLngPoints.length == 1
            ? latLngPoints.first
            : LatLng(
              latLngPoints.map((e) => e.latitude).reduce((a, b) => a + b) /
                  latLngPoints.length,
              latLngPoints.map((e) => e.longitude).reduce((a, b) => a + b) /
                  latLngPoints.length,
            );

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AbsorbPointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 9,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.skycase',
                retinaMode: RetinaMode.isHighDensity(context),
              ),

              // 🔥 SAFETY: Only draw polyline if >= 2 points
              if (latLngPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: latLngPoints,
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),

              // 🔥 SAFETY: Only draw markers if >= 1 point
              MarkerLayer(
                markers: [
                  Marker(
                    point: latLngPoints.first,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.flight_takeoff,
                      color: Colors.green,
                    ),
                  ),

                  if (latLngPoints.length > 1)
                    Marker(
                      point: latLngPoints.last,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flight_land, color: Colors.red),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
