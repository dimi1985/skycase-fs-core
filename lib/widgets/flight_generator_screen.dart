import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skycase/models/airport_location.dart';
import 'package:skycase/models/flight.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/models/aircraft_template.dart';
import 'package:skycase/models/dispatch_job.dart';

import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/services/flight_plan_service.dart';
import 'package:skycase/services/dispatch_service.dart';

import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/providers/unit_system_provider.dart';
import 'package:uuid/uuid.dart';

class FlightGeneratorScreen extends StatefulWidget {
  const FlightGeneratorScreen({super.key});

  @override
  State<FlightGeneratorScreen> createState() => _FlightGeneratorScreenState();
}

class _FlightGeneratorScreenState extends State<FlightGeneratorScreen> {
  // -------------------------------
  // USER SETTINGS (Units)
  // -------------------------------
  bool get isMetric => context.read<UnitSystemProvider>().isMetric;

  // -------------------------------
  // DATA SOURCES
  // -------------------------------
  List<AirportLocation> _airports = [];
  Map<String, LatLng> _coords = {};

  List<AircraftTemplate> _templates = [];
  AircraftTemplate? _selectedTemplate;

  // -------------------------------
  // LIVE SIM VARIABLES
  // -------------------------------
  SimLinkData? get sim => SimLinkSocketService().latestData;

  // -------------------------------
  // DISPATCH JOB (ACTIVE)
  // -------------------------------
  DispatchJob? activeJob;

  // -------------------------------
  // UI STATE
  // -------------------------------
  int _originMode = 0; // 0=HQ, 1=Last, 2=Live, 3=Manual
  double _maxDistance = 100;

  String? _hqIcao;
  String? _lastIcao;

  String? _customOrigin;
  String? _customDest;

  final _customOriginCtrl = TextEditingController();
  final _customDestCtrl = TextEditingController();

