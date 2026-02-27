import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:skycase/models/airport.dart';
import 'package:skycase/models/airport_frequencies.dart';
import 'package:skycase/models/airport_location.dart';
import 'package:skycase/models/flight.dart';
import 'package:skycase/models/flight_info.dart';
import 'package:skycase/models/flight_log.dart';
import 'package:skycase/models/flight_trail_point.dart';
import 'package:skycase/models/ground_phase.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/models/ndb.dart';
import 'package:skycase/models/open_sky_aircraft.dart';
import 'package:skycase/models/parking.dart';
import 'package:skycase/models/runways.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/models/turbulence_event.dart';
import 'package:skycase/models/vors.dart';
import 'package:skycase/models/waypoints.dart';
import 'package:skycase/providers/auto_flight_provider.dart';
import 'package:skycase/providers/auto_simlink_provider.dart';
import 'package:skycase/screens/ground_ops_screen.dart';
import 'package:skycase/services/aircraft_service.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/distance_tracker.dart';
import 'package:skycase/services/flight_log_service.dart';
import 'package:skycase/services/flight_plan_service.dart';
import 'package:skycase/services/metar_service.dart';
import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/services/weather_engine_service.dart';
import 'package:skycase/utils/airport_repository.dart';
import 'package:skycase/utils/cockpit_vibration.dart';
import 'package:skycase/utils/navigraph_prefs.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/widgets/map_overlay.dart';
import 'package:skycase/widgets/map_tile_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skycase/widgets/navigraph_view.dart' show NavigraphWebview;
import 'package:uuid/uuid.dart';
import 'package:keep_screen_on/keep_screen_on.dart';

enum AirportCategory { airport, heli, unknown }

class LandingSnapshot {
  final LatLng position;
  final String? runway;
  final String? icao;
  final DateTime time;

  LandingSnapshot({
    required this.position,
    required this.runway,
    required this.icao,
    required this.time,
  });
}

class MapView extends StatefulWidget {
  final String? jobFrom;
  final String? jobTo;
  final String? jobId;

  const MapView({super.key, this.jobFrom, this.jobTo, this.jobId});
  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with TickerProviderStateMixin {
  final mapController = MapController();
  final _socketService = SimLinkSocketService();

  SimLinkData? simData;
  LearnedAircraft? savedAircraft;
  int _mapStyleIndex = 0;
  bool _followAircraft = true;
  bool _mapReady = false;

  List<LatLng> _trail = [];
  List<Airport> _airports = [];

  LatLng? _startPoint;
  bool? _isGrounded;

  late final AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  double _previousHeading = 0.0;
  DateTime? _lastFixTime;
  bool _inFlight = false;
  bool _flightSessionActive = false;
  bool _flightQualified = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _engineVibrate;
  late Animation<double> _engineShake;

  double? _lastVS;
  double? _lastAirspeed;
  double? _lastHeading;
  DateTime? _lastTurbTime;
  bool isTurbulent = false;

  final List<TurbulenceEvent> _turbulenceEvents = [];

  static const List<MapTileOption> tileLayers = [
    MapTileOption(
      name: 'OpenStreetMap',
      url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    MapTileOption(
      name: 'TopoMap',
      url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    ),
    MapTileOption(
      name: 'Black',
      url: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    ),
    MapTileOption(
      name: 'White',
      url: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    ),
  ];

  DateTime? _startTime;
  DateTime? _endTime;
  double _totalDistance = 0.0;
  double _maxAltitude = 0.0;
  double _airspeedSum = 0.0;
  int _airspeedSamples = 0;
  Duration _cruiseDuration = Duration.zero;
  DateTime? _lastCruiseStart;

  DateTime? _lastSocketData;
  Timer? _reconnectTimer;
  final Stopwatch _connectionTimer = Stopwatch();
  LatLng? _initialCenter;

  List<Marker> _airportMarkers = [];
  Timer? _airportUpdateThrottle;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _initialCenterReady = false;

  double _mapRotation = 0.0;

  List<Map<String, dynamic>> _backendTrail = [];
  DateTime? _lastBackendTrailUpdate;

  DateTime? _cruiseStartCandidate;
  bool _cruiseConfirmed = false;

  LatLng? _homeBase;
  LatLng? _lastFlightDestination;

  bool _simLinkResponded = false;
  bool _simLinkAvailable = true; // ✅ tracks if SimLink is even available

  // "free" or "mission"
  LatLng? _plannedStart;
  LatLng? _plannedEnd;
  final Map<String, LatLng> _airportCoords = {};

  Flight? _currentFlight;

  LatLng? _aircraftLatLng;
  double _aircraftHeading = 0.0;
  LatLng? _headingBugTarget;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  double? _lastHeadingBug;
  Timer? _headingFadeTimer;

  double _remainingNm = 0;
  String? _lastLandingRating;
  String? _lastTakeoffRating;
  bool _connectionInProgress = false;

  final bool _isLoadingAircraft = false;

  double minutesUntilTOD() {
    final speedKt = (simData?.airspeed ?? 120).clamp(60, 400);
    return ((_remainingNm - _todDistanceNm) / speedKt) * 60;
  }

  bool get hasReachedTOC {
    if (simData == null || _startPoint == null) return false;

    // Distance from origin in KM
    final distKm = const Distance().as(
      LengthUnit.Kilometer,
      _startPoint!,
      LatLng(simData!.latitude, simData!.longitude),
    );

    // Convert to nautical miles
    final distNm = distKm / 1.852;

    return distNm >= _tocDistanceNm;
  }

  LatLng? _lastDistancePoint;

  double? etaDest;
  double? etaTOC;
  double? etaTOD;

  LatLng? _tocPoint;
  LatLng? _todPoint;

  double? requiredClimbFpm;
  double? requiredDescentFpm;

  double _fuelGallons = 0.0;
  double _fuelMinutesLeft = 999.0;

  bool _lowFuel = false;
  bool _fuelEmergency = false;
  bool _showMetar = false;
  bool _showRawMetar = true;
  NavigraphWebview? _cachedNavigraph;
  LatLng? _mapCenter;
  Timer? _trafficTimer;
  OpenSkyAircraft? _selectedAircraft;
  FlightInfo? _selectedInfo;
  bool _hasEverConnected = false;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _connectionTimer.start();

    // 1️⃣ Load in-flight FIRST
    _loadInFlight();

    // 2️⃣ StartPoint + Trail
    _loadStartPoint();
    _loadTrail();

    // 3️⃣ Airports + Flight + Center
    // 3️⃣ Airports + Flight + Center
    _scheduleJsonLoads();
    _loadInitialCenter();
    _loadFlight();
    _loadCurrentFlight();
    _loadTurbulenceEvents();

    // 4️⃣ Rotation controller
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
      if (_mapReady && _followAircraft && simData != null) {
        try {
          final angle = _rotationAnimation.value;
          mapController.rotate(angle);
          _mapRotation = angle;
        } catch (_) {}
      }
    });

    // Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 5️⃣ Map listener
    mapController.mapEventStream.listen((event) {
      if (event.source == MapEventSource.onDrag ||
          event.source == MapEventSource.scrollWheel ||
          event.source == MapEventSource.doubleTap ||
          event.source == MapEventSource.onMultiFinger) {
        if (mounted) setState(() {});
        _throttledUpdateAirportMarkers();
      }
    });

    // 6️⃣ Fade + map style
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _loadMapStyle();

    // 7️⃣ Navigraph cache
    if (!Platform.isWindows) {
      _cachedNavigraph = const NavigraphWebview();
    }

