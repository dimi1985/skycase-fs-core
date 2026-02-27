import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:skycase/models/airport.dart';
import 'package:skycase/models/flight_log.dart';
import 'package:skycase/models/parking.dart';
import 'package:skycase/models/runways.dart';
import 'package:skycase/providers/home_arrival_provider.dart';
import 'package:skycase/screens/dispatch_board_screen.dart';
import 'package:skycase/screens/flight_logs_screen.dart';
import 'package:skycase/screens/map_screen.dart';
import 'package:skycase/screens/route_builder_screen.dart';
import 'package:skycase/screens/settings_screen.dart';
import 'package:skycase/services/flight_log_service.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/utils/airport_repository.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/widgets/flight_generator_screen.dart';

class HomeAirportSurfaceMap extends StatefulWidget {
  const HomeAirportSurfaceMap({super.key});

  @override
  State<HomeAirportSurfaceMap> createState() => _HomeAirportSurfaceMapState();
}

/* ────────────────────────────────────────────────────────────── */
/*  LAYOUT SYSTEM                                                  */
/* ────────────────────────────────────────────────────────────── */

enum AirportLayout { mobile, desktop }

AirportLayout _layoutFor(BoxConstraints c) =>
    c.maxWidth < 800 ? AirportLayout.mobile : AirportLayout.desktop;

class _AirportLayoutConfig {
  final double zoom;
  final double spacing;
  final double buildingSize;
  final double centerYOffsetMeters;

  const _AirportLayoutConfig({
    required this.zoom,
    required this.spacing,
    required this.buildingSize,
    required this.centerYOffsetMeters,
  });
}

_AirportLayoutConfig _layoutConfig(AirportLayout l) {
  return l == AirportLayout.mobile
      ? const _AirportLayoutConfig(
        zoom: 16.1,
        spacing: 1.9,
        buildingSize: 54,
        centerYOffsetMeters: -180, // 👈 adjust THIS
      )
      : const _AirportLayoutConfig(
        zoom: 16.5,
        spacing: 1.45,
        buildingSize: 68,
        centerYOffsetMeters: 0,
      );
}

String? _parkingCodeFromSpot(ParkingSpot p) {
  return "${p.name}${p.number}";
}

Future<String?> _resolveParkingCodeFromLogs(String airportIcao) async {
  try {
    final userId = await SessionManager.getUserId();
    if (userId == null) return null;

    final logs = await FlightLogService.getFlightLogs(userId);

    FlightLog? match;

    for (final log in logs) {
      if (log.endLocation?.icao?.toUpperCase() == airportIcao) {
        match = log;
        break;
      }
    }

    return match?.endLocation?.parking; // e.g. "G18"
  } catch (_) {
    return null;
  }
}

ParkingSpot? _findParkingByCode(List<ParkingSpot> spots, String? code) {
  if (code == null || code.isEmpty) return null;

  for (final p in spots) {
    if (_parkingCodeFromSpot(p) == code) {
      return p;
    }
  }
  return null;
}

/* ────────────────────────────────────────────────────────────── */
/*  STATE                                                         */
/* ────────────────────────────────────────────────────────────── */

class _HomeAirportSurfaceMapState extends State<HomeAirportSurfaceMap> {
  Airport? _airport;
  LatLng? _center;

  List<Runway> _runways = const [];
  List<ParkingSpot> _parking = const [];

  ParkingSpot? _activeParking;

  bool _loading = true;
  bool _failed = false;

