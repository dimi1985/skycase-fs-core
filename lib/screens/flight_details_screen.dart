import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skycase/screens/flight_route_map.dart';
import '../models/flight_log.dart';
import '../models/airport_location.dart';

class FlightDetailsScreen extends StatelessWidget {
  final FlightLog log;
  const FlightDetailsScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy • HH:mm');

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        title: const Text("Flight Recap"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _routeHeader(context),

            const SizedBox(height: 18),

            _sectionCard(
              context,
              title: "Aircraft",
              child: _rowText(log.aircraft),
            ),

            _sectionCard(
              context,
              title: "Flight Time",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _rowText(
                    "${dateFormat.format(log.startTime)} → ${dateFormat.format(log.endTime)}",
                  ),
                  const SizedBox(height: 6),
                  _subRow(
                    "Duration",
                    "${_formatDuration(log.duration)} (${log.duration} min)",
                  ),
                ],
              ),
            ),

            _sectionHeader(context, "Route"),
            _sectionCard(
              context,
              child: Column(
                children: [
                  _airportBlock(
                    icon: Icons.flight_takeoff,
                    title: "Departure",
                    loc: log.startLocation,
                  ),
                  const Divider(height: 24),
                  _airportBlock(
                    icon: Icons.flight_land,
                    title: "Arrival",
                    loc: log.endLocation,
                  ),
                  const Divider(height: 24),
                  _subRow(
                    "Distance Flown",
                    "${log.distanceFlown.toStringAsFixed(1)} NM",
                  ),
                ],
              ),
            ),

            _sectionHeader(context, "Performance"),
            _miniGrid(context, [
              _metric("Avg Speed", "${log.avgAirspeed} kt"),
              _metric("Max Alt", "${log.maxAltitude} ft"),
              _metric("Cruise", "${log.cruiseTime} min"),
            ]),

            _sectionHeader(context, "Flight Events"),
            _sectionCard(
              context,
              child: Column(
                children: [
                  _subRow(
                    "Takeoff",
                    log.events['takeoffScore']?.toString() ?? "N/A",
                  ),
                  _subRow(
                    "Landing",
                    log.events['butterScore']?.toString() ?? "N/A",
                  ),
                  _subRow(
                    "Hard Landing",
                    log.events['hardLanding'] == true ? "Yes" : "No",
                  ),
                ],
              ),
            ),

            _sectionHeader(context, "Turbulence"),
            _sectionCard(
              context,
              child: Column(
                children: [
                  _subRow(
                    "Light",
                    "${log.events['turbulenceCount']['light']} events",
                  ),
                  _subRow(
                    "Moderate",
                    "${log.events['turbulenceCount']['moderate']} events",
                  ),
                  _subRow(
                    "Severe",
                    "${log.events['turbulenceCount']['severe']} events",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _mapButton(context, colors),
          ],
        ),
      ),
    );
  }

  // =========================
  // ROUTE HEADER (ICAO + RWY + PARK)
  // =========================
  Widget _routeHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _icaoStack(log.startLocation),
          const Spacer(),
          Icon(Icons.flight, size: 30, color: colors.primary),
          const Spacer(),
          _icaoStack(log.endLocation),
        ],
      ),
    );
  }

  Widget _icaoStack(AirportLocation? loc) {
    final icao = _safe(loc?.icao, "UNK");
    final runway = _safe(loc?.runway, "—");
    final parking = _safe(loc?.parking, "—");

    return Column(
      children: [
        Text(
          icao,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "RWY $runway • P $parking",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // =========================
  // AIRPORT BLOCK (DETAIL)
  // =========================
  Widget _airportBlock({
    required IconData icon,
    required String title,
    required AirportLocation? loc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _safe(loc?.icao, "UNK"),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Runway: ${_safe(loc?.runway, "—")}   •   Parking: ${_safe(loc?.parking, "—")}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // UI HELPERS
  // =========================
  Widget _sectionCard(
    BuildContext context, {
    String? title,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            height: 18,
            width: 3,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: colors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  Widget _miniGrid(BuildContext context, List<Widget> items) {
    return Row(children: items.map((w) => Expanded(child: w)).toList());
  }

  Widget _metric(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _mapButton(BuildContext context, ColorScheme colors) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text("Flight Path Viewer")),
                body: FlightRouteMap(trail: log.trail),
              ),
            ),
          );
        },
        icon: const Icon(Icons.map),
        label: const Text("View Flight on Map"),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // =========================
  // SMALL UTILS
  // =========================
  String _safe(String? v, String fallback) =>
      (v == null || v.isEmpty) ? fallback : v;

  String _formatDuration(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return "${h}h ${m}m";
  }
}