  bool _useLiveAircraft = true;
  bool _fuelDetail = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadAirportDB();
    _loadTemplates();
    _loadActiveJob();
  }

  // ---------------------------------------------------------
  // LOAD USER PREFS (HQ ICAO, LAST ICAO)
  // ---------------------------------------------------------
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hqIcao = prefs.getString("homebase_icao");
      _lastIcao = prefs.getString("last_destination_icao");
      _maxDistance = prefs.getDouble("flight_max_distance_nm") ?? 100;
    });
  }

  // ---------------------------------------------------------
  // LOAD AIRPORT DATABASE
  // ---------------------------------------------------------
  Future<void> _loadAirportDB() async {
    final raw = await rootBundle.loadString("assets/data/airports.json");
    final list = jsonDecode(raw);

    final List<AirportLocation> tempAirports = [];
    final Map<String, LatLng> tempCoords = {};

    for (final a in list) {
      final icao = a["icao"];
      final lat = a["lat"]?.toDouble();
      final lon = a["lon"]?.toDouble();
      final name = a["name"] ?? "";

      if (icao != null && lat != null && lon != null) {
        tempAirports.add(
          AirportLocation.fromJson({
            "icao": icao,
            "name": name,
            "lat": lat,
            "lng": lon,
          }),
        );
        tempCoords[icao] = LatLng(lat, lon);
      }
    }

    setState(() {
      _airports = tempAirports;
      _coords = tempCoords;
    });
  }

  // ---------------------------------------------------------
  // LOAD AIRCRAFT TEMPLATES
  // ---------------------------------------------------------
  Future<void> _loadTemplates() async {
    final raw = await rootBundle.loadString(
      "assets/data/aircraft_templates.json",
    );
    final list = jsonDecode(raw);

    setState(() {
      _templates =
          (list as List).map((e) => AircraftTemplate.fromJson(e)).toList();
    });
  }

  // ---------------------------------------------------------
  // LOAD ACTIVE DISPATCH JOB
  // ---------------------------------------------------------
  Future<void> _loadActiveJob() async {
    final userId = await SessionManager.getUserId();
    if (userId == null) return;

    final res = await DispatchService.getActiveJob(userId);
    if (res == null) return;

    setState(() => activeJob = DispatchJob.fromJson(res));
  }

  // ---------------------------------------------------------
  // ORIGIN LATLNG GETTER (HQ / LAST / LIVE / MANUAL)
  // ---------------------------------------------------------
  LatLng? get _originLatLng {
    switch (_originMode) {
      case 0: // HQ
        return _coords[_hqIcao];
      case 1: // Last Flight
        return _coords[_lastIcao];
      case 2: // Live Aircraft Pos
        return sim != null ? LatLng(sim!.latitude, sim!.longitude) : null;
      case 3: // Manual
        return _coords[_customOrigin?.toUpperCase()];
    }
    return null;
  }

  String get _originIcao {
    switch (_originMode) {
      case 0:
        return _hqIcao ?? "";
      case 1:
        return _lastIcao ?? "";
      case 2:
        return "LIVEPOS";
      case 3:
        return _customOrigin?.toUpperCase() ?? "";
    }
    return "";
  }

  LatLng? get _manualDestLatLng {
    if (_originMode != 3) return null;
    if (_customDest == null) return null;
    return _coords[_customDest!.toUpperCase()];
  }

  // ---------------------------------------------------------
  // DISTANCE CALCULATOR
  // ---------------------------------------------------------
  double _distNm(LatLng a, LatLng b) {
    return vincentyDistanceNm(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  double _rad(double x) => x * pi / 180;

  // ---------------------------------------------------------
  // CRUISE SPEED (LIVE OR TEMPLATE)
  // ---------------------------------------------------------
  double _cruiseSpeedKts() {
    if (_useLiveAircraft && sim != null) {
      return switch (sim!.engineType) {
        0 => 110, // piston
        1 => 450, // jet
        3 => 120, // heli
        5 => 230, // turboprop
        _ => 150,
      };
    }

    if (_selectedTemplate != null) return _selectedTemplate!.cruiseSpeed;

    return 150;
  }

  // ---------------------------------------------------------
  // FUEL DENSITY (AVGAS or Jet-A)
  // ---------------------------------------------------------
  double _fuelDensity() {
    // Live aircraft determines fuel type
    if (_useLiveAircraft && sim != null) {
      return (sim!.engineType == 0) ? 6.0 : 6.7;
    }

    // Template determines fuel type
    return _selectedTemplate?.fuelDensity ?? 6.0;
  }

  // ---------------------------------------------------------
  // SEMI-REALISTIC FUEL PLANNING
  // ---------------------------------------------------------
  Map<String, double> computeFuel(double distanceNm) {
    // --------------------------------------------------
    // FLIGHT PROFILE
    // --------------------------------------------------
    final cruiseSpeedKts = _cruiseSpeedKts();
    final flightHours = distanceNm / cruiseSpeedKts;

    // --------------------------------------------------
    // BASE ENROUTE BURN
    // --------------------------------------------------
    final burnGph = _selectedTemplate?.fuelBurn ?? 46.0;
    final enrouteFuel = burnGph * flightHours;

    // --------------------------------------------------
    // FIXED OPERATIONAL FUEL
    // --------------------------------------------------
    const taxiFuel = 3.0;
    const climbFuel = 5.0;
    const reserveFuel = 30.0;

    // --------------------------------------------------
    // DISPATCH REQUIREMENTS
    // --------------------------------------------------
    final requiredJobFuel = activeJob?.requiredFuelGallons.toDouble() ?? 0.0;

    final payloadPenaltyFuel = _payloadPenaltyFuel(distanceNm);

    // --------------------------------------------------
    // TOTAL REQUIRED ON BOARD
    // --------------------------------------------------
    final totalGallons =
        enrouteFuel +
        taxiFuel +
        climbFuel +
        reserveFuel +
        requiredJobFuel +
        payloadPenaltyFuel;

    // --------------------------------------------------
    // UNIT CONVERSION
    // --------------------------------------------------
    final density = _fuelDensity(); // lbs / gal
    final fuelLbs = totalGallons * density;
    final fuelKg = fuelLbs * 0.453592;

    return {
      "gal": totalGallons,
      "lbs": fuelLbs,
      "kg": fuelKg,
      "enroute": enrouteFuel,
      "required": requiredJobFuel,
      "payloadPenalty": payloadPenaltyFuel,
    };
  }

  // ---------------------------------------------------------
  // JOB CARGO → PAYLOAD WEIGHT
  // ---------------------------------------------------------
  num jobPayloadWeightLbs() {
    if (activeJob == null) return 0;

    final cargo = activeJob!.payloadLbs;
    final pax = activeJob!.paxCount * 170; // standard pax weight
    final fuelCargo = activeJob!.transferFuelGallons * 6;

    return cargo + pax + fuelCargo;
  }

  // ---------------------------------------------------------
  // MTOW CHECK (WARNING ONLY)
  // ---------------------------------------------------------
  String? mtowWarning({required double plannedFuelLbs}) {
    if (_useLiveAircraft && sim != null) {
      final simW = sim!.weights;
      final jobPayload = jobPayloadWeightLbs();
      final zfw = simW.emptyWeight + jobPayload;

      final gross = zfw + plannedFuelLbs;
      final limit = simW.maxTakeoffWeight;

      if (gross > limit) {
        final exceed = gross - limit;
        return "⚠ MTOW exceeded by ${exceed.toStringAsFixed(0)} lbs";
      }
    }
    return null;
  }

  // ---------------------------------------------------------
  // SHOW DIALOG
  // ---------------------------------------------------------
  void _info(String msg) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Flight Created"),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("Back"),
              ),
            ],
          ),
    );
  }

  // ---------------------------------------------------------
  // SNACK
  // ---------------------------------------------------------
  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------
  // GENERATE FLIGHT
  // ---------------------------------------------------------
  Future<void> _generate() async {
    final origin = _originLatLng;
    if (origin == null) {
      _snack("Invalid origin ICAO.");
      return;
    }

    // MANUAL MODE
    if (_originMode == 3) {
      final dest = _manualDestLatLng;
      if (dest == null) {
        _snack("Invalid destination ICAO.");
        return;
      }

      final dist = _distNm(origin, dest);
      await _finalizeFlight(
        originIcao: _customOrigin!.toUpperCase(),
        destIcao: _customDest!.toUpperCase(),
        originLat: origin.latitude,
        originLng: origin.longitude,
        destLat: dest.latitude,
        destLng: dest.longitude,
        distanceNm: dist,
      );
      return;
    }

    // AUTO SELECT DESTINATION
    final filtered =
        _airports.where((a) {
          final c = _coords[a.icao];
          if (c == null) return false;
          final d = _distNm(origin, c);
          if (d < 15 || d > _maxDistance) return false;
          if (a.icao == _originIcao) return false;
          return true;
        }).toList();

    if (filtered.isEmpty) {
      _snack("No destinations found.");
      return;
    }

    filtered.shuffle();
    final chosen = filtered.first;
    final dest = _coords[chosen.icao]!;

    await _finalizeFlight(
      originIcao: _originIcao,
      destIcao: chosen.icao,
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: dest.latitude,
      destLng: dest.longitude,
      distanceNm: _distNm(origin, dest),
    );
  }

  // ---------------------------------------------------------
  // CREATE FINAL FLIGHT OBJECT
  // ---------------------------------------------------------
  Future<void> _finalizeFlight({
    required String originIcao,
    required String destIcao,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double distanceNm,
  }) async {
    final speed = _cruiseSpeedKts();
    final etaMin = (distanceNm / speed * 60).round();

    final fuel = computeFuel(distanceNm);
    final gal = fuel["gal"]!;
    final lbs = fuel["lbs"]!;

    final extraPayload = jobPayloadWeightLbs();
    final totalPayload = extraPayload;

    final warning = mtowWarning(plannedFuelLbs: lbs);
    if (warning != null) _snack(warning);

    final templateName =
        _useLiveAircraft && sim != null
            ? sim!.title
            : _selectedTemplate?.name ?? "Unknown";

    final flight = Flight(
      id: const Uuid().v4(),
      originIcao: originIcao,
      destinationIcao: destIcao,
      generatedAt: DateTime.now(),
      aircraftType: templateName,
      estimatedDistanceNm: distanceNm,
      estimatedTime: Duration(minutes: etaMin),
      originLat: originLat,
      originLng: originLng,
      destinationLat: destLat,
      destinationLng: destLng,
      missionId: null,
      cruiseAltitude: _recommendedAltitude(distanceNm),
      plannedFuel: gal, // ALWAYS SAVE IN GALLONS INTERNALLY
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("last_flight", jsonEncode(flight.toJson()));

    final userId = await SessionManager.getUserId();
    if (userId != null) {
      await FlightPlanService.saveFlightPlan(flight, userId);
    }

    final unitFuel =
        isMetric
            ? "${fuel["kg"]!.toStringAsFixed(1)} kg"
            : "${fuel["gal"]!.toStringAsFixed(1)} gal";

    _info("""
From: $originIcao
To:   $destIcao

Distance: ${distanceNm.toStringAsFixed(1)} NM
Time:     ${etaMin} min
Fuel:     $unitFuel

Payload (job included): ${totalPayload.toStringAsFixed(0)} lbs
Aircraft: $templateName
""");
  }

  // ---------------------------------------------------------
  // ALTITUDE SUGGESTION
  // ---------------------------------------------------------
  int _recommendedAltitude(double nm) {
    if (nm < 20) return 1500;
    if (nm < 50) return 3000;
    if (nm < 100) return 5000;
    if (nm < 160) return 8000;
    if (nm < 250) return 10000;
    if (nm < 350) return 12000;
    if (nm < 500) return 14000;
    if (nm < 700) return 16000;
    if (nm < 1000) return 18000;
    return 22000;
  }

  Map<String, double>? get _fuelSnapshot {
    if (_originLatLng == null) return null;
    return computeFuel(_currentDistanceNm);
  }

  double get _currentDistanceNm {
    if (_originLatLng == null) return _maxDistance;

    if (_originMode == 3 && _manualDestLatLng != null) {
      return _distNm(_originLatLng!, _manualDestLatLng!);
    }

    return _maxDistance;
  }

  // ---------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final simConnected = sim != null;
    final fuel = _fuelSnapshot;

    return Scaffold(
      appBar: AppBar(title: const Text("Flight Generator")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // ORIGIN
            // ==================================================
            const Text(
              "✈ Origin",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _originBtn(
                  "HQ",
                  Icons.home_filled,
                  0,
                  _hqIcao ?? "—",
                  enabled: _hqIcao != null,
                ),
                _originBtn(
                  "Last",
                  Icons.history,
                  1,
                  _lastIcao ?? "—",
                  enabled: _lastIcao != null,
                ),
                _originBtn(
                  "Live",
                  Icons.gps_fixed,
                  2,
                  "GPS",
                  enabled: simConnected,
                ),
                _originBtn("Manual", Icons.edit_location, 3, ""),
              ],
            ),

            const SizedBox(height: 22),

            if (_originMode == 3) ...[
              TextField(
                controller: _customOriginCtrl,
                maxLength: 4,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "Origin ICAO",
                  border: OutlineInputBorder(),
                ),
                onChanged:
                    (v) => setState(() => _customOrigin = v.toUpperCase()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _customDestCtrl,
                maxLength: 4,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "Destination ICAO",
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _customDest = v.toUpperCase()),
              ),
              const SizedBox(height: 20),
            ],

            // ==================================================
            // RANGE
            // ==================================================
            if (_originMode != 3) ...[
              Text("Max Distance: ${_maxDistance.toInt()} NM"),
              Slider(
                value: _maxDistance,
                min: 25,
                max: 1000,
                onChanged: (v) => setState(() => _maxDistance = v),
              ),
              const SizedBox(height: 20),
            ],

            // ==================================================
            // AIRCRAFT
            // ==================================================
            const Text(
              "🛩 Aircraft",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (simConnected)
              SwitchListTile(
                title: const Text("Use Live Aircraft"),
                value: _useLiveAircraft,
                onChanged: (v) => setState(() => _useLiveAircraft = v),
              ),

            if (!_useLiveAircraft)
              DropdownButton<AircraftTemplate>(
                isExpanded: true,
                hint: const Text("Select Template"),
                value: _selectedTemplate,
                items:
                    _templates
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _selectedTemplate = v),
              ),

            const SizedBox(height: 24),

            // ==================================================
            // FUEL PANEL
            // ==================================================
            if (fuel != null) _fuelPanel(),

            const SizedBox(height: 30),

            // ==================================================
            // JOB IMPACT
            // ==================================================
            if (activeJob != null && fuel != null)
              Card(
                color: Colors.grey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "JOB IMPACT",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        "Payload weight: ${jobPayloadWeightLbs().toStringAsFixed(0)} lbs",
                        style: const TextStyle(color: Colors.white70),
                      ),

                      if (fuel["payloadPenalty"]! > 0)
                        Text(
                          "Payload penalty fuel: +${fuel["payloadPenalty"]!.toStringAsFixed(1)} gal",
                          style: const TextStyle(color: Colors.white70),
                        ),

                      if (activeJob!.needsFuel)
                        Text(
                          "Mission-required fuel: +${fuel["required"]!.toStringAsFixed(1)} gal",
                          style: const TextStyle(color: Colors.white70),
                        ),

                      if (_useLiveAircraft && sim != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            mtowWarning(plannedFuelLbs: fuel["lbs"]!) ??
                                "MTOW: OK",
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 30),

            // ==================================================
            // ACTION
            // ==================================================
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flight_takeoff),
                label: const Text("Generate Flight"),
                onPressed: _generate,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // ORIGIN BUTTON
  // ---------------------------------------------------------
  Widget _originBtn(
    String title,
    IconData icon,
    int mode,
    String sub, {
    bool enabled = true,
  }) {
    final selected = _originMode == mode;

    return GestureDetector(
      onTap: enabled ? () => setState(() => _originMode = mode) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        width: 130,
        decoration: BoxDecoration(
          color: enabled ? Colors.grey.shade800 : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: enabled ? Colors.white : Colors.grey),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: enabled ? Colors.white : Colors.grey,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.grey,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // FUEL PANEL
  // ---------------------------------------------------------
  Widget _fuelPanel() {
    final distance =
        _originMode == 3 && _manualDestLatLng != null
            ? _distNm(_originLatLng!, _manualDestLatLng!)
            : _maxDistance;

    final f = computeFuel(distance);
    final density = _fuelDensity();

    final gal = f["gal"]!;
    final lbs = f["lbs"]!;
    final kg = f["kg"]!;

    final unitFuel =
        isMetric
            ? "${kg.toStringAsFixed(1)} kg"
            : "${gal.toStringAsFixed(1)} gal";

    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "⛽ Fuel Estimate",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _fuelDetail = !_fuelDetail),
                  child: Text(_fuelDetail ? "Simple" : "Details"),
                ),
              ],
            ),

            Text("Distance: ${distance.toStringAsFixed(1)} NM"),
            Text("Fuel Needed: $unitFuel"),
            const SizedBox(height: 10),

            if (_fuelDetail) ...[
              Text("Enroute:  ${f["enroute"]!.toStringAsFixed(1)} gal"),
              const Text("Taxi:     3 gal"),
              const Text("Climb:    5 gal"),
              const Text("Reserve:  30 gal"),
              const SizedBox(height: 6),
              Text("Total:    ${gal.toStringAsFixed(1)} gal"),
              Text("In lbs:   ${lbs.toStringAsFixed(1)} lbs"),
            ],
          ],
        ),
      ),
    );
  }

  double _extraFuelFromJob(double distanceNm) {
    if (activeJob == null) return 0;

    if (activeJob!.type == "fuel") return 0;
    final payload = jobPayloadWeightLbs();
    if (payload <= 0) return 0;

    // Cruise speed → hours
    final speed = _cruiseSpeedKts();
    final hours = distanceNm / speed;

    // Semi-realistic: +1 gal/hr for every 200 lbs
    return (payload / 200.0) * hours;
  }

  double vincentyDistanceNm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double a = 6378137.0; // WGS-84 ellipsoid major axis
    const double f = 1 / 298.257223563;
    final double b = (1 - f) * a;

    double L = _rad(lon2 - lon1);
    double U1 = atan((1 - f) * tan(_rad(lat1)));
    double U2 = atan((1 - f) * tan(_rad(lat2)));

    double sinU1 = sin(U1), cosU1 = cos(U1);
    double sinU2 = sin(U2), cosU2 = cos(U2);

    double lambda = L;
    double lambdaPrev;

    const int maxIter = 100;
    int iter = 0;

    double sinLambda, cosLambda, sinSigma, cosSigma, sigma, cos2SigmaM, C;

    do {
      sinLambda = sin(lambda);
      cosLambda = cos(lambda);

      sinSigma = sqrt(
        pow(cosU2 * sinLambda, 2) +
            pow(cosU1 * sinU2 - sinU1 * cosU2 * cosLambda, 2),
      );

      if (sinSigma == 0) return 0; // coincident points

      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = atan2(sinSigma, cosSigma);

      cos2SigmaM = cosSigma - (2 * sinU1 * sinU2) / (cosU1 * cosU2);

      C =
          (f / 16) *
          pow(cosU1 * cosU2, 2) *
          (4 + f * (4 - 3 * pow(cosU1 * cosU2, 2)));

      lambdaPrev = lambda;
      lambda =
          L +
          (1 - C) *
              f *
              sinLambda *
              (sigma +
                  C *
                      sinSigma *
                      (cos2SigmaM +
                          C * cosSigma * (-1 + 2 * pow(cos2SigmaM, 2))));
    } while ((lambda - lambdaPrev).abs() > 1e-12 && ++iter < maxIter);

    if (iter >= maxIter) return double.nan; // no convergence

    double uSq = (pow(cosU1 * cosU2, 2) * (a * a - b * b)) / (b * b);

    double A =
        1 + (uSq / 16384) * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));

    double B = (uSq / 1024) * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));

    double deltaSigma =
        B *
        sinSigma *
        (cos2SigmaM +
            (B / 4) *
                (cosSigma * (-1 + 2 * pow(cos2SigmaM, 2)) -
                    (B / 6) *
                        cos2SigmaM *
                        (-3 + 4 * pow(sinSigma, 2)) *
                        (-3 + 4 * pow(cos2SigmaM, 2))));

    double s = b * A * (sigma - deltaSigma);

    return s / 1852.0; // meters → NM
  }

  double _payloadPenaltyFuel(double distanceNm) {
    if (activeJob == null) return 0;
    if (activeJob!.isFuelJob) return 0;

    final payload = jobPayloadWeightLbs();
    if (payload <= 0) return 0;

    final hours = distanceNm / _cruiseSpeedKts();

    // +1 gal / hr per 200 lbs
    return (payload / 200.0) * hours;
  }
}
