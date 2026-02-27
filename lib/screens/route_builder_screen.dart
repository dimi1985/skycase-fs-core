import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:skycase/models/airport.dart';
import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/services/flight_plan_service.dart';
import '../providers/route_builder_provider.dart';

class RouteBuilderScreen extends StatefulWidget {
  const RouteBuilderScreen({super.key});

  @override
  State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen> {
  final TextEditingController ctrl = TextEditingController();
  final MapController mapController = MapController(); // ⭐ NEW
  List<dynamic> results = [];

  @override
  void initState() {
    super.initState();
    context.read<RouteBuilderProvider>().loadData();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RouteBuilderProvider>();

    if (!vm.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final points = vm.route.map((e) => e.coord).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Route Builder")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ---------------- MAP ----------------
            SizedBox(
              height: 250,
              child: FlutterMap(
                mapController: mapController, // ⭐ CONTROLLER ENABLED
                options: MapOptions(
                  initialCenter:
                      points.isNotEmpty
                          ? points.first
                          : const LatLng(37.98, 23.72),
                  initialZoom: 6,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  ),
                  if (points.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          strokeWidth: 4,
                          color: Colors.cyanAccent,
                        ),
                      ],
                    ),
                  if (points.isNotEmpty)
                    MarkerLayer(
                      markers:
                          points
                              .map(
                                (p) => Marker(
                                  point: p,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                ],
              ),
            ),

            // ------------- SEARCH ---------------
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  TextField(
                    controller: ctrl,
                    onChanged: (q) {
                      setState(() => results = vm.search(q));
                    },
                    decoration: InputDecoration(
                      hintText: "Search ICAO / FIX / VOR / NDB / Waypoint",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ctrl.clear();
                          setState(() => results = []);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ---------- IMPORT ROUTE BUTTON ----------
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.note_add),
                      label: const Text("Paste SimBrief/Navigraph Route"),
                      onPressed: () => _openRouteImportDialog(vm),
                    ),
                  ),

                  if (results.isNotEmpty)
                    SizedBox(
                      height: 220,
                      child: Card(
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final item = results[i];

                            final bool isAirport = item is Airport;
                            final String title =
                                isAirport ? item.icao : item.ident;

                            final String subtitle =
                                isAirport
                                    ? "${item.name}\n${item.country}"
                                    : "${item.name ?? "Waypoint"}\nType: ${item.type}";

                            final LatLng coord =
                                isAirport
                                    ? LatLng(item.lat, item.lon)
                                    : LatLng(item.lat, item.lon);

                            return ListTile(
                              title: Text(title),
                              subtitle: Text(subtitle),
                              isThreeLine: true,
                              onTap: () {
                                vm.add(item);

                                // ⭐ MOVE MAP TO THIS POINT
                                Future.delayed(Duration(milliseconds: 150), () {
                                  mapController.move(coord, 10.0);
                                });

                                ctrl.clear();
                                setState(() => results = []);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ---------- ROUTE LIST ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "Route: ${vm.route.length} points — "
                "${vm.totalDistanceNm.toStringAsFixed(1)} NM",
                style: const TextStyle(fontSize: 14),
              ),
            ),

            SizedBox(
              height: 350,
              child: ReorderableListView.builder(
                itemCount: vm.route.length,
                onReorder: vm.reorder,
                itemBuilder: (_, i) {
                  final leg = vm.route[i];
                  return ListTile(
                    key: ValueKey("${leg.id}-$i"),
                    title: Text(leg.id),
                    subtitle: Text(
                      "${leg.lat.toStringAsFixed(4)}, "
                      "${leg.lon.toStringAsFixed(4)}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => vm.remove(i),
                    ),
                  );
                },
              ),
            ),

            ElevatedButton.icon(
              icon: Icon(Icons.save),
              label: Text("Save Route"),
              onPressed: () async {
                final vm = context.read<RouteBuilderProvider>();
                final userId = context.read<UserProvider>().user!.id;

                final f = vm.buildFlight("Generic", 8000, 0.0);
                await FlightPlanService.saveFlightPlan(f, userId);

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Route saved!")));
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openRouteImportDialog(RouteBuilderProvider vm) {
    final TextEditingController routeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Paste Route String"),
            content: TextField(
              controller: routeCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Example:\nLGAV KEA UL608 RDS LCA LCLK",
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _parseAndImportRoute(vm, routeCtrl.text.trim());
                },
                child: const Text("Import"),
              ),
            ],
          ),
    );
  }

  void _parseAndImportRoute(RouteBuilderProvider vm, String text) {
    if (text.isEmpty) return;

    // Split tokens by space
    final tokens =
        text
            .toUpperCase()
            .replaceAll("\n", " ")
            .split(" ")
            .where((t) => t.trim().isNotEmpty)
            .toList();

    // Clear current route
    vm.clear();

    int added = 0;
    LatLng? firstPoint;

    for (final token in tokens) {
      // Skip airways (UL608, J20, A3, B12...)
      if (RegExp(r"[A-Z]\d+").hasMatch(token)) continue;

      final match = vm.findExact(token);
      if (match == null) continue;

      vm.add(match);
      added++;

      if (firstPoint == null) {
        firstPoint = match.coord;
      }
    }

    if (added == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No matching waypoints found.")),
      );
      return;
    }

    // Center map on first
    Future.delayed(const Duration(milliseconds: 200), () {
      mapController.move(firstPoint!, 9.5);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Imported $added waypoints.")));
  }
}