  late final MapController _mapController;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _bootstrap();
  }

  /* ────────────────────────────────────────────────────────────── */
  /*  BOOTSTRAP                                                    */
  /* ────────────────────────────────────────────────────────────── */

  Future<void> _bootstrap() async {
    try {
      final repo = AirportRepository();
      await repo.load();

      final icao = await _resolveIcao();
      final airport = repo.find(icao);
      if (airport == null) return _fail();

      final center = LatLng(airport.lat, airport.lon);
      final parking = await _loadParking(icao);
      final runways = await _loadRunways(center);

      final parkingCodeFromLogs = await _resolveParkingCodeFromLogs(icao);

      final resolvedParking =
          _findParkingByCode(parking, parkingCodeFromLogs) ??
          _findNearestParking(center, parking);

      context.read<HomeArrivalProvider>().setArrival(
        icao: airport.icao,
        parking:
            resolvedParking != null
                ? _parkingCodeFromSpot(resolvedParking)
                : null,
      );

      if (!mounted) return;

      setState(() {
        _airport = airport;
        _center = center;
        _parking = parking;
        _runways = runways;
        _activeParking = resolvedParking;
        _loading = false;
      });
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _loading = false;
    });
  }

  /* ────────────────────────────────────────────────────────────── */
  /*  DATA LOADERS                                                 */
  /* ────────────────────────────────────────────────────────────── */

  Future<String> _resolveIcao() async {
    try {
      final userId = await SessionManager.getUserId();
      if (userId != null) {
        final logs = await FlightLogService.getFlightLogs(userId);
        final icao = logs.firstOrNull?.endLocation?.icao;
        if (icao != null) return icao.toUpperCase();
      }

      final token = await SessionManager.loadToken();
      if (token != null) {
        final hq = await UserService(
          baseUrl: "http://38.242.241.46:3000",
        ).getHq(token);
        if (hq?.icao != null) return hq!.icao.toUpperCase();
      }
    } catch (_) {}

    return "LGAV";
  }

  Future<List<ParkingSpot>> _loadParking(String icao) async {
    final raw = await rootBundle.loadString('assets/data/parking.json');
    final List<dynamic> jsonList = json.decode(raw);

    return jsonList
        .map((e) => ParkingSpot.fromJson(e))
        .where((p) => p.icao == icao)
        .toList(growable: false);
  }

  Future<List<Runway>> _loadRunways(LatLng center) async {
    final raw = await rootBundle.loadString('assets/data/runways.json');
    final List<dynamic> jsonList = json.decode(raw);

    const distance = Distance();

    return jsonList
        .map((e) => Runway.fromJson(e))
        .where((r) {
          final p1 = LatLng(r.end1Lat, r.end1Lon);
          final p2 = LatLng(r.end2Lat, r.end2Lon);
          return distance.as(LengthUnit.Meter, center, p1) < 9000 &&
              distance.as(LengthUnit.Meter, center, p2) < 9000;
        })
        .toList(growable: false);
  }

  ParkingSpot? _findNearestParking(LatLng center, List<ParkingSpot> spots) {
    if (spots.isEmpty) return null;

    const distance = Distance();
    ParkingSpot best = spots.first;
    double bestD = distance.as(
      LengthUnit.Meter,
      center,
      LatLng(best.lat, best.lon),
    );

    for (final p in spots.skip(1)) {
      final d = distance.as(LengthUnit.Meter, center, LatLng(p.lat, p.lon));
      if (d < bestD) {
        best = p;
        bestD = d;
      }
    }
    return best;
  }

  /* ────────────────────────────────────────────────────────────── */
  /*  GEO HELPERS                                                  */
  /* ────────────────────────────────────────────────────────────── */

  LatLng _offsetMeters(
    LatLng origin, {
    required double metersNorth,
    required double metersEast,
  }) {
    final lat = origin.latitude;
    final lon = origin.longitude;

    final dLat = metersNorth / 111320.0;
    final dLon = metersEast / (111320.0 * cos(lat * pi / 180));

    return LatLng(lat + dLat, lon + dLon);
  }

  LatLng _viewportAwareCenter(LatLng center, _AirportLayoutConfig cfg) {
    if (cfg.centerYOffsetMeters == 0) return center;

    return _offsetMeters(
      center,
      metersNorth: -cfg.centerYOffsetMeters, // 👈 ONLY this
      metersEast: 60,
    );
  }

  /* ────────────────────────────────────────────────────────────── */
  /*  ACTION BUILDINGS (RADIAL)                                     */
  /* ────────────────────────────────────────────────────────────── */

  List<_AirportAction> _actions(LatLng ref, _AirportLayoutConfig cfg) {
    LatLng radial(double deg, double meters) {
      final rad = deg * pi / 180;
      return _offsetMeters(
        ref,
        metersNorth: cos(rad) * meters * cfg.spacing,
        metersEast: sin(rad) * meters * cfg.spacing,
      );
    }

    return [
      _AirportAction("DISPATCH", Icons.assignment, radial(210, 70), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DispatchBoardScreen()),
        );
      }),

      _AirportAction("MAP", Icons.map, radial(90, 80), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }),

      _AirportAction("FLIGHTS", Icons.list_alt, radial(0, 85), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FlightLogsScreen()),
        );
      }),

      _AirportAction("FREE", Icons.flight_takeoff, radial(150, 85), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FlightGeneratorScreen()),
        );
      }),

      _AirportAction("ROUTE", Icons.alt_route, radial(330, 75), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RouteBuilderScreen()),
        );
      }),

      _AirportAction("SET", Icons.settings, radial(30, 75), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      }),
    ];
  }

  /* ────────────────────────────────────────────────────────────── */
  /*  BUILD                                                       */
  /* ────────────────────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed || _center == null) {
      return const Center(
        child: Text(
          "Airport surface unavailable",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _layoutFor(constraints);
        final cfg = _layoutConfig(layout);

        final baseCenter =
            _activeParking != null
                ? LatLng(_activeParking!.lat, _activeParking!.lon)
                : _center!;

        final center = _viewportAwareCenter(baseCenter, cfg);

        final newSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (_lastSize != newSize) {
          _lastSize = newSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(center, cfg.zoom);
            }
          });
        }

        final ref =
            _activeParking != null
                ? LatLng(_activeParking!.lat, _activeParking!.lon)
                : center;

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: cfg.zoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  retinaMode: false,
                  urlTemplate:
                      "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),

                PolylineLayer(
                  polylines:
                      _runways
                          .map(
                            (r) => Polyline(
                              points: [
                                LatLng(r.end1Lat, r.end1Lon),
                                LatLng(r.end2Lat, r.end2Lon),
                              ],
                              strokeWidth: (r.width / 10).clamp(2, 8),
                              color: Colors.white.withOpacity(0.7),
                            ),
                          )
                          .toList(),
                ),

                MarkerLayer(
                  markers:
                      _parking.map((p) {
                        final isActive = identical(p, _activeParking);

                        return Marker(
                          point: LatLng(p.lat, p.lon),
                          width: isActive ? 24 : 12,
                          height: isActive ? 24 : 12,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  p.hasJetway
                                      ? Colors.lightBlueAccent
                                      : Colors.orangeAccent,
                              boxShadow:
                                  isActive
                                      ? [
                                        BoxShadow(
                                          color: Colors.cyanAccent.withOpacity(
                                            0.7,
                                          ),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                      : null,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                if (_activeParking != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(_activeParking!.lat, _activeParking!.lon),
                        width: 42,
                        height: 42,
                        child: Transform.rotate(
                          angle: _activeParking!.heading * pi / 180,
                          child: const Icon(
                            Icons.airplanemode_active,
                            size: 36,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // 👇 BOTTOM ACTION BAR
            _bottomActionBar(cfg),
          ],
        );
      },
    );
  }

  Widget _airportBuilding(_AirportAction a) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    a.icon,
                    color: Colors.cyanAccent,
                    size: c.maxHeight * 0.38, // 🔥 proportional
                  ),
                  SizedBox(height: c.maxHeight * 0.05),
                  SizedBox(
                    height: c.maxHeight * 0.22, // 🔥 hard cap
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        a.label,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bottomActionBar(_AirportLayoutConfig cfg) {
    final actions = _actions(_center!, cfg);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 20,
      child: SafeArea(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children:
                    actions.map((a) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: GestureDetector(
                          onTap: a.onTap,
                          child: SizedBox(
                            width: cfg.buildingSize * 0.9,
                            height: cfg.buildingSize * 0.9,
                            child: _airportBuilding(a),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────── */
/*  ACTION MODEL                                                  */
/* ────────────────────────────────────────────────────────────── */

class _AirportAction {
  final String label;
  final IconData icon;
  final LatLng position;
  final VoidCallback onTap;

  const _AirportAction(this.label, this.icon, this.position, this.onTap);
}