    // 8️⃣ Engine vibration
    _engineVibrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    )..repeat(reverse: true);

    _engineShake = Tween<double>(begin: -0.35, end: 0.35).animate(
      CurvedAnimation(parent: _engineVibrate, curve: Curves.fastOutSlowIn),
    );

    // 9️⃣ Heartbeat (only after first successful connect)
    _heartbeatTimer = Timer.periodic(Duration(seconds: 4), (_) {
      if (!_hasEverConnected) return;
      if (!_isConnected) return;

      final now = DateTime.now();
      if (_lastSocketData != null) {
        final diff = now.difference(_lastSocketData!).inSeconds;

        if (diff > 6) {
          print("💀 Heartbeat Lost — Auto reconnecting...");
          _isConnected = false;
          _connectToSimLink();
        }
      }
    });

    // 🔟 Auto-connect SimLink AFTER UI is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("🚀 Auto-connecting SimLink...");
      _connectToSimLink();
    });
    _loadSavedAircraft();

    _powerFlickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  bool get isClimbing => (simData?.verticalSpeed ?? 0) > 200;
  bool get isDescending => (simData?.verticalSpeed ?? 0) < -200;

  bool get isStableCruise {
    if (simData == null) return false;
    return atCruiseAltitude &&
        simData!.verticalSpeed.abs() <= 200 &&
        simData!.airspeed > 75;
  }

  bool get atCruiseAltitude {
    if (_currentFlight?.cruiseAltitude == null || simData == null) return false;
    final cruise = _currentFlight!.cruiseAltitude!;
    return simData!.altitude >= cruise - 200 &&
        simData!.altitude <= cruise + 300;
  }

  /// Handle incoming real-time sim data
  void _handleSimUpdate(SimLinkData data) async {
    if (!mounted) return;
    final phase = _computePhase(data);

    await CockpitVibration.onPhaseChange(phase);

    // -------------------------------------------------------
    // PHASE CHANGE ANNOUNCER (no spam, no duplicates)
    // -------------------------------------------------------
    if (phase != _lastAnnouncedPhase) {
      _lastAnnouncedPhase = phase;

      switch (phase) {
        case GroundPhase.taxi:
          showHudMessage("🚕 Taxi");
          break;

        case GroundPhase.roll:
          // ❌ Do nothing — runway latch handles this
          break;

        case GroundPhase.parked:
          showHudMessage("🅿️ Parked");
          break;

        case GroundPhase.airborne:
          // Do nothing — takeoff logic already announces this
          break;
      }
    }
    // -------------------------------------------------------
    // RUNWAY ALIGNMENT DETECTION (after entry, before roll)
    // -------------------------------------------------------
    final bool runwayLike =
        data.onGround &&
        data.airspeed < 15 &&
        _computePhase(data) != GroundPhase.parked;

    if (_inFlight && _runwayUsedDeparture == 'N/A' && runwayLike) {
      final now = DateTime.now();
      final heading = data.heading;

      if (_lastHeadingForRunway == null ||
          (heading - _lastHeadingForRunway!).abs() > 5) {
        // Still turning → reset stability window
        _lastHeadingForRunway = heading;
        _headingStableSince = now;
      } else {
        // Heading stable
        final stableSeconds =
            now.difference(_headingStableSince!).inMilliseconds / 1000;

        if (stableSeconds >= 2.0) {
          final latlng = LatLng(data.latitude, data.longitude);
          final rwy = _detectRunway(latlng);

          if (rwy != null) {
            _runwayUsedDeparture = rwy;
            showHudMessage("🛫 Lined up — RWY $_runwayUsedDeparture");
          }
        }
      }
    }

    // -------------------------------------------------------
    // RUNWAY EXIT DETECTION
    // -------------------------------------------------------
    if (_runwayPhaseLatched) {
      final bool exitedRunway =
          !data.onRunway &&
          data.onGround &&
          data.airspeed < 40; // realistic rollout threshold

      if (exitedRunway) {
        _runwayPhaseLatched = false;
        showHudMessage("🚕 Taxi — Runway Vacated");
      }
    }

    if (!_settingsLoaded) return;

    // -------------------------------
    // RUNWAY LOCK (ROLL DETECTION)
    // -------------------------------
    if (data.onRunway && data.airspeed > 30) {
      _runwayLock = true;
      _runwayExitCandidate = null;
    }

    final double volts = data.mainBusVolts;
    final bool avionics = data.avionicsOn;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Realistic screen power logic for mobile only
      if (volts > 7 && avionics) {
        KeepScreenOn.turnOn(); // or Wakelock.enable();
      } else {
        KeepScreenOn.turnOff(); // or Wakelock.disable();
      }
    }

    final now = DateTime.now();
    final latlng = LatLng(data.latitude, data.longitude);
    _lastSocketData = now;
    _qualifyFlightIfNeeded(data);

    // -------------------------------------------------------
    // ⭐ GROUND INITIALIZATION FIX
    //   Initialize _isGrounded ONLY ONCE for the first packet
    // -------------------------------------------------------
    _isGrounded ??= data.onGround;

    // -------------------------------------------------------
    // ⭐ MID-AIR ATTACH FIX
    //   If we connect while already airborne → start flight
    // -------------------------------------------------------
    if (!_flightSessionActive &&
        !data.onGround &&
        data.airspeed > 40 &&
        data.altitude > 150) {
      final prefs = await SharedPreferences.getInstance();
      await DistanceTracker.reset();
      DistanceTracker.start();
      _startFlight();
      _flightSessionActive = true;
      _inFlight = true;
      await prefs.setBool('in_flight', true);

      _flightQualified = true;
      showHudMessage(
        "🛫 Auto Flight Attached (Mid-Air)\n"
        "🧭 PHASE: ${phase != null ? _phaseLabel(phase) : '--'}",
      );
    }

    // -------------------------------------------------------
    // FLIGHT PLAN DISTANCE / ETA / TOC / TOD
    // -------------------------------------------------------
    if (_aircraftLatLng != null &&
        _currentFlight != null &&
        _airportCoords.containsKey(_currentFlight!.destinationIcao)) {
      final dest = _airportCoords[_currentFlight!.destinationIcao]!;
      _remainingNm = _calculateDistanceNm(_aircraftLatLng!, dest);

      await DistanceTracker.feed(latlng);
      _updateEtas();
      _computeTocTodPoints();
    }

    // ----------------------
    // TOC AUTO-HIDE LOGIC
    // ----------------------
    if (_tocPoint != null) {
      if (atCruiseAltitude ||
          simData!.altitude > _currentFlight!.cruiseAltitude!) {
        _tocPoint = null;
      }
    }

    // ----------------------
    // TOD AUTO-HIDE LOGIC
    // ----------------------
    if (_todPoint != null) {
      if (!atCruiseAltitude) _todPoint = null;
      if (isDescending) _todPoint = null;
      if (_remainingNm < _todDistanceNm) _todPoint = null;
    }

    // Heading bug fade logic
    final headingBug = data.autopilot.headingBug;
    if (_lastHeadingBug == null || _lastHeadingBug != headingBug) {
      _lastHeadingBug = headingBug;
      _fadeController.reset();
      _headingFadeTimer?.cancel();
      _headingFadeTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) _fadeController.forward();
      });
    }

    final s = simData;

    if (_currentFlight != null && s != null) {
      final selectedAlt = s.autopilot.altitudeTarget;

      // --- TOC ---
      if (s.verticalSpeed > 200 && s.altitude < selectedAlt - 100) {
        _tocDistanceNm = calculateTOCDistanceNm();
      } else {
        _tocDistanceNm = 0;
      }

      // --- TOD ---
      final destElev =
          _currentFlight!.destinationLat != null
              ? (_destinationElevationFt ?? 0)
              : 0;

      if (_cruiseConfirmed && s.altitude >= selectedAlt - 100) {
        _todDistanceNm = calculateTODDistanceNm(destElev);
      } else {
        _todDistanceNm = 0;
      }
    }

    // Update aircraft state
    _aircraftLatLng = latlng;
    _aircraftHeading = data.heading;
    _headingBugTarget = _computeTargetFromHeading(latlng, headingBug, 30.0);

    // -------------------------------------------------------
    // TAKEOFF DETECTION (Ground → Air)
    // -------------------------------------------------------
    if (_isGrounded == true && data.onGround == false) {
      final pitch = data.pitch;

      _lastTakeoffRating = takeoffGradeFromPitch(pitch);
      showHudMessage(
        "🛫 Takeoff: $_lastTakeoffRating (${pitch.toStringAsFixed(1)}°)\n"
        "🧭 PHASE: ${phase != null ? _phaseLabel(phase) : '--'}",
      );

      _recordedTakeoffPitch = pitch;
    }

    // ------------------------------
    // AUTO START (taxi out)
    // ------------------------------
    if (_autoFlightEnabled && !_flightSessionActive) {
      final bool shouldStart =
          data.onGround && data.combustion && data.airspeed > 8;

      if (shouldStart) {
        print("🟢 AUTO: Flight START — Taxi detected");

        // 🔒 HARD LOCK — prevents flashing
        _flightSessionActive = true;
        _inFlight = true;

        final prefs = await SharedPreferences.getInstance();
        _takeoffTimestamp = DateTime.now();
        await DistanceTracker.reset();
        DistanceTracker.start();

        _startFlight();
        await prefs.setBool('in_flight', true);

        showHudMessage(
          "🟢 Auto Flight Started (Taxi)\n"
          "🧭 PHASE: ${_phaseLabel(phase)}",
        );
      }
    }

    // -------------------------------------------------------
    // REAL GA FUEL CALCULATION
    // -------------------------------------------------------
    _fuelGallons = data.fuelGallons;

    // Estimate burn rate
    double gph = _estimateFuelFlow();

    // Avoid divide-by-zero
    if (gph > 0) {
      _fuelMinutesLeft = (_fuelGallons / gph) * 60.0;
    } else {
      _fuelMinutesLeft = 999;
    }

    bool newLowFuel = false;
    bool newEmergency = false;

    if (_fuelMinutesLeft < 30) {
      newLowFuel = true;
      if (!_lowFuel) {
        showHudMessage(
          "⚠️ LOW FUEL — ${_fuelMinutesLeft.toStringAsFixed(0)} min left",
        );
      }
    }

    if (_fuelMinutesLeft < 15) {
      newEmergency = true;
      if (!_fuelEmergency) {
        showHudMessage(
          "🚨 FUEL EMERGENCY — ${_fuelMinutesLeft.toStringAsFixed(0)} min!",
        );
      }
    }

    _lowFuel = newLowFuel;
    _fuelEmergency = newEmergency;

    // -------------------------------------------------------
    // LANDING DETECTION (Air → Ground)
    // -------------------------------------------------------
    if (_isGrounded == false && data.onGround == true) {
      final vs = data.verticalSpeed;

      if (!await _recentLanding()) {
        _lastLandingRating = landingGradeFromVs(vs);
        showHudMessage(
          "🧈 Landing: $_lastLandingRating (VS: ${vs.toStringAsFixed(0)} fpm)",
        );
        await _markLanding();
      }
    }

    // -------------------------------------------------------
    // 🛬 LANDING SNAPSHOT (RUNWAY / ICAO LOCK)
    // -------------------------------------------------------
    if (_isGrounded == false &&
        data.onGround == true &&
        _landingSnapshot == null) {
      final pos = LatLng(data.latitude, data.longitude);

      final runway =
          (!isHelicopter || helicopterHasWheels) ? _detectRunway(pos) : null;

      final icao = _toAirportLocation(pos)?.icao;

      _landingSnapshot = LandingSnapshot(
        position: pos,
        runway: runway,
        icao: icao,
        time: DateTime.now(),
      );

      print("🛬 Landing SNAPSHOT → ICAO=$icao RWY=${runway ?? 'UNK'}");
    }

    // ------------------------------
    // AUTO END (parked & shutdown)
    // ------------------------------
    if (_autoFlightEnabled && _flightSessionActive && _startPoint != null) {
      final shouldConsiderParking =
          data.onGround &&
          !data.onRunway &&
          data.parkingBrake &&
          !data.combustion;

      // 1️⃣ First detection of real parking intent
      if (shouldConsiderParking && !_pendingFlightEnd) {
        _pendingFlightEnd = true;
        _pendingEndTime = DateTime.now();

        showHudMessage("🅿️ Parked — monitoring shutdown...");
      }

      // 2️⃣ Confirm after stability window
      if (_pendingFlightEnd) {
        final stableFor = DateTime.now().difference(_pendingEndTime!).inSeconds;

        if (stableFor >= 10) {
          await _finalizeAndUploadFlight();

          _pendingFlightEnd = false;
          _pendingEndTime = null;
          _inFlight = false;
          _flightSessionActive = false;

          showHudMessage("🔴 Flight Ended — Parked");
        }
      }
    }

    // -------------------------------------------------------
    // UPDATE GROUND STATE LAST (IMPORTANT)
    // -------------------------------------------------------
    _isGrounded = data.onGround;

    // Turbulence detection
    _handleTurbulenceDetection(data, now, latlng);

    // Teleport/lag detection
    final timeDelta =
        _lastFixTime != null ? now.difference(_lastFixTime!).inSeconds : 0;
    _lastFixTime = now;

    if (_inFlight && _trail.isNotEmpty) {
      final last = _trail.last;

      // Aviation-accurate distance
      final distNm = _calculateDistanceNm(last, latlng);
      final distKm = distNm * 1.852;

      final isLegitMovement = data.airspeed > 40;

      // Anti-teleport filter
      if (distKm > 10 && timeDelta < 8 && !isLegitMovement) {
        print(
          "🛑 Ignored jump (${distKm.toStringAsFixed(1)} km / ${timeDelta}s)",
        );
        return;
      }
    }

    // Ensure distance tracking start reference
    if (_inFlight && _lastDistancePoint == null) {
      _lastDistancePoint = latlng;
    }

    // Track flight stats
    if (_inFlight) {
      await DistanceTracker.feed(latlng);
      _trackFlightStats(data, latlng, now);
    }

    // Follow-aircraft camera
    if (_followAircraft && _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          mapController.move(latlng, mapController.camera.zoom);
          _animateRotation(data.heading);
        } catch (_) {}
      });
    }

    // -------------------------------------------------------
    // TRAIL (visual)
    // -------------------------------------------------------
    if (_inFlight && !data.onGround) {
      final last = _trail.isNotEmpty ? _trail.last : null;

      final movedMeters =
          last == null ? 999.0 : _calculateDistanceNm(last, latlng) * 1852.0;

      if (movedMeters >= 1.0) {
        _trail.add(latlng);
        _saveTrail(_trail);
      }
    }

    // Backend trail (every 15s or 30m)
    if (_inFlight) {
      final lastBackend =
          _backendTrail.isNotEmpty
              ? LatLng(_backendTrail.last['lat'], _backendTrail.last['lng'])
              : null;

      final timeSinceLast =
          _lastBackendTrailUpdate != null
              ? now.difference(_lastBackendTrailUpdate!).inSeconds
              : null;

      final distFromLast =
          lastBackend != null
              ? _calculateDistanceNm(lastBackend, latlng) *
                  1.852 // NM → KM
              : null;

      if (lastBackend == null ||
          (distFromLast != null && distFromLast > 0.03) ||
          (timeSinceLast != null && timeSinceLast >= 15)) {
        _backendTrail.add({
          'lat': latlng.latitude,
          'lng': latlng.longitude,
          'timestamp': now.toIso8601String(),
        });

        _lastBackendTrailUpdate = now;
      }
    }

    // Rebuild UI
    if (!mounted) return;
    setState(() => simData = data);
  }

  /// Rotate map smoothly based on heading
  void _animateRotation(double newHeading) {
    final old = _previousHeading;
    final target = -newHeading % 360;

    _rotationAnimation = Tween<double>(begin: old, end: target).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    _previousHeading = target;
    _rotationController.forward(from: 0);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _socketService.dispose();
    _heartbeatTimer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _engineVibrate.dispose();
    _powerFlickerCtrl.dispose();
    super.dispose();
  }

  bool get isWaitingForData =>
      simData == null && _connectionTimer.elapsed.inSeconds < 5;

  bool get isDataOffline =>
      simData == null && _connectionTimer.elapsed.inSeconds >= 5;

  double? _lastZoom;
  LatLngBounds? _lastBounds;

  final clusters = <String, List<Airport>>{};

  double _tocDistanceNm = 0;
  double _todDistanceNm = 0;

  double get currentVs => simData?.verticalSpeed ?? 0;

  double calculateTOCDistanceNm() {
    final s = simData;
    if (s == null) return 0;

    final targetAlt = s.autopilot.altitudeTarget;
    final currentAlt = s.altitude;

    final altToClimb = (targetAlt - currentAlt).clamp(0, double.infinity);
    if (altToClimb <= 0) return 0;

    final climbRateFpm =
        s.verticalSpeed.abs() < 300 ? 300.0 : s.verticalSpeed.abs();

    final climbTimeMin = altToClimb / climbRateFpm;
    final speedKt = s.airspeed.clamp(60, 400);

    return speedKt * (climbTimeMin / 60);
  }

  double calculateTODDistanceNm(double destinationElevationFt) {
    final s = simData;
    if (s == null) return 0;

    final fromAlt = s.autopilot.altitudeTarget;
    final altToLose = (fromAlt - destinationElevationFt).clamp(
      0,
      double.infinity,
    );

    return altToLose / 300.0; // 3° rule
  }

  static const String _mapStyleKey = "map_style_index";

  Flight? _serverFlight;
  double? _recordedTakeoffPitch;

  String? _gearFlapsMessage;
  Timer? _gearFlapsTimer;

  late bool _autoFlightEnabled;
  late bool _autoConnectEnabled;
  bool _settingsLoaded = false;
  DateTime? _takeoffTimestamp;
  Timer? _landingTimer;

  bool _initializedAfterSettings = false;

  bool get battOn => simData?.mission.battery ?? false; // ✅ HERE
  bool get avionicsOn => simData?.avionicsOn ?? false; // ✅ HERE
  bool get powerOn => battOn && avionicsOn; // optional
  bool get batteryOnly => battOn && !avionicsOn; // optional

  bool get hasElectricalPower =>
      simData != null &&
      (simData!.mainBusVolts > 5 ||
          simData!.mission.battery ||
          simData!.combustion);

  DateTime? _lastAircraftSave;
  bool _isReconnecting = false;

  final Map<String, Map<String, dynamic>?> _wxCache = {};
  DateTime? _lastWxUpdate;

  //new items for navigation display and etc

  // VORs
  List<Vor> _vors = [];
  List<Marker> _vorMarkers = [];
  // Filter
  final bool _showVOR = true;
  final Map<String, List<Vor>> _vorClusters = {};
  Timer? _vorUpdateThrottle;
  double? _lastVorZoom;
  LatLngBounds? _lastVorBounds;

  // NDBs
  List<Ndb> _ndbs = [];
  List<Marker> _ndbMarkers = [];
  final Map<String, List<Ndb>> _ndbClusters = {};

  Timer? _ndbUpdateThrottle;
  double? _lastNdbZoom;
  LatLngBounds? _lastNdbBounds;

  bool _showNDB = false;

  //Runaways
  // =============== RUNWAY STATE ===============
  Timer? _runwayUpdateThrottle;
  double? _lastRunwayZoom;
  LatLngBounds? _lastRunwayBounds;

  List<Polyline> _runwayPolylines = [];
  List<Runway> _runways = [];
  final bool _showRunways = true; // toggle via UI
  List<Marker> _runwayMarkers = [];

  // =============== PARKING STATE ===============

  List<ParkingSpot> _parkings = [];
  List<Marker> _parkingMarkers = [];
  final Map<String, List<ParkingSpot>> _parkingClusters = {};
  Timer? _parkingUpdateThrottle;
  double? _lastParkingZoom;
  LatLngBounds? _lastParkingBounds;
  final bool _showParking = true;

  // =============== WAYPOINT STATE ===============
  List<Waypoint> _waypoints = [];
  List<Marker> _waypointMarkers = [];

  Timer? _waypointThrottle;
  double _lastWaypointZoom = -1;
  LatLngBounds? _lastWaypointBounds;
  final Map<String, List<Waypoint>> _waypointClusters = {};
  bool _showWaypoints = false; // or true, your choice

  // Airport frequencies
  List<AirportFrequency> _frequencies = [];
  Map<String, List<AirportFrequency>> _freqByIcao = {};

  String? _runwayUsedDeparture = "";
  String? _runwayUsedArrival = ""; // will be used at end of flight
  String? _parkingStart = "";
  String? _parkingEnd = "";

  List<ParkingSpot> _parkingSpots = [];

  bool _filterBig = true;
  bool _filterHeli = true;

  LatLng? get currentLatLng =>
      simData != null ? LatLng(simData!.latitude, simData!.longitude) : null;

  bool _pendingFlightEnd = false;
  DateTime? _pendingEndTime;

  bool _runwayLock = false;
  DateTime? _runwayExitCandidate;

  GroundPhase? _lastAnnouncedPhase;

  bool _runwayPhaseLatched = false;

  double? _lastYawRate;
  double? _lastSlipBeta;
  double? _lastRudder;

  double? _lastElevatorTrim;
  DateTime? _lastPilotInputTime;

  double _currentZoom = 7;

  LandingSnapshot? _landingSnapshot;
  final bool _wasOnGround = true;

  late final AnimationController _powerFlickerCtrl;

  double? _lastHeadingForRunway;
  DateTime? _headingStableSince;

  double get effectiveBusVolts {
    final s = simData;
    if (s == null) return 0;

    if (s.mainBusVolts > 5) return s.mainBusVolts;
    if (s.mission.battery) return 24.0;
    return 0.0;
  }

  get _destinationElevationFt {
    if (_currentFlight == null) return 0;

    final icao = _currentFlight!.destinationIcao.toUpperCase();
    if (icao.isEmpty) return 0;

    final airport = _airports.firstWhere(
      (a) => a.icao == icao,
      orElse:
          () => Airport(
            icao: '',
            lat: 0,
            lon: 0,
            elevation: 0,
            name: '',
            country: '',
            isMilitary: false,
          ),
    );

    return airport.elevation.toDouble();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Load provider settings ONCE
    if (!_settingsLoaded) {
      final autoFlightProvider = context.read<AutoFlightProvider>();
      final autoSimLinkProvider = context.read<AutoSimLinkProvider>();

      _autoFlightEnabled = autoFlightProvider.autoFlight;
      _autoConnectEnabled = autoSimLinkProvider.autoConnect;

      _settingsLoaded = true;
    }

    // -----------------------------------------
    // ⭐ AUTO-CONNECT — runs ONLY once
    // -----------------------------------------
    if (_settingsLoaded && !_initializedAfterSettings) {
      _initializedAfterSettings = true;
    }
  }

  bool get isHelicopter {
    final title = simData?.title.toLowerCase() ?? "";

    return title.contains("helicopter") ||
        // Airbus / Eurocopter
        title.contains("h125") ||
        title.contains("h145") ||
        title.contains("h160") ||
        // Light helicopters
        title.contains("cabri") ||
        title.contains("robinson") ||
        title.contains("r22") ||
        title.contains("r44") ||
        title.contains("r66") ||
        // Military / heavy helicopters
        title.contains("chinook") || // CH-47
        title.contains("ch-47") ||
        title.contains("ch47") ||
        title.contains("black hawk") ||
        title.contains("blackhawk") ||
        title.contains("uh-60") ||
        title.contains("uh60");
  }

  /// Main UI
  @override
  Widget build(BuildContext context) {
    if (!_initialCenterReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasData = simData != null;
    final LatLng initialView =
        hasData
            ? LatLng(simData!.latitude, simData!.longitude)
            : _initialCenter ??
                LatLng(0, 0); // Fallback to 0,0 if no initial center

    bool isMobile(BuildContext context) {
      final width = MediaQuery.of(context).size.width;
      return width < 600; // 👈 threshold for mobile
    }

    bool isTablet(BuildContext context) {
      final width = MediaQuery.of(context).size.width;
      return width >= 600 && width < 1024;
    }

    bool isDesktop(BuildContext context) {
      final width = MediaQuery.of(context).size.width;
      return width >= 1024;
    }

    final showPowerFlicker =
        _isConnected &&
        hasData &&
        !isDataOffline &&
        hasElectricalPower &&
        effectiveBusVolts < 18;

    final s = simData;

    final bool heli = isHelicopter;
    final double rotationAngle =
        (() {
          if (s == null) return 0.0;

          final double airspeed = s.airspeed;
          final double heading = s.heading;

          // Helicopter hovering → north-up
          if (heli && airspeed < 20) return 0.0;

          // Normalize heading
          final normalized = (heading % 360 + 360) % 360;
          return normalized * (pi / 180);
        })();

    return Stack(
      children: [
        // ===========================================================
        // 1. AVATAR MODE → Show GroundOpsScreen INSTEAD of the map
        // ===========================================================
        if (simData != null && simData!.isAvatar)
          Positioned.fill(child: GroundOpsScreen(flight: _currentFlight)),

        // ===========================================================
        // 2. AIRCRAFT MODE → Show the MapScreen as you already built it
        // ===========================================================
        if (simData == null || (simData!.isAircraft && !simData!.isAvatar)) ...[
          // 🔥 Put ALL your existing Map UI here.
          // Nothing changes, you keep 100% of your current code.
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              onPositionChanged: (camera, hasGesture) {
                _mapCenter = camera.center;
                _currentZoom = camera.zoom;
              },
              onMapReady: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _mapReady = true);
                  _throttledUpdateAirportMarkers(); // Ensure initial markers load
                });
              },
              initialCenter: initialView,
              initialZoom: 7,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),

            children: [
              // Map tile layer
              TileLayer(
                retinaMode: false,
                urlTemplate: tileLayers[_mapStyleIndex].url,
                subdomains: tileLayers[_mapStyleIndex].subdomains,
                userAgentPackageName: 'com.skycase',
              ),

              // ✅ Water zones appear after a route is picked
              if (_plannedEnd != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _plannedEnd!,
                      radius: 5000, // ~5km, adjust as needed
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.2),
                      borderStrokeWidth: 2,
                      borderColor: Colors.blueAccent,
                    ),
                  ],
                ),

              // Aircraft trail polyline
              if (_trail.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _trail,
                      strokeWidth: 4.0,
                      color: _getTrailColor(simData?.altitude ?? 0),
                    ),
                  ],
                ),

              if (_currentFlight != null) ...[
                PolylineLayer(
                  polylines:
                      _isDirectRoute()
                          ? (() {
                            final originIcao = _currentFlight!.originIcao;
                            final destIcao = _currentFlight!.destinationIcao;

                            final origin =
                                originIcao == 'LIVEPOS'
                                    ? LatLng(
                                      _currentFlight!.originLat!,
                                      _currentFlight!.originLng!,
                                    )
                                    : _airportCoords[originIcao];

                            final destination = _airportCoords[destIcao];

                            // ❌ Do NOT render polyline unless BOTH points exist
                            if (origin == null || destination == null) {
                              return <Polyline>[];
                            }

                            return [
                              Polyline(
                                points: [origin, destination],
                                strokeWidth: 5,
                                color: const Color.fromARGB(255, 83, 64, 255),
                              ),
                            ];
                          })()
                          : [
                            Polyline(
                              points: _buildCustomRoute(),
                              strokeWidth: 4,
                              color: Colors.cyanAccent,
                            ),
                          ],
                ),
              ],

              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, _) {
                  if (_aircraftLatLng == null || _headingBugTarget == null) {
                    return const SizedBox();
                  }

                  final dots = buildDottedLine(
                    _aircraftLatLng!,
                    _headingBugTarget!,
                    dotSpacingMeters: 350, // tune this
                  );

                  return PolylineLayer(
                    polylines: [
                      for (int i = 0; i < dots.length - 1; i += 2)
                        Polyline(
                          points: [dots[i], dots[i + 1]],
                          color: Colors.cyanAccent.withOpacity(
                            _fadeAnimation.value,
                          ),
                          strokeWidth: 2.5,
                        ),
                    ],
                  );
                },
              ),

              if (_showRunways) PolylineLayer(polylines: _runwayPolylines),
              if (_showRunways) MarkerLayer(markers: _runwayMarkers),

              if (_showVOR) MarkerLayer(markers: _vorMarkers),

              if (_showNDB) MarkerLayer(markers: _ndbMarkers),
              if (_showParking) MarkerLayer(markers: _parkingMarkers),
              if (_showWaypoints) MarkerLayer(markers: _waypointMarkers),

              // 💣 Fully skip marker layer below zoom 3.0
              if (_mapReady && mapController.camera.zoom >= 3.0)
                MarkerLayer(markers: _buildVisibleAirportMarkers()),

              // Aircraft + trail start/end markers including turbulence markers
              MarkerLayer(
                markers: [
                  // ✈️ Aircraft marker (only when data is available)
                  if (simData != null)
                    Marker(
                      width: 40,
                      height: 40,
                      point: LatLng(simData!.latitude, simData!.longitude),
                      child: Transform.rotate(
                        angle: rotationAngle,
                        child: Icon(
                          isHelicopter
                              ? Icons
                                  .flight // temporary heli-friendly icon
                              : Icons.airplanemode_active,
                          size: 40,
                          color: _getMarkerColor(
                            tileLayers[_mapStyleIndex].name,
                          ),
                        ),
                      ),
                    ),

                  // 🏠 Home Base marker (always visible if available)
                  if (_homeBase != null)
                    Marker(
                      point: _homeBase!,
                      width: 30,
                      height: 30,
                      child: IgnorePointer(
                        ignoring: true, // <-- TAP-THROUGH FIX
                        child: Tooltip(
                          message: 'Home Base',
                          child: Icon(
                            Icons.home,
                            color: Colors.blueAccent,
                            size: 28,
                            shadows: [
                              Shadow(blurRadius: 5, color: Colors.black45),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 🏁 Last Flight Destination marker
                  if (_lastFlightDestination != null)
                    Marker(
                      point: _lastFlightDestination!,
                      width: 30,
                      height: 30,
                      child: Tooltip(
                        message: 'Last Flight Destination',
                        child: Icon(
                          Icons.airplane_ticket,
                          color: Colors.lightGreenAccent,
                          size: 28,
                          shadows: [
                            Shadow(blurRadius: 5, color: Colors.black45),
                          ],
                        ),
                      ),
                    ),

                  // 🌪️ Turbulence events
                  ..._turbulenceEvents.map(
                    (event) => Marker(
                      width: 16,
                      height: 16,
                      point: event.location,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getTurbulenceColor(event.severity),
                          border: Border.all(color: Colors.redAccent, width: 2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ======================================
          // 🔌 POWER BLACKOUT / DIM OVERLAY
          // ======================================
          if (simData != null) ...[
            if (!battOn) Container(color: Colors.black),

            if (batteryOnly) Container(color: Colors.black.withOpacity(0.55)),
          ],

          // ======================================
          if (showPowerFlicker)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _powerFlickerCtrl,
                builder: (_, __) {
                  final t = _powerFlickerCtrl.value;

                  // 🎛 STAGED flicker (NOT random chaos)
                  final opacity =
                      (t < 0.2)
                          ? 0.05
                          : (t < 0.35)
                          ? 0.35
                          : (t < 0.6)
                          ? 0.12
                          : (t < 0.75)
                          ? 0.45
                          : 0.08;

                  final dx = (t < 0.35 || t > 0.7) ? 0.0 : -3.0;

                  return IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(dx, 0),
                        child: Container(color: Colors.black),
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_isConnected && hasData && !isDataOffline && !battOn)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25), // subtle dim
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.8),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black87,
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔴 BATTERY OFF TEXT
                        Text(
                          "BATTERY OFF",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 🏠 HOME BUTTON (blended, not flashy)
                        SizedBox(
                          width: 160,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (!mounted) return;
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.home_outlined, size: 18),
                            label: const Text("Return Home"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white24,
                                width: 1.1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Map style selector (top right)
          if (battOn || isDataOffline)
            Positioned(
              top: 50,
              right: 12,
              child: MapTileSelector(
                selectedIndex: _mapStyleIndex,
                tileOptions: tileLayers,
                onSelected: (index) async {
                  setState(() => _mapStyleIndex = index);
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setInt(_mapStyleKey, index);
                },
                iconColor: _getMapStyleIconColor(),
              ),
            ),

          // Live data overlay
          if (hasData)
            MapOverlay(
              simData: simData!,
              show: ((powerOn || isDataOffline) && !simData!.onGround),
              vibrate: _vibrateIfEngineOn,
            ),

          // ⭐ Follow toggle — only when connected & telemetry present AND battery ON
          if (_isConnected && hasData && _settingsLoaded && battOn)
            Positioned(
              top: 50,
              left: 12,
              child: FloatingActionButton.small(
                heroTag: 'follow_toggle',
                onPressed: () {
                  if (!mounted) return;

                  setState(() => _followAircraft = !_followAircraft);

                  if (_followAircraft && simData != null) {
                    _animateRotation(simData!.heading);
                  }
                },
                child: Icon(_followAircraft ? Icons.gps_fixed : Icons.gps_off),
              ),
            ),

          // ⭐ North-up reset — only when connected & telemetry present AND battery ON
          if (_isConnected && hasData && _settingsLoaded && battOn)
            Positioned(
              top: 50,
              left: 70,
              child: FloatingActionButton.small(
                heroTag: 'north_up',
                onPressed: () {
                  if (!mounted) return;

                  setState(() {
                    _followAircraft = false;
                    _previousHeading = 0.0;
                  });

                  mapController.rotate(0);
                },
                child: const Icon(Icons.navigation_outlined),
              ),
            ),

          if (_isConnected && hasData && _settingsLoaded && !_autoFlightEnabled)
            Positioned(
              bottom: isDesktop(context) ? 20 : 80,
              right: 20,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder:
                    (_, child) => Transform.scale(
                      scale: _inFlight ? _pulseAnimation.value : 1.0,
                      child: FloatingActionButton(
                        heroTag: 'in_flight_toggle',
                        backgroundColor: _inFlight ? Colors.red : Colors.green,
                        onPressed: _toggleFlightState,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _inFlight ? Icons.stop : Icons.play_arrow,
                            key: ValueKey(_inFlight),
                            size: 30,
                          ),
                        ),
                      ),
                    ),
              ),
            ),

          if (battOn || isDataOffline)
            Positioned(
              top: 50,
              left:
                  !hasData
                      ? 10
                      : _isConnected
                      ? 130
                      : 20,
              child: FloatingActionButton.small(
                heroTag: 'home_button',
                onPressed: () {
                  if (!mounted) return;

                  Navigator.pop(context);
                },
                child: const Icon(Icons.home_outlined),
              ),
            ),

          if (isDataOffline)
            Positioned(
              bottom: isMobile(context) ? 30 : 35,
              left: isMobile(context) ? 10 : 40,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: offlineBadgeDecoration(context),
                child: const Text(
                  'SimLink offline\nAircraft telemetry unavailable\nDirect distance & ETA tools still available',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),

          // 📶 Connect/Disconnect Button
          if (!_autoConnectEnabled)
            Positioned(
              bottom: isMobile(context) ? 10 : 20,
              right: isMobile(context) ? 20 : 80,
              child:
                  isMobile(context)
                      ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // MOBILE MAIN BUTTON
                          FloatingActionButton(
                            heroTag: 'connected_button_mobile',
                            backgroundColor:
                                _isConnected
                                    ? Colors.redAccent
                                    : (_simLinkAvailable
                                        ? null
                                        : Colors.grey.shade700),
                            onPressed:
                                (_isConnecting || !_simLinkAvailable)
                                    ? null
                                    : () {
                                      if (_isConnected) {
                                        _disconnectFromSimLink();
                                      } else {
                                        _connectToSimLink(manual: true);
                                      }
                                    },
                            child:
                                _isConnecting
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Icon(
                                      _isConnected
                                          ? Icons.wifi_off
                                          : _simLinkAvailable
                                          ? Icons.wifi
                                          : Icons.warning_amber_rounded,
                                    ),
                          ),

                          // MOBILE RETRY BUTTON
                          if (!_simLinkAvailable && !_isConnected)
                            const SizedBox(width: 12),
                          if (!_simLinkAvailable && !_isConnected)
                            FloatingActionButton.small(
                              heroTag: 'reconnect_button_mobile',
                              backgroundColor: Colors.orange,
                              tooltip: "Retry Connection",
                              onPressed: () => _connectToSimLink(manual: true),
                              child: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      )
                      // DESKTOP UI
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // DESKTOP MAIN BUTTON
                          FloatingActionButton.extended(
                            heroTag: 'connected_button_desktop',
                            backgroundColor:
                                _isConnected
                                    ? Colors.redAccent
                                    : (_simLinkAvailable
                                        ? null
                                        : Colors.grey.shade700),
                            icon:
                                _isConnecting
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Icon(
                                      _isConnected
                                          ? Icons.wifi_off
                                          : _simLinkAvailable
                                          ? Icons.wifi
                                          : Icons.warning_amber_rounded,
                                    ),
                            label: Text(
                              _isConnecting
                                  ? 'Connecting...'
                                  : _isConnected
                                  ? 'Disconnect'
                                  : _simLinkAvailable
                                  ? 'Connect SimLink'
                                  : 'SimLink Offline',
                            ),
                            onPressed:
                                (_isConnecting || !_simLinkAvailable)
                                    ? null
                                    : () {
                                      if (_isConnected) {
                                        _disconnectFromSimLink();
                                      } else {
                                        _connectToSimLink(manual: true);
                                      }
                                    },
                          ),

                          // DESKTOP RETRY BUTTON
                          if (!_simLinkAvailable && !_isConnected)
                            const SizedBox(width: 12),
                          if (!_simLinkAvailable && !_isConnected)
                            IconButton(
                              tooltip: "Retry Connection",
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.orange,
                              ),
                              onPressed: () => _connectToSimLink(manual: true),
                            ),
                        ],
                      ),
            ),

          if (_currentFlight != null && !isDataOffline && (powerOn || battOn))
            Positioned(
              top:
                  isDesktop(context)
                      ? 100
                      : isTablet(context)
                      ? 120
                      : 100,
              left: isDesktop(context) ? 10 : 10,

              child: Align(
                alignment: Alignment.topCenter,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.assignment_outlined,
                    color: Colors.orangeAccent,
                  ),
                  label: const Text("Flight Plan Details"),
                  onPressed: () => _showFlightDialog(context),
                ),
              ),
            ),

          if (_currentFlight != null &&
              !isDataOffline &&
              (powerOn || battOn) &&
              _inFlight)
            Positioned(
              top: 150,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🟠 ${_currentFlight!.destinationIcao}  |  ${_remainingNm.toStringAsFixed(1)} NM',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),

          // 🛩️ AUTOPILOT STATUS PANEL
          if (simData != null && (powerOn || isDataOffline))
            Positioned(
              bottom: isDesktop(context) ? 10 : 20, // adjust to taste
              left: 15,
              child: powerDim(
                _vibrateIfEngineOn(_autopilotPanel(simData!.autopilot)),
              ),
            ),

          if (_currentFlight != null && _inFlight && battOn && !batteryOnly)
            Positioned(
              bottom: _inFlight ? 250 : 220,
              left: 5,
              child: _etaHud(),
            ),

          // SYSTEM LIGHT STRIP (under the top buttons)
          if (simData != null && (battOn || isDataOffline))
            Positioned(
              bottom:
                  _inFlight
                      ? (isDesktop(context) ? 130 : 100) // 👈 lower when flying
                      : (isDesktop(context)
                          ? 180
                          : 100), // 👈 original positions
              left: 12,
              right: 12,
              child: powerDim(
                _vibrateIfEngineOn(
                  _systemStrip(simData!.mission, isDesktop(context)),
                ),
              ),
            ),

          // ⭐ METAR FAB — only when SimLink is connected
          if (_isConnected && hasData && (powerOn || isDataOffline))
            Positioned(
              top: 50,
              left: 185,
              child: FloatingActionButton.small(
                heroTag: 'metar_toggle',
                onPressed: () {
                  if (!mounted) return;
                  setState(() => _showMetar = !_showMetar);
                },
                child: const Icon(Icons.info_outline),
              ),
            ),

          // ⭐ METAR PANEL — only when connected + simData + toggle on
          if (_isConnected &&
              _showMetar &&
              simData != null &&
              (powerOn || isDataOffline))
            Positioned(
              top: 100,
              left: 10,
              right: 10,
              child: _buildMetarPanel(simData!.weather),
            ),

          FutureBuilder<bool>(
            future: NavigraphPrefs.getHasPremium(),
            builder: (context, snapshot) {
              final hasPremium = snapshot.data ?? false;

              if (!hasPremium) return SizedBox.shrink();
              if (Platform.isWindows) return SizedBox.shrink();

              // ⛔ NEW: Hide completely if battery OFF
              if (!battOn || !isDataOffline) return SizedBox.shrink();

              return Positioned(
                top: 50,
                left: !hasData ? 70 : 230,
                child: FloatingActionButton.small(
                  heroTag: 'navigraph_btn',
                  backgroundColor: Colors.blueGrey,
                  elevation: 6,
                  child: const Icon(Icons.map_outlined, size: 20),
                  onPressed: () => _openNavigraphSheet(context),
                ),
              );
            },
          ),

          if (battOn || isDataOffline)
            Positioned(
              top: 50,
              right: 50,
              child: FloatingActionButton.small(
                heroTag: 'icao_search_btn',
                onPressed: () => _openIcaoSearchDialog(),
                child: Icon(Icons.search),
              ),
            ),

          if (_gearFlapsMessage != null)
            Positioned(
              bottom: 220,
              left: 10,
              right: 230,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _gearFlapsMessage != null ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      _gearFlapsMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ------------------------------------------------------
          // OFFLINE MODE — show summary + direct cancel button
          // ------------------------------------------------------
          if (isDataOffline && _currentFlight != null)
            Positioned(
              top: 150,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _buildFlightBannerText(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text("Discard Plan"),
                    onPressed: () => _cancelFlight(context, fromDialog: false),
                  ),
                ],
              ),
            ),

          if (hasData)
            Positioned(
              bottom: isMobile(context) ? 220 : 300,
              left: 12,
              child: powerDim(
                _vibrateIfEngineOn(
                  Opacity(
                    opacity:
                        battOn
                            ? 1
                            : 0.35, // optional: dim more when battery off
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "BUS ${simData!.mainBusVolts.toStringAsFixed(1)}V",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "OAT ${simData!.weather.temperature.toStringAsFixed(0)}°C",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (hasData && isIcing(simData!))
            Positioned(
              top: 50,
              left: 12,
              child: powerDim(
                _vibrateIfEngineOn(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "❄️ ICING (${simData!.structural.toStringAsFixed(0)}%)",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (battOn || isDataOffline)
            Positioned(
              top:
                  isMobile(context)
                      ? _currentFlight == null
                          ? 100
                          : 110
                      : 160,
              left: 10,
              child: _buildFilterButton(context),
            ),

          if ((battOn || isDataOffline) && _mapCenter != null)
            Positioned(
              top: 100,
              right: 25,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${_zoomToNm(_currentZoom, _mapCenter!.latitude).toStringAsFixed(1)} NM",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (simData != null && simData!.mainBusVolts > 0)
            Positioned(
              bottom: isMobile(context) ? 260 : 270,
              left: 12,
              child: _radioHud(simData!),
            ),
        ],
      ],
    );
  }

  List<Marker> _buildVisibleAirportMarkers() => _airportMarkers;

  /// Aircraft marker color based on map style
  Color _getMarkerColor(String tileName) {
    switch (tileName.toLowerCase()) {
      case 'black':
        return Colors.white;
      case 'white':
        return Colors.black;
      case 'topomap':
        return const Color.fromARGB(255, 64, 127, 243);
      default:
        return const Color.fromARGB(255, 3, 131, 206);
    }
  }

  Color _getTrailColor(double altitude) {
    final themeName = tileLayers[_mapStyleIndex].name.toLowerCase();
    final base = _altitudeTint(altitude);

    switch (themeName) {
      case 'black': // NAVBLUE / DARK
        return _mix(base, Colors.cyanAccent, 0.40);

      case 'white': // LIGHT MODE
        return _mix(base, Colors.orangeAccent, 0.25);

      case 'topomap':
        return _mix(base, Colors.indigo, 0.30);

      default: // fallback
        return _mix(base, Colors.deepPurpleAccent, 0.25);
    }
  }

  Color _getTurbulenceColor(String severity) {
    switch (severity) {
      case 'severe':
        return Colors.red.withOpacity(0.5);
      case 'moderate':
        return Colors.orange.withOpacity(0.5);
      case 'light':
      default:
        return Colors.yellow.withOpacity(0.4);
    }
  }

  Future<void> _loadAirports() async {
    final repo = AirportRepository();
    await repo.load();

    if (!mounted) return;

    setState(() {
      _airports = repo.airports;
      _airportCoords
        ..clear()
        ..addAll(repo.coordsByIcao);
    });
  }

  void _showAirportInfo(Airport airport) async {
    final wx = await WeatherEngineService.getAirportWeather(airport);

    if (!mounted) return;

    final cat = wx["category"] ?? "UNKNOWN";

    final catColor =
        {
          "VFR": Colors.greenAccent,
          "MVFR": Colors.blueAccent,
          "IFR": Colors.redAccent,
          "LIFR": Colors.purpleAccent,
        }[cat] ??
        Colors.grey;

    final source = wx["source"] ?? "UNKNOWN";

    final sourceColor =
        {
          "REAL": Colors.cyanAccent,
          "SIMLINK": Colors.orangeAccent,
          "REGIONAL": Colors.lightGreenAccent,
          "MODEL": Colors.pinkAccent,
        }[source] ??
        Colors.white70;

    IconData icon = Icons.wb_sunny;
    final raw = wx["raw"]?.toString() ?? "";

    if (raw.contains("TS")) {
      icon = Icons.flash_on;
    } else if (raw.contains("RA") || raw.contains("DZ")) {
      icon = Icons.water_drop;
    } else if (raw.contains("SN")) {
      icon = Icons.ac_unit;
    } else if (raw.contains("FG") || raw.contains("BR")) {
      icon = Icons.cloud;
    } else if (raw.contains("BKN") || raw.contains("OVC")) {
      icon = Icons.cloud_queue;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================================
                // HEADER ROW
                // ============================================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // CATEGORY RING
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: catColor, width: 3),
                      ),
                      child: Center(
                        child: Icon(icon, color: catColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // ICAO + NAME
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${airport.icao} – ${airport.name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${airport.country} • Elev ${airport.elevation.toStringAsFixed(0)} ft",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // RIGHT SIDE: SOURCE + CATEGORY BADGE
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: sourceColor, width: 1.2),
                          ),
                          child: Text(
                            source,
                            style: TextStyle(
                              color: sourceColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _categoryBadge(wx),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                Divider(color: Colors.white24),
                const SizedBox(height: 12),

                // ============================================================
                // WEATHER DETAILS GRID
                // ============================================================
                _infoRow("Wind", wx["wind"] ?? "N/A"),
                _infoRow("Temp", "${wx["temp"]}°C"),
                _infoRow("Visibility", wx["visibility"] ?? "N/A"),
                _infoRow(
                  "Clouds",
                  wx["clouds"] == null || wx["clouds"].isEmpty
                      ? "Clear"
                      : wx["clouds"].join(", "),
                ),
                _infoRow("Pressure", wx["pressure"] ?? "N/A"),

                const SizedBox(height: 16),
                Divider(color: Colors.white24),
                const SizedBox(height: 14),

                // ============================================================
                // RAW METAR BLOCK
                // ============================================================
                const Text(
                  "Raw METAR",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    raw,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'RobotoMono',
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                // ============================================================
                // AIRPORT FREQUENCIES
                // ============================================================
                Builder(
                  builder: (_) {
                    final freqs = _freqByIcao[airport.icao] ?? [];

                    if (freqs.isEmpty) return const SizedBox.shrink();

                    // 🧹 Deduplicate identical freq+type pairs
                    final unique = <String, AirportFrequency>{};
                    for (final f in freqs) {
                      unique["${f.type}_${f.frequency}"] = f;
                    }

                    final cleanList = unique.values.toList();

                    // Friendly type names
                    String friendly(String t) {
                      switch (t) {
                        case "T":
                          return "Tower";
                        case "G":
                          return "Ground";
                        case "A":
                          return "Approach";
                        case "RDO":
                          return "Radio";
                        case "RDR":
                          return "Radar";
                        case "DIR":
                          return "Director";
                        case "ATIS":
                          return "ATIS";
                        case "APT":
                          return "Airport";
                        default:
                          return t;
                      }
                    }

                    IconData iconFor(String t) {
                      switch (t) {
                        case "T":
                          return Icons.airplanemode_active;
                        case "G":
                          return Icons.local_taxi;
                        case "A":
                          return Icons.south_west;
                        case "RDO":
                          return Icons.wifi_tethering;
                        case "RDR":
                          return Icons.radar;
                        case "DIR":
                          return Icons.splitscreen;
                        case "ATIS":
                          return Icons.speaker;
                        default:
                          return Icons.radio;
                      }
                    }

                    Color colorFor(String t) {
                      switch (t) {
                        case "T":
                          return Colors.orangeAccent;
                        case "G":
                          return Colors.greenAccent;
                        case "A":
                          return Colors.cyanAccent;
                        case "RDO":
                          return Colors.purpleAccent;
                        case "RDR":
                          return Colors.redAccent;
                        case "DIR":
                          return Colors.yellowAccent;
                        case "ATIS":
                          return Colors.blueAccent;
                        default:
                          return Colors.white70;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 22),
                        Divider(color: Colors.white24),
                        const SizedBox(height: 16),

                        const Text(
                          "Frequencies",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        ...cleanList.map((f) {
                          final mhz = (f.frequency / 1000.0).toStringAsFixed(3);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  iconFor(f.type),
                                  size: 18,
                                  color: colorFor(f.type),
                                ),
                                const SizedBox(width: 12),

                                Expanded(
                                  child: Text(
                                    friendly(f.type) +
                                        (f.description != null &&
                                                f.description!.isNotEmpty
                                            ? " – ${f.description}"
                                            : ""),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),

                                Text(
                                  "$mhz MHz",
                                  style: TextStyle(
                                    color: colorFor(f.type),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 6),
                // ============================================================
                // DIRECT TO BUTTON
                // ============================================================
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _createDirectFlightTo(airport.icao);
                    },
                    icon: const Icon(Icons.flight_takeoff, size: 20),
                    label: const Text("Direct To"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveStartPoint(LatLng point) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('start_lat', point.latitude);
    await prefs.setDouble('start_lng', point.longitude);
  }

  void _loadStartPoint() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('start_lat');
    final lng = prefs.getDouble('start_lng');

    if (lat != null && lng != null) {
      _startPoint = LatLng(lat, lng);
    }
  }

  Future<void> _saveTrail(List<LatLng> trail) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      trail.map((e) => [e.latitude, e.longitude]).toList(),
    );
    await prefs.setString('flight_trail', encoded);
  }

  Future<void> _loadTrail() async {
    if (!_inFlight) {
      // Do NOT restore old trails if not mid-flight
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('flight_trail');
    if (encoded == null) return;

    try {
      final List<dynamic> raw = jsonDecode(encoded);
      final restored =
          raw
              .map<LatLng>((e) => LatLng(e[0] as double, e[1] as double))
              .toList();

      if (!mounted) return;

      // ❗ Delay inserting trail until AFTER map is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _trail.clear();
          _trail.addAll(restored);
        });
        print("🟢 Trail restored with ${_trail.length} points.");
      });
    } catch (e) {
      print('❌ Error loading trail: $e');
    }
  }

  void _toggleFlightState() async {
    final prefs = await SharedPreferences.getInstance();
    final newState = !_inFlight;
    if (!mounted) return;
    setState(() {
      _inFlight = newState;
    });

    await prefs.setBool('in_flight', _inFlight);

    if (_inFlight) {
      _startFlight();
    } else {
      await _endFlight();
    }
  }

  Future<void> _loadInFlight() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // ⚠️ Never restore real flight state from disk
    // Flight sessions are ephemeral and must be telemetry-driven
    setState(() {
      _inFlight = false;
      _flightSessionActive = false;
    });

    // 🧹 Defensive cleanup: stale prefs from crashes / force closes
    await prefs.remove('in_flight');
    await prefs.remove('flight_start_time');

    // 🧠 Pulse is ONLY started when auto-flight detects takeoff
    _pulseController.stop();

    print("🔁 Flight session reset — waiting for auto-flight detection");
  }

  Future<void> _saveTurbulenceEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _turbulenceEvents.map((e) => e.toJson()).toList();
    await prefs.setString('turbulence_events', jsonEncode(jsonList));
  }

  Future<void> _loadTurbulenceEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('turbulence_events');
    if (encoded == null) return;
    try {
      final List<dynamic> raw = jsonDecode(encoded);
      if (!mounted) return;
      setState(() {
        _turbulenceEvents.clear();
        _turbulenceEvents.addAll(raw.map((e) => TurbulenceEvent.fromJson(e)));
      });
    } catch (e) {
      print('Error loading turbulence events: \$e');
    }
  }

  bool get isTurbulenceEligible {
    if (simData == null) return false;

    // Never detect turbulence on ground
    if (simData!.onGround) return false;

    // Helicopters: only in forward flight
    if (isHelicopter) {
      return simData!.airspeed > 25 && simData!.altitude > 100;
    }

    // Fixed wing: only above safe altitude
    return simData!.airspeed > 60 && simData!.altitude > 500;
  }

  Future<void> _handleTurbulenceDetection(
    SimLinkData data,
    DateTime now,
    LatLng latlng,
  ) async {
    // --------------------------------------------------
    // 1️⃣ FLIGHT REGIME GATE (ABSOLUTE)
    // --------------------------------------------------
    if (!isTurbulenceEligible) {
      _updateLastTurbSamples(data);
      return;
    }

    // --------------------------------------------------
    // 2️⃣ COOLDOWNS
    // --------------------------------------------------
    if (_lastTurbTime != null && now.difference(_lastTurbTime!).inSeconds < 4) {
      _updateLastTurbSamples(data);
      return;
    }

    // --------------------------------------------------
    // 3️⃣ PILOT INPUT (DO NOT RETURN)
    // --------------------------------------------------
    final bool pilotActive = _detectPilotInput(data, now);

    // --------------------------------------------------
    // 4️⃣ DELTA SIGNALS (RAW MOTION)
    // --------------------------------------------------
    double yawDelta =
        _lastYawRate != null ? (data.yawRateDeg - _lastYawRate!).abs() : 0.0;

    double slipDelta =
        _lastSlipBeta != null ? (data.slipBetaDeg - _lastSlipBeta!).abs() : 0.0;

    final double vsDelta =
        _lastVS != null ? (data.verticalSpeed - _lastVS!).abs() : 0.0;

    final double airspeedDelta =
        _lastAirspeed != null ? (data.airspeed - _lastAirspeed!).abs() : 0.0;

    // --------------------------------------------------
    // 5️⃣ HELICOPTER NORMALIZATION
    // --------------------------------------------------
    if (isHelicopter) {
      yawDelta *= 0.4;
      slipDelta *= 0.4;
    }

    // --------------------------------------------------
    // 6️⃣ SCORING
    // --------------------------------------------------
    int score = 0;

    // Airspeed instability
    if (airspeedDelta > 5) score++;
    if (airspeedDelta > 10) score++;

    // Light
    if (yawDelta > 0.8) score++;
    if (slipDelta > 0.7) score++;
    if (vsDelta > 300) score++;

    // Moderate
    if (yawDelta > 2.0) score++;
    if (slipDelta > 1.8) score++;
    if (vsDelta > 600) score++;

    // Severe
    if (yawDelta > 4.0) score += 2;
    if (slipDelta > 3.5) score += 2;
    if (vsDelta > 1000) score += 2;

    // --------------------------------------------------
    // 7️⃣ PILOT INPUT DAMPING
    // --------------------------------------------------
    if (pilotActive) {
      score -= isHelicopter ? 2 : 1;
    }

    // --------------------------------------------------
    // 8️⃣ FINAL THRESHOLD
    // --------------------------------------------------
    if (score < 2) {
      _updateLastTurbSamples(data);
      return;
    }

    // --------------------------------------------------
    // 9️⃣ CLASSIFICATION
    // --------------------------------------------------
    String level = 'light';
    if (score >= 4) level = 'moderate';
    if (score >= 7) level = 'severe';

    _lastTurbTime = now;
    _turbulenceEvents.add(TurbulenceEvent(latlng, level, now));
    await _saveTurbulenceEvents();

    debugPrint(
      "🌪️ $level turbulence | "
      "VSΔ=${vsDelta.toStringAsFixed(0)} fpm "
      "yawΔ=${yawDelta.toStringAsFixed(1)}°/s",
    );

    _updateLastTurbSamples(data);
  }

  void _updateLastTurbSamples(SimLinkData data) {
    _lastVS = data.verticalSpeed;
    _lastAirspeed = data.airspeed;
    _lastHeading = data.heading;
    _lastYawRate = data.yawRateDeg;
    _lastSlipBeta = data.slipBetaDeg;
    _lastRudder = data.rudderDeflectionDeg;
    _lastElevatorTrim = data.elevatorTrim;
  }

  bool _detectPilotInput(SimLinkData data, DateTime now) {
    if (_lastRudder == null || _lastElevatorTrim == null) return false;

    final rudderDelta = (data.rudderDeflectionDeg - _lastRudder!).abs();

    final trimDelta = (data.elevatorTrim - _lastElevatorTrim!).abs();

    if (rudderDelta > 2.0 || trimDelta > 0.5) {
      _lastPilotInputTime = now;
      return true;
    }

    return false;
  }

  void _trackFlightStats(SimLinkData data, LatLng latlng, DateTime now) async {
    // 📈 Max altitude
    if (data.altitude > _maxAltitude) {
      _maxAltitude = data.altitude;
    }

    // 🚀 Average airspeed
    _airspeedSum += data.airspeed;
    _airspeedSamples++;

    // 🧭 Cruise detection
    final isStableVS = data.verticalSpeed.abs() < 100;
    final isFastEnough = data.airspeed > 90;
    final isHighEnough = data.altitude > 3000;

    if (isStableVS && isFastEnough && isHighEnough) {
      if (_cruiseStartCandidate == null) {
        _cruiseStartCandidate = now;
      } else {
        final held = now.difference(_cruiseStartCandidate!).inSeconds;
        if (!_cruiseConfirmed && held >= 15) {
          _cruiseConfirmed = true;
          _lastCruiseStart = now;
          print("🧭 Cruise started at: $now");
        }
      }
    } else {
      if (_cruiseConfirmed && _lastCruiseStart != null) {
        _cruiseDuration += now.difference(_lastCruiseStart!);
        print("🧭 Cruise ended. Duration now: ${_cruiseDuration.inSeconds}s");
      }
      _cruiseConfirmed = false;
      _cruiseStartCandidate = null;
      _lastCruiseStart = null;
    }
  }

  Future<void> _startFlight() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    print("🧪 StartFlight — userId = $userId");

    // ------------------------------------------------------------
    // 🔗 Bind flight to active job (if any)
    // ------------------------------------------------------------
    if (widget.jobId != null) {
      await prefs.setString('flight_job_id', widget.jobId!);
      print("🧭 Flight bound to job ${widget.jobId}");
    } else if (userId != null) {
      final activeJob = await DispatchService.getActiveJob(userId);

      if (activeJob != null && activeJob['job'] != null) {
        final jobId = activeJob['job']['_id'];
        await prefs.setString('flight_job_id', jobId);
        print("🧭 Flight bound to job $jobId");
      }
    }

    // ------------------------------------------------------------
    // 🛑 Safety: never start a flight while cold & parked
    // ------------------------------------------------------------
    if (simData != null &&
        simData!.onGround &&
        simData!.parkingBrake &&
        !simData!.combustion) {
      print("⛔ StartFlight aborted — aircraft is parked & engine off");
      return;
    }

    _pulseController.repeat(reverse: true);
    _inFlight = true;

    // ------------------------------------------------------------
    // ⏱️ Start time
    // ------------------------------------------------------------
    _startTime = DateTime.now();
    await prefs.setString('flight_start_time', _startTime!.toIso8601String());

    // ------------------------------------------------------------
    // ⭐ Reset flight state
    // ------------------------------------------------------------
    await DistanceTracker.reset();

    _maxAltitude = 0;
    _airspeedSum = 0;
    _airspeedSamples = 0;
    _cruiseDuration = Duration.zero;
    _lastCruiseStart = null;
    _cruiseConfirmed = false;
    _cruiseStartCandidate = null;

    _trail.clear();
    _backendTrail.clear();
    _turbulenceEvents.clear();
    _lastBackendTrailUpdate = null;

    // IMPORTANT: reset departure runway here
    _runwayUsedDeparture = 'N/A';

    // ------------------------------------------------------------
    // 🧹 Clear old local state
    // ------------------------------------------------------------
    await prefs.remove('flight_trail');
    await prefs.remove('turbulence_events');
    await prefs.remove('start_lat');
    await prefs.remove('start_lng');

    // ------------------------------------------------------------
    // 📍 Start location detection (NO runway logic here)
    // ------------------------------------------------------------
    if (simData != null) {
      final latlng = LatLng(simData!.latitude, simData!.longitude);

      _startPoint = latlng;
      _trail.add(latlng);

      final airportIcao = _toAirportLocation(latlng)?.icao;

      // Parking detection ONLY
      _parkingStart = 'N/A';
      if (airportIcao != null) {
        final parking = detectParkingSpot(latlng, icao: airportIcao);
        if (parking != null) {
          _parkingStart = parking;
        }
      }

      print("🅿️ Starting parking: $_parkingStart");

      await _saveStartPoint(latlng);
      await _saveTrail(_trail);
    }

    print("🟢 Flight started at $_startTime");
  }

  Future<void> _endFlight() async {
    await _finalizeAndUploadFlight();
  }

  void _throttledUpdateAirportMarkers({bool force = false}) {
    if (_airportUpdateThrottle?.isActive ?? false) return;

    _airportUpdateThrottle = Timer(const Duration(milliseconds: 250), () async {
      if (!_mapReady || _airports.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final camera = mapController.camera;

        if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

        final zoom = camera.zoom;
        final bounds = camera.visibleBounds;

        if (!force && zoom == _lastZoom && bounds == _lastBounds) return;

        if (!force) {
          _lastZoom = zoom;
          _lastBounds = bounds;
        }

        // Hide if too zoomed out
        if (zoom < 5.0) {
          if (mounted) setState(() => _airportMarkers = []);
          return;
        }

        // Visible airports
        final visibleAirports =
            _airports.where((a) {
              return bounds.contains(LatLng(a.lat, a.lon));
            }).toList();

        // WEATHER CACHE (10 min interval)
        await _updateWeatherCache(visibleAirports);

        final List<Marker> markers = [];

        // =======================================================
        // MODE A — FULL DETAIL
        // =======================================================
        if (zoom >= 9.0) {
          for (final airport in visibleAirports) {
            // --------------------------------------------------
            // 🔎 CATEGORY FILTER (skip airport if category hidden)
            // --------------------------------------------------
            final cat = categorizeAirport(airport);
            if ((cat == AirportCategory.airport && !_filterBig) ||
                (cat == AirportCategory.heli && !_filterHeli)) {
              continue;
            }

            // --------------------------------------------------
            // AIRPORT CORE
            // --------------------------------------------------
            final pos = LatLng(airport.lat, airport.lon);

            final isJobDest =
                widget.jobTo != null &&
                airport.icao == widget.jobTo!.toUpperCase();

            final baseColor = markerColor(cat);

            // Cached METAR
            final wx = _wxCache[airport.icao];
            final wxCat = metarCategory(wx);
            final wxColor = metarColor(wxCat);

            // --------------------------------------------------
            // WEATHER RING (back layer)
            // --------------------------------------------------
            markers.add(
              Marker(
                point: pos,
                width: 70,
                height: 70,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _showAirportInfo(airport),
                  child:
                      wx != null
                          ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: wxColor, width: 2),
                                ),
                              ),
                              Positioned(bottom: 0, child: wxIcon(wx)),
                            ],
                          )
                          : const SizedBox(),
                ),
              ),
            );

            // --------------------------------------------------
            // AIRPORT MARKER DOT
            // --------------------------------------------------
            markers.add(
              Marker(
                key: ValueKey('airport_${airport.icao}_$zoom'),
                point: pos,
                width: isJobDest ? 30 : 16,
                height: isJobDest ? 30 : 16,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAirportInfo(airport),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isJobDest ? Colors.orangeAccent : baseColor,
                      border: Border.all(
                        color:
                            isJobDest
                                ? Colors.redAccent
                                : baseColor.withOpacity(0.8),
                        width: isJobDest ? 3 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: baseColor.withOpacity(0.7),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(child: buildMarkerShape(cat, isJobDest)),
                  ),
                ),
              ),
            );
          }
        }
        // =======================================================
        // MODE B — CLUSTER MODE (zoomed out)
        // =======================================================
        else {
          clusters.clear();
          final bucketSize = zoom < 6.5 ? 4.0 : (zoom < 8.0 ? 2.0 : 0.0);

          for (final airport in visibleAirports) {
            // --------------------------------------------------
            // 🔎 CATEGORY FILTER (same logic as detailed view)
            // --------------------------------------------------
            final cat = categorizeAirport(airport);

            if ((cat == AirportCategory.airport && !_filterBig) ||
                (cat == AirportCategory.heli && !_filterHeli)) {
              continue; // skip airport completely
            }

            // --------------------------------------------------
            // CLUSTER BUCKET ASSIGNMENT
            // --------------------------------------------------
            final key =
                bucketSize == 0
                    ? airport.icao
                    : '${(airport.lat / bucketSize).floor()}_${(airport.lon / bucketSize).floor()}';

            clusters.putIfAbsent(key, () => []).add(airport);
          }

          for (final group in clusters.values) {
            final avgLat =
                group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
            final avgLon =
                group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;

            markers.add(
              Marker(
                point: LatLng(avgLat, avgLon),
                width: 36,
                height: 34,
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_airport,
                      size: 14,
                      color: Color.fromARGB(255, 15, 83, 173),
                      shadows: [Shadow(color: Colors.cyan, blurRadius: 4)],
                    ),
                    Text(
                      '${group.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'RobotoMono',
                        color: Color.fromARGB(255, 98, 87, 240),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }

        if (mounted) setState(() => _airportMarkers = markers);
        _throttledUpdateVorMarkers();
        _throttledUpdateNdbMarkers();
        _throttledUpdateRunwayPolylines();
        _throttledUpdateParkingMarkers();
        _throttledUpdateWaypointMarkers(force: true);
      });
    });
  }

  // ============================================================
  //  CONNECT TO SIMLINK (final version)
  // ============================================================
  void _connectToSimLink({bool manual = false}) async {
    if (!mounted) return;

    // Prevent parallel calls
    if (_connectionInProgress) {
      print("⛔ connectToSimLink blocked (already running)");
      return;
    }
    _connectionInProgress = true;

    final bool isReconnect = _hasEverConnected && !_isConnected;

    if (isReconnect) {
      print("🔄 SimLink RECONNECT STARTED...");
      _isReconnecting = true;
    }

    setState(() {
      _isConnecting = true;
      _isConnected = false;
      if (!isReconnect) simData = null;
      if (manual) _simLinkAvailable = true;
    });

    // -------- CONNECT --------
    await _socketService.connect((SimLinkData data) async {
      if (!mounted) return;

      _lastSocketData = DateTime.now();
      _simLinkResponded = true;

      setState(() {
        simData = data;
        _isConnected = true;
        _isConnecting = false;
        _isReconnecting = false;
      });

      _handleSimUpdate(data);

      if (!_hasEverConnected) _hasEverConnected = true;

      if (isReconnect) {
        await _restoreAfterReconnect();
      }

      _connectionInProgress = false;
    });

    // -------- CONNECTION TIMEOUT --------
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;

      if (!_isConnected) {
        print("⏳ SimLink connection timeout");

        setState(() {
          _isConnecting = false;
          _isConnected = false;
        });
      }

      _connectionInProgress = false;
    });
  }

  Future<void> _loadInitialCenter() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');

    if (userId != null) {
      try {
        final logs = await FlightLogService.getFlightLogs(userId);
        if (logs.isNotEmpty && logs.first.endLocation != null) {
          _lastFlightDestination =
              logs.first.endLocation != null
                  ? LatLng(
                    logs.first.endLocation!.lat,
                    logs.first.endLocation!.lng,
                  )
                  : null;
          _initialCenter = _lastFlightDestination; // 📍Set as camera center
        }
      } catch (e) {
        print('❌ Failed to fetch flight logs: $e');
      }
    }

    if (_homeBase == null && token != null) {
      try {
        final hq = await UserService(
          baseUrl: 'http://38.242.241.46:3000',
        ).getHq(token);
        if (hq != null) {
          _homeBase = LatLng(hq.lat, hq.lon);
          _initialCenter ??= _homeBase; // fallback center
        }
      } catch (e) {
        print('❌ Failed to fetch HQ: $e');
      }
    }

    _initialCenter ??= const LatLng(37.9838, 23.7275); // 💥 ultimate fallback

    if (!mounted) return;
    setState(() {
      _initialCenterReady = true;
    });
  }

  void _disconnectFromSimLink() async {
    final pos =
        simData != null ? LatLng(simData!.latitude, simData!.longitude) : null;

    print("🔌 SimLink disconnect requested");

    // Full force-close
    await _socketService.dispose();

    if (!mounted) return;
    setState(() {
      _isConnected = false;
      _isConnecting = false;
    });

    // Restore map view
    if (pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          mapController.move(pos, mapController.camera.zoom);
          mapController.rotate(0);
        } catch (_) {}
      });
    }
  }

  Color _getMapStyleIconColor() {
    final theme = tileLayers[_mapStyleIndex].name.toLowerCase();
    switch (theme) {
      case 'black':
        return Colors.white;
      case 'white':
        return Colors.black;
      case 'topomap':
        return Colors.blueGrey;
      default:
        return Colors.blueAccent;
    }
  }

  AirportLocation? _toAirportLocation(LatLng? point) {
    if (point == null || _airports.isEmpty) return null;

    const distance = Distance();

    // 🛡️ Prefer _homeBase if very close
    if (_homeBase != null) {
      final hqDist = distance.as(LengthUnit.Kilometer, point, _homeBase!);

      if (hqDist <= 2.78) {
        final match = _airports.firstWhere(
          (a) =>
              (a.lat - _homeBase!.latitude).abs() < 0.01 &&
              (a.lon - _homeBase!.longitude).abs() < 0.01,
          orElse:
              () => Airport(
                icao: 'HQ',
                lat: _homeBase!.latitude,
                lon: _homeBase!.longitude,
                name: '',
                country: '',
                elevation: 0,
                isMilitary: false,
              ),
        );

        return AirportLocation(
          icao: match.icao,
          lat: point.latitude,
          lng: point.longitude,
          name: '',
        );
      }
    }

    // 🔍 Otherwise fallback to nearest airport
    final nearest =
        _airports
            .map(
              (a) => {
                'airport': a,
                'dist': distance.as(
                  LengthUnit.Kilometer,
                  point,
                  LatLng(a.lat, a.lon),
                ),
              },
            )
            .toList()
          ..sort(
            (a, b) => (a['dist'] as double).compareTo(b['dist'] as double),
          );

    final closest = nearest.first['airport'] as Airport;

    return AirportLocation(
      icao: closest.icao,
      lat: point.latitude,
      lng: point.longitude,
      name: '',
    );
  }

  void _checkFuelRange() {
    if (simData == null || _plannedStart == null || _plannedEnd == null) return;

    final data = simData!;
    final ac = savedAircraft;

    // ============================================================
    // 1) LIVE + SAVED FUEL CAPACITY
    // ============================================================
    final double currentFuelGal = data.fuelGallons;

    final double fuelCap =
        data.fuelCapacityGallons > 0
            ? data.fuelCapacityGallons
            : (ac?.fuelCapacityGallons ?? 40.0);

    // Safety: don't allow 0-capacity bugs
    if (fuelCap <= 0) return;

    // ============================================================
    // 2) SIMPLE FUEL PERCENTAGE
    // ============================================================
    final double fuelPercent = (currentFuelGal / fuelCap) * 100;

    // ============================================================
    // 3) DISTANCE CHECK (only for user awareness)
    //    — NO RANGE MATH, JUST INFORMATIONAL
    // ============================================================
    final distanceNM =
        const Distance().as(
          LengthUnit.Kilometer,
          _plannedStart!,
          _plannedEnd!,
        ) *
        0.539957;

    // ============================================================
    // 4) RULES:
    //    - < 20% fuel → warn
    //    - Distance > 200 NM → optional soft warning
    // ============================================================
    bool lowFuel = fuelPercent < 20;
    bool longTrip = distanceNM > 200;

    if (!lowFuel && !longTrip) {
      print(
        "✅ Fuel OK (${fuelPercent.toStringAsFixed(1)}%), "
        "Trip: ${distanceNM.toStringAsFixed(0)} NM",
      );
      return;
    }

    // ============================================================
    // 5) SHOW WARNINGS
    // ============================================================
    String message = "";

    if (lowFuel) {
      message +=
          "⛽ Low fuel (${fuelPercent.toStringAsFixed(1)}%)! Consider refueling.\n";
    }

    if (longTrip) {
      message +=
          "🛫 Long trip ahead (${distanceNM.toStringAsFixed(0)} NM). "
          "Plan fuel stops.";
    }

    print("⚠ Fuel/Trip Warning → $message");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.trim()),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String normalizeAircraftId(String title) {
    if (title.toLowerCase().contains("pa28")) return "PA28";
    if (title.toLowerCase().contains("kodiak")) return "Kodiak";
    // Add more mappings if needed
    return title;
  }

  Future<void> _loadFlight() async {
    if (_currentFlight != null) {
      print("➡️ Server flight already loaded, skipping local.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final flightString = prefs.getString('last_flight');
    if (flightString == null) {
      print("⚠️ No flight data found in prefs.");
      return;
    }

    try {
      final flightJson = jsonDecode(flightString);
      final flight = Flight.fromJson(flightJson);

      if (!mounted) return;
      setState(() {
        _currentFlight = flight;
      });

      _checkFuelRange();

      print(
        "🧭 Loaded LOCAL Flight: ${flight.originIcao} → ${flight.destinationIcao}",
      );
    } catch (e) {
      print("❌ Failed to parse local flight: $e");
    }
  }

  void _showFlightDialog(BuildContext context) {
    if (_currentFlight == null) return;

    final origin = _currentFlight!.originIcao;
    final dest = _currentFlight!.destinationIcao;
    final cruise = _currentFlight!.cruiseAltitude;
    final dist = _currentFlight!.estimatedDistanceNm.toStringAsFixed(1);
    final etaMin = _currentFlight!.estimatedTime.inMinutes;

    final bool matchesDispatch =
        widget.jobTo != null && widget.jobTo!.toUpperCase() == dest;

    final waypoints = _getFlightWaypoints();
    final hasWaypoints = waypoints.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            "🧭 Flight Plan",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 400, // prevent overflow!
                  minWidth: 300, // optional
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "📍 From: $origin",
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Text(
                          "📍 To: $dest",
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                        if (matchesDispatch) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: const Text(
                              "🎯 Job Destination",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "🛫 Distance: $dist NM",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      "🕒 Estimated Time: ${formatEta(etaMin)}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),

                    if (cruise != null)
                      Text(
                        "🌤 Cruise Altitude: $cruise ft",
                        style: const TextStyle(color: Colors.white70),
                      ),

                    const SizedBox(height: 12),

                    if (hasWaypoints) ...[
                      const Text(
                        "🗺 Route Waypoints:",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: waypoints.length,
                        itemBuilder: (_, i) {
                          final wp = waypoints[i];

                          return Text(
                            "• ${wp.ident}",
                            style: const TextStyle(color: Colors.white70),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () => _cancelFlight(ctx, fromDialog: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.cancel,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Cancel Flight",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                "Close",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelFlight(BuildContext ctx, {bool fromDialog = true}) async {
    // Only close if coming from actual dialog
    if (fromDialog) {
      if (Navigator.of(ctx).canPop()) {
        Navigator.of(ctx).pop();
      }
    }

    // clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_flight');
    await prefs.remove('start_lat');
    await prefs.remove('start_lng');
    await prefs.remove('flight_trail');
    await prefs.remove('turbulence_events');
    await prefs.remove('flight_start_time');
    await prefs.setBool('hasRestoredPayload', false);

    // 🔥 delete backend flight too
    final userId = await SessionManager.getUserId();
    if (userId != null) {
      await FlightPlanService.deleteCurrentFlight(userId);
    }

    if (!mounted) return;

    // reset UI
    setState(() {
      _currentFlight = null;
      _trail.clear();
      _backendTrail.clear();
      _startPoint = null;
      _turbulenceEvents.clear();
    });

    if (!isDataOffline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Flight cancelled"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  LatLng _computeTargetFromHeading(
    LatLng origin,
    double bearingDeg,
    double distanceNM,
  ) {
    const double R = 3440.065; // Earth radius in nautical miles
    final double bearingRad = bearingDeg * pi / 180;

    final lat1 = origin.latitudeInRad;
    final lon1 = origin.longitudeInRad;
    final dByR = distanceNM / R;

    final lat2 = asin(
      sin(lat1) * cos(dByR) + cos(lat1) * sin(dByR) * cos(bearingRad),
    );
    final lon2 =
        lon1 +
        atan2(
          sin(bearingRad) * sin(dByR) * cos(lat1),
          cos(dByR) - sin(lat1) * sin(lat2),
        );

    return LatLng(lat2 * 180 / pi, lon2 * 180 / pi);
  }

  Future<void> _createDirectFlightTo(String destinationIcao) async {
    final prefs = await SharedPreferences.getInstance();

    final origin =
        simData != null
            ? LatLng(simData!.latitude, simData!.longitude)
            : _initialCenter ?? const LatLng(0, 0);

    final destination = _airportCoords[destinationIcao];

    if (destination == null) {
      print("❌ No coordinates found for $destinationIcao");
      return;
    }

    // ⭐ OFFICIAL AVIATION DISTANCE (Vincenty)
    final distanceNm = _calculateDistanceNm(origin, destination);

    // ⭐ Recommended cruise altitude (unchanged)
    final cruiseAlt = _recommendedAltitude(distanceNm);

    final flight = Flight(
      id: const Uuid().v4(),
      originIcao: 'LIVEPOS',
      destinationIcao: destinationIcao,
      generatedAt: DateTime.now(),
      aircraftType: normalizeAircraftId(simData?.title ?? 'Unknown'),
      estimatedDistanceNm: distanceNm,
      estimatedTime: Duration(minutes: (distanceNm / 110 * 60).round()),
      originLat: origin.latitude,
      originLng: origin.longitude,
      destinationLat: destination.latitude,
      destinationLng: destination.longitude,
      missionId: null,

      cruiseAltitude: cruiseAlt,
      plannedFuel: 0,
    );

    await prefs.setString('last_flight', jsonEncode(flight.toJson()));

    setState(() {
      _currentFlight = flight;
    });

    _checkFuelRange(); // unchanged

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🧭 Direct flight to $destinationIcao set')),
    );
  }

  double _calculateDistanceNm(LatLng p1, LatLng p2) {
    // WGS-84 ellipsoid params
    const double a = 6378137.0;
    const double f = 1 / 298.257223563;
    const double b = a * (1 - f);

    // Convert degrees to radians
    double toRad(double d) => d * pi / 180.0;

    final double lat1 = toRad(p1.latitude);
    final double lat2 = toRad(p2.latitude);
    final double L = toRad(p2.longitude - p1.longitude);

    double U1 = atan((1 - f) * tan(lat1));
    double U2 = atan((1 - f) * tan(lat2));

    double sinU1 = sin(U1);
    double cosU1 = cos(U1);
    double sinU2 = sin(U2);
    double cosU2 = cos(U2);

    double lambda = L;
    double lambdaPrev;
    const double eps = 1e-12;
    const int maxIter = 100;

    double sinLambda, cosLambda;
    double sinSigma, cosSigma, sigma;
    double sinAlpha, cosSqAlpha;
    double cos2SigmaM;
    int iter = 0;

    do {
      sinLambda = sin(lambda);
      cosLambda = cos(lambda);

      double t1 = cosU2 * sinLambda;
      double t2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda;

      double sinSqSigma = t1 * t1 + t2 * t2;
      sinSigma = sqrt(sinSqSigma);

      if (sinSigma == 0) return 0.0; // same point

      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = atan2(sinSigma, cosSigma);

      sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
      cosSqAlpha = 1 - sinAlpha * sinAlpha;

      if (cosSqAlpha != 0) {
        cos2SigmaM = cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha;
      } else {
        cos2SigmaM = 0; // equatorial line
      }

      double C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha));

      lambdaPrev = lambda;
      lambda =
          L +
          (1 - C) *
              f *
              sinAlpha *
              (sigma +
                  C *
                      sinSigma *
                      (cos2SigmaM +
                          C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
    } while ((lambda - lambdaPrev).abs() > eps && ++iter < maxIter);

    double uSq = cosSqAlpha * (a * a - b * b) / (b * b);

    double A =
        1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));

    double B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));

    double deltaSigma =
        B *
        sinSigma *
        (cos2SigmaM +
            B /
                4 *
                (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
                    B /
                        6 *
                        cos2SigmaM *
                        (-3 + 4 * sinSigma * sinSigma) *
                        (-3 + 4 * cos2SigmaM * cos2SigmaM)));

    double distMeters = b * A * (sigma - deltaSigma);

    return distMeters / 1852.0; // meters → NM
  }

  Future<void> _cleanupFlight(SharedPreferences prefs) async {
    _trail.clear();
    _backendTrail.clear();
    _lastBackendTrailUpdate = null;
    _startPoint = null;
    _turbulenceEvents.clear();
    _currentFlight = null;
    _flightQualified = false;
    await prefs.remove('start_lat');
    await prefs.remove('start_lng');
    await prefs.remove('flight_trail');
    await prefs.remove('turbulence_events');
    await prefs.remove('flight_start_time');
    await prefs.setBool('hasRestoredPayload', false);
    await prefs.remove('last_flight');
    await prefs.remove('flight_job_id');

    print("🧹 Cleanup complete. Flight reset.");
    if (mounted) setState(() {});
  }

  Future<void> _showFlightSummaryDialog(
    FlightLog log,
    AirportLocation? startLoc,
    AirportLocation? endLoc,
  ) async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("📊 Flight Summary"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("✈️ Aircraft: ${log.aircraft}"),
                Text("🕒 Duration: ${log.duration} min"),
                Text(
                  "📍 From: ${startLoc?.icao.isNotEmpty == true ? startLoc!.icao : '${startLoc?.lat}, ${startLoc?.lng}'}",
                ),
                Text(
                  "📍 To: ${endLoc?.icao.isNotEmpty == true ? endLoc!.icao : '${endLoc?.lat}, ${endLoc?.lng}'}",
                ),
                const Divider(),
                Text("🧭 Distance: ${_formatDistance(log.distanceFlown)}"),
                Text("📈 Max Altitude: ${log.maxAltitude} ft"),
                Text("🚀 Avg Airspeed: ${log.avgAirspeed} kts"),
                Text("⏱️ Cruise Time: ${log.cruiseTime} min"),
                Text("🪄 Trail Points: ${log.trail.length}"),
                const Divider(),
                Text("🌪️ Turbulence:"),
                Text("  Light: ${log.events['turbulenceCount']['light']}"),
                Text(
                  "  Moderate: ${log.events['turbulenceCount']['moderate']}",
                ),
                Text("  Severe: ${log.events['turbulenceCount']['severe']}"),
                const Divider(),

                Text(
                  "🧈 Landing Score: ${log.events['butterScore'] ?? '--'} / 100",
                ),
                Text(
                  "🛫 Takeoff Score: ${log.events['takeoffScore'] ?? '--'} / 100",
                ),
                const Divider(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Close"),
              ),
            ],
          ),
    );
  }

  Future<String> _deriveFlightType() async {
    final prefs = await SharedPreferences.getInstance();
    final jobJson = prefs.getString('active_dispatch_job');

    final hasJob = jobJson != null;

    final hasRoute =
        _currentFlight?.originIcao.isNotEmpty == true &&
        _currentFlight?.destinationIcao.isNotEmpty == true;

    if (hasJob && hasRoute) return 'free_with_job';
    return 'free';
  }

  int _recommendedAltitude(double distanceNm) {
    if (distanceNm < 20) return 1500;
    if (distanceNm < 50) return 3000;
    if (distanceNm < 100) return 5000;
    if (distanceNm < 160) return 8000;
    if (distanceNm < 250) return 10000;
    if (distanceNm < 350) return 12000;
    if (distanceNm < 500) return 14000;
    if (distanceNm < 700) return 16000;
    if (distanceNm < 1000) return 18000;
    return 22000;
  }

  Widget _autopilotPanel(AutopilotData ap) {
    Widget tiny(String label, bool active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: active ? Colors.greenAccent : Colors.white24,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: active ? Colors.greenAccent : Colors.white,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tiny("AP", ap.master),
        tiny("HDG", ap.headingLock),
        tiny("NAV", ap.navLock),
        tiny("APR", ap.approachHold),
        tiny("BC", ap.backcourseHold),
        tiny("ALT", ap.altitudeLock),
        tiny("VS", ap.verticalSpeedHold),
        tiny("IAS", ap.airspeedHold),
      ],
    );
  }

  Widget _etaHud() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _etaBox("ETA", _fmt(etaDest)),
          _etaBox("TOC", _fmt(etaTOC)),
          _etaBox("TOD", _fmt(etaTOD)),
        ],
      ),
    );
  }

  Widget _etaBox(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white30, width: 0.8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double? minutes) {
    if (minutes == null) return "--";
    final m = minutes.round();
    final h = m ~/ 60;
    final mm = m % 60;
    return h > 0 ? "${h}h ${mm}m" : "${mm}m";
  }

  void _updateEtas() {
    if (_currentFlight == null || simData == null) {
      etaDest = etaTOC = etaTOD = null;
      requiredClimbFpm = null;
      requiredDescentFpm = null;
      return;
    }

    final speedKt = (simData!.airspeed).clamp(40, 400);
    final cruiseAlt = _currentFlight!.cruiseAltitude!.toDouble();

    // ---------- DEST ETA ----------
    etaDest = (_remainingNm / speedKt) * 60;

    // ---------- TOC ETA ----------
    final distFromOrigin = _currentFlight!.estimatedDistanceNm - _remainingNm;
    double distToTOC = _tocDistanceNm - distFromOrigin;

    if (atCruiseAltitude) {
      etaTOC = 0;
    } else {
      etaTOC = distToTOC > 0 ? (distToTOC / speedKt) * 60 : 0;
    }

    // Required climb FPM
    if (!atCruiseAltitude && etaTOC != null && etaTOC! > 0) {
      final remainingAlt = cruiseAlt - simData!.altitude;
      requiredClimbFpm = remainingAlt > 0 ? remainingAlt / etaTOC! : 0;
    } else {
      requiredClimbFpm = 0;
    }

    // ---------- TOD ETA ----------
    final distToTOD = _remainingNm - _todDistanceNm;

    if (isStableCruise) {
      etaTOD = distToTOD > 0 ? (distToTOD / speedKt) * 60 : 0;
    } else {
      // If already descending or below cruise, TOD invalid
      etaTOD = 0;
    }

    // Required descent
    if (etaTOD != null && etaTOD! > 0 && isStableCruise) {
      final remainingAlt = simData!.altitude;
      requiredDescentFpm = remainingAlt / etaTOD!;
    } else {
      requiredDescentFpm = 0;
    }
  }

  void _computeTocTodPoints() {
    if (_currentFlight == null || simData == null) {
      _tocPoint = null;
      _todPoint = null;
      return;
    }

    final origin =
        _currentFlight!.originIcao == 'LIVEPOS'
            ? LatLng(_currentFlight!.originLat!, _currentFlight!.originLng!)
            : _airportCoords[_currentFlight!.originIcao]!;

    final dest = _airportCoords[_currentFlight!.destinationIcao]!;
    final totalNm = _calculateDistanceNm(origin, dest);

    // 🧠 Dynamically calculate current and target cruise altitudes
    final currentAlt = simData!.altitude;
    final targetCruise =
        simData?.autopilot.altitudeTarget ??
        _currentFlight?.cruiseAltitude ??
        0;
    final atTargetCruise = (currentAlt - targetCruise).abs() < 200;

    // --------- TOC POINT ---------
    if (isClimbing && !atTargetCruise) {
      if (_tocDistanceNm > 0 && _tocDistanceNm < totalNm) {
        _tocPoint = _pointOnRoute(origin, dest, _tocDistanceNm);
      }
    } else {
      _tocPoint = null;
    }

    // --------- TOD POINT ---------
    if (isStableCruise) {
      final todFromOrigin = totalNm - _todDistanceNm;

      if (todFromOrigin > 0 && todFromOrigin < totalNm) {
        _todPoint = _pointOnRoute(origin, dest, todFromOrigin);
      }
    } else {
      _todPoint = null;
    }
  }

  LatLng _pointOnRoute(LatLng a, LatLng b, double nmFromA) {
    final totalNm = _calculateDistanceNm(a, b);
    final ratio = nmFromA / totalNm;

    final lat = a.latitude + (b.latitude - a.latitude) * ratio;
    final lon = a.longitude + (b.longitude - a.longitude) * ratio;

    return LatLng(lat, lon);
  }

  Future<void> _loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_mapStyleKey);

    if (saved != null && saved >= 0 && saved < tileLayers.length) {
      setState(() => _mapStyleIndex = saved);
    }
  }

  Widget _systemStrip(MissionData m, bool isDesktop) {
    Widget sys(String label, bool active, {bool isDoor = false}) {
      final isDoorOpen = isDoor && active;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color:
                isDoorOpen
                    ? Colors.redAccent
                    : active
                    ? Colors.greenAccent
                    : Colors.white24,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isDoorOpen
                    ? Colors.redAccent
                    : active
                    ? Colors.greenAccent
                    : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // ------------------------------
    // Build main system items
    // ------------------------------
    final List<Widget> items = [
      sys("BATT", m.battery),
      sys("BEAC", m.beacon),
      sys("NAV", m.nav),
      sys("LAND", m.landing),
      sys("TAXI", m.taxi),
      sys("STRB", m.strobe),

      // 🔥 NEW ROW 1 ADDITIONS
      sys("PITOT", simData?.pitot ?? false),
      sys("A-ICE", simData?.antiIce ?? false),

      // Doors
      sys("L-MAIN", m.mainLeft, isDoor: true),
      sys("R-MAIN", m.mainRight, isDoor: true),
      sys("CARGO", m.cargo, isDoor: true),
      sys("PAX", m.passenger, isDoor: true),
    ];

    // ------------------------------
    // Split into two rows automatically
    // ------------------------------
    final int half = (items.length / 2).ceil();
    final List<Widget> row1 = items.sublist(0, half);
    final List<Widget> row2 = items.sublist(half);

    // ------------------------------
    // FINAL OUTPUT — always two rows
    // ------------------------------
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: row1),
        const SizedBox(height: 4),
        Row(children: row2),
        const SizedBox(height: 6),

        // Gear + Flaps
        if (simData != null) _gearFlapsRow(simData!),
        if (simData != null) _brakeRow(simData!),
      ],
    );
  }

  Future<void> _loadCurrentFlight() async {
    final userId = await SessionManager.getUserId();

    if (userId == null) {
      print("❌ No userId found — cannot load current flight.");
      return;
    }

    final plan = await FlightPlanService.getCurrentFlight(userId);

    if (!mounted) return;

    setState(() {
      _serverFlight = plan;

      // 🔥 MERGE HERE
      if (_serverFlight != null) {
        _currentFlight = _serverFlight;
      }
    });
  }

  // -----------------------------
  // LANDING RATING
  // -----------------------------
  String landingGradeFromVs(double vs) {
    final v = vs.abs();

    // Filter garbage values (SimConnect bug spikes)
    if (v > 3000) return "Invalid VS (Spike) ⚠️";

    if (v <= 80) return "BUTTER KING 🧈👑";
    if (v <= 140) return "Smooth 🟢";
    if (v <= 220) return "Normal 🟡";
    if (v <= 300) return "Firm 🟠";
    if (v <= 450) return "Hard 🔴";

    return "Crash Landing 💀";
  }

  // -----------------------------
  // TAKEOFF RATING
  // -----------------------------
  String takeoffGradeFromVs(double vs) {
    // VS at rotation is normally low. Filter anomalies.
    if (vs < -50) return "Rotation Error ⚠️";

    if (vs < 200) return "Smooth Rotation 🟢";
    if (vs < 350) return "Standard Rotate 🟡";
    if (vs < 550) return "High Nose-Up 🟠";
    if (vs < 800) return "Steep Pull 🚀";

    return "Unstable Rotation 💀";
  }

  void showHudMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.transparent,

      // ⭐⭐ FORCE TOP POSITION
      margin: const EdgeInsets.only(top: 40, left: 40, right: 40, bottom: 0),

      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.80),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.7),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.35),
              blurRadius: 18,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // ⭐ Show ON TOP
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }

  double _calculateButterScore(double vs) {
    // Example simple scoring:
    final smooth = vs.abs();
    if (smooth < 80) return 100;
    if (smooth < 140) return 90;
    if (smooth < 200) return 75;
    if (smooth < 300) return 55;
    return 30;
  }

  double _calculateTakeoffScore(double pitchDegrees) {
    if (pitchDegrees >= 8 && pitchDegrees <= 12) return 100;
    if (pitchDegrees >= 6 && pitchDegrees <= 14) return 80;
    return 60;
  }

  double _estimateFuelFlow() {
    switch (simData?.engineType) {
      case 0:
        return 0; // Electric
      case 1:
        return 9; // Piston (C172, DA40, Piper Archer)
      case 3:
        return 45; // Turboprop (Kodiak, Caravan, TBM ~50)
      case 2:
        return 300; // Jets (A320N, 737, 787)
      default:
        return 10;
    }
  }

  Widget _buildMetarPanel(WeatherData wx) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.cyanAccent.withOpacity(0.7),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE + TXT MODE BUTTON
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "METAR (Live Aircraft Position)",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _showRawMetar = !_showRawMetar);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      !_showRawMetar ? "RAW" : "FRIENDLY",
                      style: TextStyle(
                        color: Colors.cyanAccent.withOpacity(
                          _showRawMetar ? 1.0 : 0.6,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ===========================
            // MODE 1 — METAR STRING MODE
            // ===========================
            if (_showRawMetar) ...[
              Text(
                _buildMetarString(wx),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
            // ===========================
            // MODE 2 — FULL UI PANEL
            // ===========================
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Wind",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _windArrow(wx.windDirection, wx.windVelocity),
                ],
              ),
              _wxLine(
                "Visibility",
                "${(wx.visibility / 1000).toStringAsFixed(1)} km",
              ),
              _wxLine("Temperature", "${wx.temperature.toStringAsFixed(0)}°C"),

              // Pressures in HPA + INHG
              _wxLine(
                "QNH",
                "${wx.seaLevelPressure.toStringAsFixed(0)} hPa   (${_hpaToInHg(wx.seaLevelPressure)} inHg)",
              ),
              _wxLine(
                "BARO",
                "${wx.baroPressure.toStringAsFixed(0)} hPa   (${_hpaToInHg(wx.baroPressure)} inHg)",
              ),
              _wxLine(
                "Ambient",
                "${wx.ambientPressure.toStringAsFixed(2)} inHg   (${(wx.ambientPressure / 0.029529983).toStringAsFixed(0)} hPa)",
              ),

              _wxLine("Cloud Density", wx.cloudDensity.toStringAsFixed(1)),
              _wxLine("In Cloud", wx.inCloud ? "YES" : "NO"),

              _wxLine("Precipitation", _precip(wx.precipState)),
              _wxLine("Precip Rate", wx.precipRate.toStringAsFixed(2)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _wxLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _precip(int state) {
    if (state == 2) return "None";
    if (state == 4) return "Rain";
    if (state == 8) return "Snow";
    return "Unknown";
  }

  String _hpaToInHg(double hpa) {
    return (hpa * 0.029529983).toStringAsFixed(2);
  }

  String _buildMetarString(WeatherData wx) {
    final windDir = wx.windDirection.toStringAsFixed(0).padLeft(3, '0');
    final windVel = wx.windVelocity.toStringAsFixed(0).padLeft(2, '0');

    final wind = "$windDir${windVel}KT";

    final vis =
        wx.visibility > 9999 ? "9999" : wx.visibility.toStringAsFixed(0);

    final temp = wx.temperature.toStringAsFixed(0);
    final qnh = wx.seaLevelPressure.toStringAsFixed(0);
    final precip = _precip(wx.precipState).toUpperCase();

    return "POS $wind $vis $precip ${temp}C Q$qnh";
  }

  Widget _windArrow(double directionDegrees, double speed) {
    final angleRad = (directionDegrees + 90) * pi / 180;

    return Row(
      children: [
        Transform.rotate(
          angle: angleRad,
          child: const Icon(
            Icons.arrow_upward,
            color: Colors.cyanAccent,
            size: 28,
            shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "${directionDegrees.toStringAsFixed(0)}° / ${speed.toStringAsFixed(0)} kt",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _openNavigraphSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // ❌ can't tap outside to close
      enableDrag: false, // ❌ can't drag down
      isScrollControlled: true, // fullscreen-style height
      backgroundColor: Colors.black,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.92, // almost fullscreen
          child: Column(
            children: [
              // --- HEADER BAR ---
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Colors.black87,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Navigraph Charts",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // CLOSE BUTTON 🔻
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // --- WEBVIEW AREA ---
              Expanded(child: _cachedNavigraph!),
            ],
          ),
        );
      },
    );
  }

  void _openIcaoSearchDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Go to ICAO"),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: "Enter ICAO (e.g. LGAV)",
              hintText: "ICAO Code",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final icao = controller.text.trim().toUpperCase();
                Navigator.pop(ctx);
                _goToIcao(icao);
              },
              child: const Text("Go"),
            ),
          ],
        );
      },
    );
  }

  void _goToIcao(String icao) {
    if (!_airportCoords.containsKey(icao)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ICAO '$icao' not found"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final target = _airportCoords[icao]!;

    mapController.move(target, 12);

    // 🔵 Force airport markers to update NOW
    _throttledUpdateAirportMarkers();

    // Optional popup
    _showIcaoPopup(icao, target);
  }

  void _showIcaoPopup(String icao, LatLng pos) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Centered on $icao"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String formatEta(int minutes) {
    if (minutes < 60) {
      return "$minutes min";
    }

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (mins == 0) {
      return "${hours}h";
    }

    return "${hours}h ${mins}m";
  }

  Color markerColor(AirportCategory cat) {
    switch (cat) {
      case AirportCategory.airport:
        return const Color(0xFF1E88E5); // strong blue

      case AirportCategory.heli:
        return const Color(0xFFC5E1A5); // helipad green

      default:
        return Colors.grey;
    }
  }

  Widget buildMarkerShape(AirportCategory cat, bool isJobDest) {
    switch (cat) {
      case AirportCategory.heli:
        return const Text(
          "H",
          style: TextStyle(
            color: Colors.black,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );

      case AirportCategory.airport:
        return Container(
          width: isJobDest ? 6 : 4,
          height: isJobDest ? 6 : 4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        );

      default: // unknown or weird icao
        return Container(
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white70,
          ),
        );
    }
  }

  Future<bool> _recentLanding() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt("last_landing_ms") ?? 0;
    final delta = DateTime.now().millisecondsSinceEpoch - last;
    return delta < 8000; // 8 sec cooldown
  }

  Future<void> _markLanding() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("last_landing_ms", DateTime.now().millisecondsSinceEpoch);
  }

  String takeoffGradeFromPitch(double p) {
    p = p.abs(); // safety

    if (p < 2) return "Late Rotate 🟡";
    if (p < 6) return "Shallow Rotate 🟡";
    if (p < 10) return "Smooth Rotation 🟢"; // PERFECT
    if (p < 14) return "Aggressive Rotate 🟠";
    if (p < 20) return "Over-Rotate 🚨";

    return "Unstable Rotation 💀";
  }

  String _formatDistance(double nm) {
    if (nm < 1.0) {
      final meters = (nm * 1852).round();
      return "$meters m";
    } else {
      return "${nm.toStringAsFixed(1)} NM";
    }
  }

  BoxDecoration offlineBadgeDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      borderRadius: BorderRadius.circular(10),

      // 🔹 Background style
      color:
          isDark
              ? Colors.black.withOpacity(0.50)
              : Colors.white.withOpacity(0.35),

      // 🔹 Navigraph-style borderlines
      border: Border.all(
        color:
            isDark
                ? colors.primary.withOpacity(
                  0.35,
                ) // cyan/blue glow in dark mode
                : Colors.black.withOpacity(0.20), // soft grey in light mode
        width: 1.2,
      ),

      // 🔹 Optional subtle shadow
      boxShadow: [
        BoxShadow(
          color:
              isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Color _altitudeTint(double alt) {
    if (alt < 1000) return Colors.redAccent;
    if (alt < 5000) return Colors.orangeAccent;
    if (alt < 10000) return Colors.yellowAccent;
    if (alt < 15000) return Colors.lightGreenAccent;
    if (alt < 25000) return Colors.cyanAccent;
    return Colors.blueAccent;
  }

  Color _mix(Color a, Color b, double amount) {
    return Color.lerp(a, b, amount) ?? a;
  }

  Widget _gearFlapsRow(SimLinkData d) {
    final bool gearDown = d.gearHandleDown;
    final int flaps = d.flapsIndex;

    // You can adjust degrees if aircraft is not 10° per index
    final int flapDegrees = flaps * 10;

    Widget box(String text, bool active, {bool danger = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color:
                danger
                    ? Colors.redAccent
                    : active
                    ? Colors.greenAccent
                    : Colors.white24,
            width: 0.8,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color:
                danger
                    ? Colors.redAccent
                    : active
                    ? Colors.greenAccent
                    : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Row(
      children: [
        // 🛬 GEAR
        box(gearDown ? "GEAR ↓" : "GEAR ↑", gearDown),

        // 🪂 FLAPS
        box("F: ${flapDegrees}°", flapDegrees > 0),
      ],
    );
  }

  Widget _brakeRow(SimLinkData d) {
    Widget sys(String label, bool active, {bool isParking = false}) {
      final Color color = active ? Colors.redAccent : Colors.white24;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    bool brakeActive(double v) => v > 5; // filter noise

    return Row(
      children: [
        // 🅿 Parking brake ON = RED
        sys("P-BRK", d.parkingBrake, isParking: true),

        // 🚫 Toe brakes pressed = RED
        sys("L-BRK", brakeActive(d.leftBrake)),
        sys("R-BRK", brakeActive(d.rightBrake)),
      ],
    );
  }

  Widget _vibrateIfEngineOn(Widget child) {
    final engineOn = simData?.combustion ?? false;

    if (!engineOn) return child;

    return AnimatedBuilder(
      animation: _engineShake,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(_engineShake.value, 0),
          child: child,
        );
      },
    );
  }

  Widget powerDim(Widget child) {
    // BATT OFF → pitch black
    if (!battOn) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcATop),
        child: child,
      );
    }

    // BATT ON but AVIONICS OFF → dim
    if (batteryOnly) {
      return Opacity(opacity: 0.3, child: child);
    }

    // Full power → normal
    return child;
  }

  bool isIcing(SimLinkData d) {
    final temp = d.weather.temperature; // °C
    final icing = d.structural; // 0–100%
    final inCloud = d.weather.inCloud;
    final precip = d.weather.precipState; // 0 none, 1 rain, 2 snow, 3 sleet

    final isSnow = precip == 2;
    final isSleet = precip == 3;

    return icing > 1 && temp <= 3 && (inCloud || isSnow || isSleet);
  }

  Future<void> _restoreAfterReconnect() async {
    print("🔧 Restoring full map state after reconnect...");
    if (_currentFlight == null) return;
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ restore aircraft center
    if (simData != null) {
      final pos = LatLng(simData!.latitude, simData!.longitude);
      mapController.move(pos, mapController.camera.zoom);
    }

    // 2️⃣ trail
    final savedTrail = prefs.getString("flight_trail");
    if (savedTrail != null) {
      final jsonList = jsonDecode(savedTrail);
      _trail = jsonList.map((e) => LatLng(e["lat"], e["lng"])).toList();
    }

    // 3️⃣ backend trail
    _backendTrail = List.from(_backendTrail);

    // 4️⃣ restore current flight
    await _loadCurrentFlight();

    // 5️⃣ start point
    final sLat = prefs.getDouble("start_lat");
    final sLng = prefs.getDouble("start_lng");
    if (sLat != null && sLng != null) {
      _startPoint = LatLng(sLat, sLng);
    }

    // 6️⃣ airport markers
    _throttledUpdateAirportMarkers(force: true);

    // 7️⃣ force rebuild overlays
    if (mounted) setState(() {});

    print("✅ Reconnect Restore Complete");
  }

  /// Load saved aircraft performance data from backend
  Future<void> _loadSavedAircraft() async {
    if (simData == null) return; // no data yet

    final id = normalizeAircraftId(simData!.title);
    if (id.isEmpty) return;

    try {
      final ac = await AircraftService.getOne(id);
      if (!mounted) return;

      setState(() {
        savedAircraft = ac;
      });

      print("📘 Loaded saved aircraft profile: ${ac?.title}");
    } catch (e) {
      print("⚠️ Could not load saved aircraft: $e");
    }
  }

  String metarCategory(Map<String, dynamic>? wx) {
    if (wx == null) return "UNKNOWN";

    // Visibility (meters)
    final vis =
        int.tryParse(
          wx["raw"]
                  ?.split(" ")
                  .firstWhere(
                    (p) => RegExp(r"^\d{4}$").hasMatch(p),
                    orElse: () => "9999",
                  ) ??
              "9999",
        ) ??
        9999;

    // Cloud layers
    final clouds = wx["clouds"] ?? [];

    // Detect ceiling (lowest BKN/OVC)
    int? ceiling;
    for (final c in clouds) {
      if (c.startsWith("BKN") || c.startsWith("OVC")) {
        ceiling = int.tryParse(c.substring(3))! * 100;
        break;
      }
    }

    // --- CATEGORY LOGIC ---
    if (vis >= 5000 && (ceiling == null || ceiling >= 3000)) return "VFR";
    if (vis >= 3000 && (ceiling == null || ceiling >= 1000)) return "MVFR";
    if (vis >= 1600 && (ceiling == null || ceiling >= 500)) return "IFR";
    return "LIFR";
  }

  Color metarColor(String cat) {
    switch (cat) {
      case "VFR":
        return Colors.greenAccent;
      case "MVFR":
        return Colors.blueAccent;
      case "IFR":
        return Colors.redAccent;
      case "LIFR":
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  Widget wxIcon(Map<String, dynamic>? wx) {
    if (wx == null) return const SizedBox();

    final raw = wx["raw"] ?? "";

    if (raw.contains("TS")) {
      return const Icon(Icons.flash_on, color: Colors.yellowAccent, size: 18);
    }
    if (raw.contains("SN")) {
      return const Icon(Icons.ac_unit, color: Colors.white, size: 16);
    }
    if (raw.contains("RA") || raw.contains("DZ")) {
      return const Icon(Icons.water_drop, color: Colors.blueAccent, size: 16);
    }
    if (raw.contains("FG") || raw.contains("BR")) {
      return const Icon(Icons.visibility_off, color: Colors.grey, size: 16);
    }

    return const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 16);
  }

  Future<void> _updateWeatherCache(List<Airport> airports) async {
    // Update every 10 minutes max
    if (_lastWxUpdate != null &&
        DateTime.now().difference(_lastWxUpdate!).inMinutes < 10) {
      return;
    }

    _lastWxUpdate = DateTime.now();

    for (final a in airports) {
      try {
        final wx = await MetarService.getBriefing(a.icao);
        _wxCache[a.icao] = wx;
      } catch (_) {
        _wxCache[a.icao] = null;
      }
    }

    if (mounted) setState(() {});
  }

  Widget _categoryBadge(Map<String, dynamic> wx) {
    final cat = wx["category"] ?? "UNKNOWN";

    Color col;
    switch (cat) {
      case "VFR":
        col = Colors.greenAccent;
        break;
      case "MVFR":
        col = Colors.blueAccent;
        break;
      case "IFR":
        col = Colors.redAccent;
        break;
      case "LIFR":
        col = Colors.purpleAccent;
        break;
      default:
        col = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: col.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: col, width: 1),
      ),
      child: Text(
        cat,
        style: TextStyle(color: col, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Helper row widget
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadVors() async {
    final jsonStr = await rootBundle.loadString('assets/data/vors.json');
    final List<dynamic> jsonList = json.decode(jsonStr);

    final vors = jsonList.map((e) => Vor.fromJson(e)).toList();

    if (!mounted) return;
    setState(() {
      _vors = vors;
    });

    print("📡 Loaded ${_vors.length} VOR stations");
  }

  void _throttledUpdateVorMarkers({bool force = false}) {
    if (!_showVOR || _vors.isEmpty) return;

    if (_vorUpdateThrottle?.isActive ?? false) return;

    _vorUpdateThrottle = Timer(const Duration(milliseconds: 250), () async {
      if (!_mapReady) return;

      final camera = mapController.camera;

      if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

      final zoom = camera.zoom;
      final bounds = camera.visibleBounds;

      // Hide ONLY at extreme zoom-out
      if (zoom < 8) {
        if (mounted) setState(() => _vorMarkers = []);
        return;
      }

      // Prevent useless recalculations
      if (!force && zoom == _lastVorZoom && bounds == _lastVorBounds) return;

      if (!force) {
        _lastVorZoom = zoom;
        _lastVorBounds = bounds;
      }

      final List<Vor> visibleVors =
          _vors.where((v) {
            return bounds.contains(LatLng(v.lat, v.lon));
          }).toList();

      final List<Marker> markers = [];

      // --------------------------
      // MODE A — FULL DETAIL
      // --------------------------
      if (zoom >= 9.0) {
        for (final v in visibleVors) {
          markers.add(
            Marker(
              point: LatLng(v.lat, v.lon),
              width: 26,
              height: 26,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("VOR ${v.ident} – ${v.frequency} MHz"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.9),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: const Center(
                    child: Text(
                      "V",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
      // --------------------------
      // MODE B — CLUSTER MODE
      // --------------------------
      else {
        _vorClusters.clear();

        final bucketSize = zoom < 6.5 ? 4.0 : (zoom < 8.0 ? 2.0 : 0.0);

        for (final v in visibleVors) {
          final key =
              bucketSize == 0
                  ? v.ident
                  : '${(v.lat / bucketSize).floor()}_${(v.lon / bucketSize).floor()}';

          _vorClusters.putIfAbsent(key, () => []).add(v);
        }

        for (final group in _vorClusters.values) {
          final avgLat =
              group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
          final avgLon =
              group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;

          markers.add(
            Marker(
              point: LatLng(avgLat, avgLon),
              width: 30,
              height: 30,
              child: Column(
                children: [
                  Icon(
                    Icons.radio,
                    size: 12,
                    color: Colors.blueAccent.withOpacity(0.8),
                  ),
                  Text(
                    '${group.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      // Update state
      if (mounted) {
        setState(() => _vorMarkers = markers);
      }
    });
  }

  Future<void> _loadNdbs() async {
    final jsonStr = await rootBundle.loadString('assets/data/ndb.json');
    final List<dynamic> jsonList = json.decode(jsonStr);

    final items = jsonList.map((e) => Ndb.fromJson(e)).toList();

    if (!mounted) return;
    setState(() => _ndbs = items);

    print("📡 Loaded ${_ndbs.length} NDB stations");
  }

  List<Marker> _buildNdbDetailMarkers(List<Ndb> visible) {
    return visible.map((n) {
      return Marker(
        point: LatLng(n.lat, n.lon),
        width: 26,
        height: 26,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("NDB ${n.ident} – ${n.frequency} kHz"),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(0.85),
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: const Center(
              child: Text(
                "N",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildNdbClusterMarkers(List<Ndb> visible, double zoom) {
    final Map<String, List<Ndb>> buckets = {};

    final bucketSize = zoom < 6.5 ? 4.0 : (zoom < 8.0 ? 2.0 : 0.0);

    for (final n in visible) {
      final key =
          bucketSize == 0
              ? n.ident
              : '${(n.lat / bucketSize).floor()}_${(n.lon / bucketSize).floor()}';

      buckets.putIfAbsent(key, () => []).add(n);
    }

    return buckets.values.map((group) {
      final avgLat =
          group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
      final avgLon =
          group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;

      return Marker(
        point: LatLng(avgLat, avgLon),
        width: 30,
        height: 30,
        child: Column(
          children: [
            Icon(
              Icons.radio_button_checked,
              size: 12,
              color: Colors.orangeAccent,
            ),
            Text(
              "${group.length}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _throttledUpdateNdbMarkers({bool force = false}) {
    if (!_showNDB || _ndbs.isEmpty) return;

    if (_ndbUpdateThrottle?.isActive ?? false) return;

    _ndbUpdateThrottle = Timer(const Duration(milliseconds: 250), () async {
      if (!_mapReady) return;

      final camera = mapController.camera;

      if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

      final zoom = camera.zoom;
      final bounds = camera.visibleBounds;

      if (!force && zoom == _lastNdbZoom && bounds == _lastNdbBounds) return;

      if (!force) {
        _lastNdbZoom = zoom;
        _lastNdbBounds = bounds;
      }

      final visible =
          _ndbs.where((n) {
            return bounds.contains(LatLng(n.lat, n.lon));
          }).toList();

      final List<Marker> markers =
          zoom >= 9.0
              ? _buildNdbDetailMarkers(visible)
              : _buildNdbClusterMarkers(visible, zoom);

      if (mounted) setState(() => _ndbMarkers = markers);
    });
  }

  Future<void> _loadRunways() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/runways.json');
      final List<dynamic> jsonList = json.decode(jsonStr);

      final runways = jsonList.map((e) => Runway.fromJson(e)).toList();

      if (!mounted) return;
      setState(() {
        _runways = runways;
      });

      print("🛬 Loaded ${runways.length} runways");
    } catch (e) {
      print("❌ Error loading runways: $e");
    }
  }

  List<Polyline> _buildRunwayPolylines(List<Runway> visible) {
    return visible.map((r) {
      return Polyline(
        points: [LatLng(r.end1Lat, r.end1Lon), LatLng(r.end2Lat, r.end2Lon)],
        strokeWidth: 4,
        color: _runwayColorForSurface(r.surface),
      );
    }).toList();
  }

  Color _runwayColorForSurface(String s) {
    switch (s.toUpperCase()) {
      case 'A': // Asphalt
      case 'ASP':
        return Colors.white;

      case 'C': // Concrete
        return Colors.grey.shade300;

      case 'G': // Grass
        return Colors.greenAccent;

      case 'D': // Dirt
        return Colors.brown;

      case 'GR': // Gravel
        return Colors.orangeAccent;

      case 'S': // Snow/Ice
        return Colors.cyanAccent;

      default:
        return Colors.white70;
    }
  }

  void _throttledUpdateRunwayPolylines({bool force = false}) {
    if (!_showRunways || _runways.isEmpty) return;

    if (_runwayUpdateThrottle?.isActive ?? false) return;

    _runwayUpdateThrottle = Timer(const Duration(milliseconds: 250), () async {
      if (!_mapReady) return;

      final camera = mapController.camera;
      if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

      final zoom = camera.zoom;
      final bounds = camera.visibleBounds;

      // Prevent unnecessary recalculation
      if (!force && zoom == _lastRunwayZoom && bounds == _lastRunwayBounds) {
        return;
      }

      if (!force) {
        _lastRunwayZoom = zoom;
        _lastRunwayBounds = bounds;
      }

      // Hide runways when zoomed too far out
      if (zoom < 11.0) {
        if (mounted) {
          setState(() {
            _runwayPolylines = [];
            _runwayMarkers = []; // <-- HIDE IDENT LABELS TOO
          });
        }
        return;
      }

      // Runways inside visible bounds
      final visible =
          _runways.where((r) {
            return bounds.contains(LatLng(r.end1Lat, r.end1Lon)) ||
                bounds.contains(LatLng(r.end2Lat, r.end2Lon));
          }).toList();

      // 🔵 Build Polylines
      final newPolylines = _buildRunwayPolylines(visible);

      // 🔵 Build IDENT markers (runway numbers)
      final newMarkers = <Marker>[];

      if (zoom >= 13.0) {
        // Only when close enough
        for (final r in visible) {
          // END 1
          newMarkers.add(
            Marker(
              point: LatLng(r.end1Lat, r.end1Lon),
              width: 40,
              height: 40,
              child: Transform.rotate(
                angle: r.end1Heading * pi / 180,
                child: Center(
                  child: Text(
                    r.end1Ident,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
          );

          // END 2
          newMarkers.add(
            Marker(
              point: LatLng(r.end2Lat, r.end2Lon),
              width: 40,
              height: 40,
              child: Transform.rotate(
                angle: r.end2Heading * pi / 180,
                child: Center(
                  child: Text(
                    r.end2Ident,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _runwayPolylines = newPolylines;
          _runwayMarkers = newMarkers; // <-- STORE THE LABELS
        });
      }
    });
  }

  void _throttledUpdateParkingMarkers({bool force = false}) {
    if (!_showParking || _parkings.isEmpty) return;

    if (_parkingUpdateThrottle?.isActive ?? false) return;

    _parkingUpdateThrottle = Timer(const Duration(milliseconds: 250), () async {
      if (!_mapReady) return;

      final camera = mapController.camera;
      if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

      final zoom = camera.zoom;
      final bounds = camera.visibleBounds;

      if (!force && zoom == _lastParkingZoom && bounds == _lastParkingBounds)
        return;

      if (!force) {
        _lastParkingZoom = zoom;
        _lastParkingBounds = bounds;
      }

      // 💥 NEW RULE: HIDE BELOW 15
      if (zoom < 15.0) {
        if (mounted) setState(() => _parkingMarkers = []);
        return;
      }

      // Visible parkings
      final visible =
          _parkings.where((p) {
            return bounds.contains(LatLng(p.lat, p.lon));
          }).toList();

      final List<Marker> markers = [];

      // ⭐ FULL DETAIL ONLY (we removed clustering)
      for (final p in visible) {
        markers.add(
          Marker(
            point: LatLng(p.lat, p.lon),
            width: 26,
            height: 26,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "🅿️ ${p.icao} – ${p.name} ${p.number}"
                      "\nType: ${p.type}   Jetway: ${p.hasJetway ? 'YES' : 'NO'}",
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Transform.rotate(
                angle: p.heading * (pi / 180),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        p.hasJetway
                            ? Colors.greenAccent.withOpacity(0.85)
                            : Colors.orangeAccent.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    p.number.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if (mounted) setState(() => _parkingMarkers = markers);
    });
  }

  Future<void> _loadParking() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/parking.json');
      final List<dynamic> jsonList = json.decode(jsonStr);

      final spots = jsonList.map((e) => ParkingSpot.fromJson(e)).toList();

      if (!mounted) return;

      setState(() {
        _parkings = spots;
        _parkingSpots = spots;
      });

      print("🅿️ Loaded ${spots.length} parking spots");
    } catch (e) {
      print("❌ Failed to load parking.json → $e");
    }
  }

  Future<void> _loadWaypoints() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/waypoints.json');
      final List<dynamic> jsonList = json.decode(jsonStr);

      final list = jsonList.map((e) => Waypoint.fromJson(e)).toList();

      if (!mounted) return;
      setState(() {
        _waypoints = list;
      });

      print("🟢 Loaded ${_waypoints.length} waypoints.");
    } catch (e) {
      print("❌ Failed to load waypoints: $e");
    }
  }

  void _throttledUpdateWaypointMarkers({bool force = false}) {
    if (!_showWaypoints || _waypoints.isEmpty) return;
    if (_waypointThrottle?.isActive ?? false) return;

    _waypointThrottle = Timer(const Duration(milliseconds: 250), () async {
      if (!_mapReady) return;

      final camera = mapController.camera;
      if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

      final zoom = camera.zoom;
      final bounds = camera.visibleBounds;

      // Skip unnecessary recalculation
      if (!force &&
          zoom == _lastWaypointZoom &&
          bounds == _lastWaypointBounds) {
        return;
      }

      if (!force) {
        _lastWaypointZoom = zoom;
        _lastWaypointBounds = bounds;
      }

      // Hard hide only at extreme world zoom
      if (zoom < 4.8) {
        if (mounted) setState(() => _waypointMarkers = []);
        return;
      }

      // Only visible waypoints
      final visible =
          _waypoints
              .where((w) => bounds.contains(LatLng(w.lat, w.lon)))
              .toList();

      final List<Marker> markers = [];
      final double aircraftHeadingDeg = simData?.heading ?? 0.0;
      final double textRotationRad = -aircraftHeadingDeg * pi / 180;

      // ========================================
      // MODE A — FULL DETAIL (terminal / approach)
      // ========================================
      if (zoom >= 11.0) {
        for (final w in visible) {
          markers.add(
            Marker(
              point: LatLng(w.lat, w.lon),
              width: 42,
              height: 42,
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "FIX ${w.ident}\n${w.type}  "
                        "(${w.lat.toStringAsFixed(4)}, "
                        "${w.lon.toStringAsFixed(4)})",
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Column(
                  children: [
                    const Icon(
                      Icons.change_history,
                      color: Colors.amberAccent,
                      size: 16,
                    ),
                    Transform.rotate(
                      angle: textRotationRad,
                      child: Text(
                        w.ident,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
      // ========================================
      // MODE B — CLUSTER / DECLUTTER MODE
      // ========================================
      else {
        _waypointClusters.clear();

        final double bucketSize =
            zoom < 6.5
                ? 2.5 // country / FIR
                : zoom < 8.5
                ? 1.5 // regional
                : zoom < 10.0
                ? 0.8 // TMA
                : 0.4; // near-terminal

        for (final w in visible) {
          final key =
              '${(w.lat / bucketSize).floor()}_${(w.lon / bucketSize).floor()}';
          _waypointClusters.putIfAbsent(key, () => []).add(w);
        }

        for (final group in _waypointClusters.values) {
          final avgLat =
              group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
          final avgLon =
              group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;

          markers.add(
            Marker(
              point: LatLng(avgLat, avgLon),
              width: 36,
              height: 36,
              child: Column(
                children: [
                  Icon(
                    Icons.change_history,
                    color: Colors.amberAccent.withOpacity(0.85),
                    size: 14,
                  ),
                  Transform.rotate(
                    angle: textRotationRad,
                    child: Text(
                      '${group.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() => _waypointMarkers = markers);
      }
    });
  }

  Future<void> _loadAirportFrequencies() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/airport_frequencies.json',
      );
      final List<dynamic> jsonList = json.decode(jsonStr);

      final list = jsonList.map((e) => AirportFrequency.fromJson(e)).toList();

      // Group by ICAO
      final Map<String, List<AirportFrequency>> grouped = {};

      for (final f in list) {
        grouped.putIfAbsent(f.airportIdent, () => []).add(f);
      }

      if (!mounted) return;

      setState(() {
        _frequencies = list;
        _freqByIcao = grouped;
      });

      print(
        "🟢 Loaded ${_frequencies.length} frequencies for ${_freqByIcao.length} airports",
      );
    } catch (e) {
      print("❌ Failed to load airport frequencies: $e");
    }
  }

  void _scheduleJsonLoads() {
    final steps = <Map<String, dynamic>>[
      {'delay': 0, 'fn': _loadAirports},
      {'delay': 400, 'fn': _loadRunways},
      {'delay': 800, 'fn': _loadParking},
      {'delay': 1200, 'fn': _loadVors},
      {'delay': 1600, 'fn': _loadNdbs},
      {'delay': 2000, 'fn': _loadWaypoints},
      {'delay': 2400, 'fn': _loadAirportFrequencies},
    ];

    for (final step in steps) {
      final int delay = step['delay'] as int;
      final Future<void> Function() fn = step['fn'] as Future<void> Function();

      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        fn();
      });
    }
  }

  String? _detectRunway(LatLng pos) {
    if (simData == null || !simData!.onRunway) return null;

    final currentIcao = _detectCurrentAirportIcao(pos);
    if (currentIcao == null) return null;

    final airportPos = _airportCoords[currentIcao];
    if (airportPos == null) return null;

    const airportRadiusMeters = 3000.0;
    const headingTolerance = 20.0;

    final distance = Distance();
    final aircraftHeading = simData!.heading;

    String? bestIdent;
    double bestHeadingDiff = double.infinity;

    for (final rwy in _runways) {
      final mid = _runwayMidpoint(rwy);

      // Only consider runways near this airport
      if (distance(mid, airportPos) > airportRadiusMeters) continue;

      final d1 = _headingDiff(aircraftHeading, rwy.end1Heading);
      final d2 = _headingDiff(aircraftHeading, rwy.end2Heading);

      if (d1 < bestHeadingDiff && d1 <= headingTolerance) {
        bestHeadingDiff = d1;
        bestIdent = rwy.end1Ident;
      }

      if (d2 < bestHeadingDiff && d2 <= headingTolerance) {
        bestHeadingDiff = d2;
        bestIdent = rwy.end2Ident;
      }
    }

    if (bestIdent != null) {
      print(
        "🛬 Runway detected: $currentIcao RWY $bestIdent "
        "(Δhdg=${bestHeadingDiff.toStringAsFixed(1)}°)",
      );
    }

    return bestIdent;
  }

  LatLng _runwayMidpoint(Runway r) {
    return LatLng((r.end1Lat + r.end2Lat) / 2, (r.end1Lon + r.end2Lon) / 2);
  }

  double _headingDiff(double a, double b) {
    double d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  String? _detectCurrentAirportIcao(LatLng pos) {
    const maxDistMeters = 4000.0;
    final distance = Distance();

    String? bestIcao;
    double bestDist = double.infinity;

    for (final entry in _airportCoords.entries) {
      final d = distance(pos, entry.value);
      if (d < bestDist) {
        bestDist = d;
        bestIcao = entry.key;
      }
    }

    return bestDist <= maxDistMeters ? bestIcao : null;
  }

  Widget _buildToggleChip(
    String label,
    bool active,
    VoidCallback onTap,
    bool isMobile,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color:
              active
                  ? Colors.blueAccent.withOpacity(isMobile ? 0.20 : 0.25)
                  : Colors.grey.withOpacity(isMobile ? 0.15 : 0.20),
          borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
          border: Border.all(
            color: active ? Colors.blueAccent : Colors.grey,
            width: isMobile ? 1.0 : 1.3,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 14,
            fontWeight: FontWeight.w600,
            color: active ? Colors.blueAccent : Colors.grey[300],
          ),
        ),
      ),
    );
  }

  AirportCategory categorizeAirport(Airport ap) {
    final code = ap.icao.toUpperCase().trim();
    final len = code.length;

    // HELIPORTS
    if (len == 5) return AirportCategory.heli;
    if (code.startsWith("H")) return AirportCategory.heli;

    // NORMAL AIRPORTS
    if (len == 4) return AirportCategory.airport;

    return AirportCategory.unknown;
  }

  List<LatLng> _buildCustomRoute() {
    final f = _currentFlight;
    if (f == null) return const [];

    final List<LatLng> points = [];

    // -----------------------------
    // ORIGIN
    // -----------------------------
    if (f.originLat != null && f.originLng != null) {
      points.add(LatLng(f.originLat!, f.originLng!));
    }

    // -----------------------------
    // WAYPOINTS (typed, safe)
    // -----------------------------
    final wp = f.waypoints;
    if (wp != null && wp.isNotEmpty) {
      for (final Waypoint w in wp) {
        points.add(LatLng(w.lat, w.lon));
      }
    }

    // -----------------------------
    // DESTINATION
    // -----------------------------
    if (f.destinationLat != null && f.destinationLng != null) {
      points.add(LatLng(f.destinationLat!, f.destinationLng!));
    }

    return points;
  }

  bool _isDirectRoute() {
    return _currentFlight?.waypoints == null ||
        _currentFlight!.waypoints!.isEmpty;
  }

  Widget _buildFilterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFilterPanel(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(
          children: [
            Icon(Icons.tune, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Text("Filters", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _openFilterPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildToggleChip("Waypoints", _showWaypoints, () {
                setState(() => _showWaypoints = !_showWaypoints);
                _throttledUpdateWaypointMarkers(force: true);
              }, false),

              _buildToggleChip("NDB", _showNDB, () {
                setState(() => _showNDB = !_showNDB);
                _throttledUpdateNdbMarkers(force: true);
              }, false),

              _buildToggleChip("Normal", _filterBig, () {
                setState(() => _filterBig = !_filterBig);
                _throttledUpdateAirportMarkers(force: true);
              }, false),

              _buildToggleChip("Heli", _filterHeli, () {
                setState(() => _filterHeli = !_filterHeli);
                _throttledUpdateAirportMarkers(force: true);
              }, false),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finalizeAndUploadFlight() async {
    if (!_inFlight) return;

    final prefs = await SharedPreferences.getInstance();
    _endTime = DateTime.now();

    if (!_flightQualified) {
      debugPrint("🛑 Flight ended but NEVER QUALIFIED — discarding");

      await _cleanupFlight(prefs);
      return;
    }

    // ============================================================
    // 🛑 BASIC VALIDATION (ONLY THIS STAYS)
    // ============================================================
    if (_startTime == null) {
      await _cleanupFlight(prefs);
      return;
    }

    // ============================================================
    // 📊 RAW FLIGHT STATS (NO REJECTION)
    // ============================================================

    DistanceTracker.stop();
    final distanceNm = DistanceTracker.getNm();
    final flightDuration = _endTime!.difference(_startTime!).inMinutes;

    print(
      '[SkyCase] FINALIZE | distanceNm=$distanceNm | '
      'duration=$flightDuration | maxAlt=$_maxAltitude',
    );

    // ============================================================
    // 🧭 DERIVE FLIGHT TYPE
    // ============================================================
    final jobId = prefs.getString('flight_job_id');
    final flightType = jobId != null ? 'job' : 'free';

    // ============================================================
    // 📍 FINAL POSITION
    // ============================================================
    final LatLng? endLatLng = _trail.isNotEmpty ? _trail.last : currentLatLng;

    // ============================================================
    // 🛬 APPLY LANDING SNAPSHOT (IF AVAILABLE)
    // ============================================================
    _runwayUsedArrival = _landingSnapshot?.runway;

    // ============================================================
    // 🅿️ END PARKING DETECTION (SHUTDOWN-BASED)
    // ============================================================
    _parkingEnd = null;

    if (simData != null &&
        _landingSnapshot != null &&
        _canDetectParking(simData!)) {
      final endPos = LatLng(simData!.latitude, simData!.longitude);

      _parkingEnd = detectParkingSpot(
        endPos,
        icao: _landingSnapshot!.icao ?? '',
        requireFullyParked: true,
        maxDistanceMeters: 600, // relaxed for END
      );
    }

    print('[SkyCase] ✈️ Arrival Runway: ${_runwayUsedArrival ?? 'NONE'}');
    print('[SkyCase] 🅿️ Parking Spot: ${_parkingEnd ?? 'NONE'}');

    // ============================================================
    // 🔒 FINALIZE FLIGHT STATE (HARD STOP)
    // ============================================================
    _inFlight = false;
    _flightSessionActive = false;
    await prefs.setBool('in_flight', false);

    _pulseController.stop();
    DistanceTracker.stop();

    // ============================================================
    // 🧮 CALCULATIONS
    // ============================================================
    final userId = prefs.getString('user_id') ?? '';

    final avgAirspeed =
        _airspeedSamples > 0 ? (_airspeedSum / _airspeedSamples) : 0;

    final startLoc = _toAirportLocation(
      _startPoint,
    )?.copyWith(runway: _runwayUsedDeparture, parking: _parkingStart);

    final endLoc = _toAirportLocation(
      endLatLng,
    )?.copyWith(runway: _runwayUsedArrival, parking: _parkingEnd);

    final finalDistanceNm =
        distanceNm < 1.0
            ? double.parse(distanceNm.toStringAsFixed(4))
            : distanceNm;

    final turbCounts = {
      'light': _turbulenceEvents.where((e) => e.severity == 'light').length,
      'moderate':
          _turbulenceEvents.where((e) => e.severity == 'moderate').length,
      'severe': _turbulenceEvents.where((e) => e.severity == 'severe').length,
    };

    // ============================================================
    // 📝 BUILD LOG (NO FILTERING)
    // ============================================================
    final log = FlightLog(
      userId: userId,
      aircraft: simData?.title ?? 'Unknown',
      startTime: _startTime!,
      endTime: _endTime!,
      duration: flightDuration,
      startLocation: startLoc,
      endLocation: endLoc,
      distanceFlown: finalDistanceNm,
      avgAirspeed: avgAirspeed.round(),
      maxAltitude: _maxAltitude.round(),
      cruiseTime: _cruiseDuration.inMinutes,
      turbulence: List.from(_turbulenceEvents),
      events: {'turbulenceCount': turbCounts},
      trail: _backendTrail.map((e) => FlightTrailPoint.fromJson(e)).toList(),
      type: flightType,
      jobId: jobId,
    );

    print('[DEBUG] endLoc.toJson() = ${endLoc?.toJson()}');
    print('[DEBUG] log.endLocation?.parking = ${log.endLocation?.parking}');
    print('[SkyCase] 📤 Uploading log:');
    print(jsonEncode(log.toJson()));

    // ============================================================
// 🚀 UPLOAD
// ============================================================
if (endLoc?.icao.isNotEmpty == true) {
  await prefs.setString('last_destination_icao', endLoc!.icao);
}

// 1️⃣ Upload flight log FIRST
final newFlightId = await FlightLogService.uploadFlightLog(log);

// 2️⃣ Only if upload succeeded → add hours
if (newFlightId != null) {
  final aircraftUuid = prefs.getString("current_aircraft_uuid");

  if (aircraftUuid != null && flightDuration > 0) {
    await AircraftService.addHours(
      aircraftUuid: aircraftUuid,
      minutes: flightDuration,
    );

    print("⏱️ Added $flightDuration min to aircraft $aircraftUuid");
  }
}

    // ============================================================
    // 🎯 COMPLETE JOB (IF ANY)
    // ============================================================
    if (jobId != null) {
      await DispatchService.completeJob(jobId, userId);

      showHudMessage(
        "🛬 Arrived at ${_landingSnapshot?.icao ?? 'destination'}",
      );

      await Future.delayed(const Duration(seconds: 1));
      showHudMessage("🎉 Dispatch Job Completed!");
    }

    // ============================================================
    // 🧾 UI + STATS
    // ============================================================
    if (newFlightId != null && mounted) {
      await _showFlightSummaryDialog(log, startLoc, endLoc);
    }

    final token = prefs.getString('auth_token');
    if (token != null) {
      await UserService(
        baseUrl: 'http://38.242.241.46:3000',
      ).updateStats(token, log.duration);
    }

    // ============================================================
    // 🧹 CLEANUP
    // ============================================================
    await _cleanupFlight(prefs);
  }

  GroundPhase _computePhase(SimLinkData d) {
    // 1️⃣ Airborne always wins
    if (!d.onGround) return GroundPhase.airborne;

    // 2️⃣ Runway always roll (critical)
    if (d.onRunway) return GroundPhase.roll;

    // 3️⃣ PARKED = parking brake ON
    if (d.parkingBrake) return GroundPhase.parked;

    // 4️⃣ Taxi = brakes released + movement
    if (d.airspeed > 2.0) return GroundPhase.taxi;

    // 5️⃣ Fallback
    return GroundPhase.parked;
  }

  String _phaseLabel(GroundPhase p) {
    switch (p) {
      case GroundPhase.parked:
        return "PARKED";
      case GroundPhase.taxi:
        return "TAXI";
      case GroundPhase.roll:
        return "ROLL";
      case GroundPhase.airborne:
        return "AIRBORNE";
    }
  }

  bool _canDetectParking(SimLinkData d) {
    return d.onGround && d.airspeed < 2.0 && d.parkingBrake && !d.combustion;
  }

  String? detectParkingSpot(
    LatLng position, {
    required String icao,
    bool requireFullyParked = false,
    double maxDistanceMeters = 350,
  }) {
    if (_parkingSpots.isEmpty) return null;

    if (requireFullyParked &&
        (simData == null || !_canDetectParking(simData!))) {
      print("🅿️ Parking detection blocked — aircraft not fully parked");
      return null;
    }

    const distance = Distance();

    ParkingSpot? nearest;
    double nearestDistance = double.infinity;

    for (final p in _parkingSpots) {
      if (p.icao != icao) continue;

      final d = distance(position, LatLng(p.lat, p.lon));

      if (d < nearestDistance) {
        nearestDistance = d;
        nearest = p;
      }
    }

    if (nearest == null || nearestDistance > maxDistanceMeters) {
      print(
        "🅿️ No parking spot close enough at $icao "
        "(nearest ${nearestDistance.toStringAsFixed(1)}m)",
      );
      return null;
    }

    final label = "${nearest.name}${nearest.number}";

    print(
      "🅿️ Parking locked → $label "
      "(${nearestDistance.toStringAsFixed(1)}m)",
    );

    return label;
  }

  double _zoomToNm(double zoom, double lat) {
    final metersPerPixel = 156543.03392 * cos(lat * pi / 180) / pow(2, zoom);

    const referencePixels = 100;
    final meters = metersPerPixel * referencePixels;

    return meters / 1852; // meters → NM
  }

  String _buildFlightBannerText() {
    final f = _currentFlight!;
    final wp = f.waypoints;

    final baseInfo =
        '📏 ${f.estimatedDistanceNm.toStringAsFixed(1)} NM\n'
        '⏱️ ${formatEta(f.estimatedTime.inMinutes)}\n'
        '🌤 Cruise: ${f.cruiseAltitude} ft';

    // -------------------------------
    // DIRECT ROUTE
    // -------------------------------
    if (wp == null || wp.isEmpty) {
      return '🧭 ${f.originIcao} → ${f.destinationIcao}\n$baseInfo';
    }

    // -------------------------------
    // CUSTOM ROUTE (exclude first & last)
    // -------------------------------
    final List<Waypoint> mids =
        wp.length > 2 ? wp.sublist(1, wp.length - 1) : const [];

    final routeStr = mids
        .map((w) => w.ident.isNotEmpty ? w.ident : (w.name ?? "?"))
        .join(" → ");

    return routeStr.isEmpty
        ? '🧭 ${f.originIcao} → ${f.destinationIcao}\n$baseInfo'
        : '🧭 ${f.originIcao} → $routeStr → ${f.destinationIcao}\n$baseInfo';
  }

  List<Waypoint> _getFlightWaypoints() {
    final raw = _currentFlight?.waypoints;
    if (raw == null || raw.isEmpty) return const [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(Waypoint.fromJson)
        .toList();
  }

  Widget _radioHud(SimLinkData d) {
    final avionics = d.avionicsOn;
    final tx = d.transmitting;

    return Opacity(
      opacity: avionics ? 1.0 : 0.35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "COM1",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              formatComFrequency(d.com1Active),
              style: const TextStyle(
                color: Color.fromARGB(255, 24, 255, 236),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (tx && avionics) ...[const SizedBox(width: 6), _txBlink()],
          ],
        ),
      ),
    );
  }

  String formatComFrequency(double raw) {
    if (raw <= 0) return "---.---";

    double mhz;

    if (raw > 1e9) {
      // e.g. 1248500000 → 124.850
      mhz = raw / 1e7;
    } else if (raw > 1e8) {
      // e.g. 124850000 → 124.850
      mhz = raw / 1e6;
    } else {
      // already MHz or weird aircraft
      mhz = raw;
    }

    return mhz.toStringAsFixed(3);
  }

  Widget _txBlink() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      builder: (_, v, __) {
        return Opacity(
          opacity: v,
          child: const Text(
            "TX",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        );
      },
    );
  }

  List<LatLng> buildDottedLine(
    LatLng start,
    LatLng end, {
    double dotSpacingMeters = 400, // distance between dots
  }) {
    final distance = const Distance();
    final totalMeters = distance(start, end);

    if (totalMeters <= dotSpacingMeters) {
      return [start, end];
    }

    final bearing = distance.bearing(start, end);
    final List<LatLng> dots = [];

    for (double d = 0; d <= totalMeters; d += dotSpacingMeters) {
      dots.add(distance.offset(start, d, bearing));
    }

    return dots;
  }

  void _qualifyFlightIfNeeded(SimLinkData data) {
    final alt = data.altitude;
    final spd = data.airspeed;

    final airborneAlt = isHelicopter ? 30 : 120;
    final airborneSpeed = isHelicopter ? 5 : 45;

    if (!_flightQualified &&
        !data.onGround &&
        alt > airborneAlt &&
        spd > airborneSpeed) {
      _flightQualified = true;
      _takeoffTimestamp ??= DateTime.now();

      debugPrint("✅ Flight QUALIFIED (${isHelicopter ? 'HELI' : 'FIXED'})");
    }
  }

  bool get helicopterHasWheels {
    if (!isHelicopter) return false;

    final title = simData?.title.toLowerCase() ?? "";

    // Helicopters known to have wheels
    return title.contains("black hawk") ||
        title.contains("blackhawk") ||
        title.contains("uh-60") ||
        title.contains("uh60") ||
        title.contains("ch-47") ||
        title.contains("chinook") ||
        title.contains("aw139") ||
        title.contains("aw169");
  }
}
