import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:skycase/models/airport.dart';
import 'package:skycase/models/airport_frequencies.dart';
import 'package:skycase/models/airport_location.dart';
import 'package:skycase/models/airway_segment.dart';
import 'package:skycase/models/flight.dart';
import 'package:skycase/models/flight_info.dart';
import 'package:skycase/models/flight_log.dart';
import 'package:skycase/models/flight_trail_point.dart';
import 'package:skycase/models/ground_phase.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/models/ndb.dart';
import 'package:skycase/models/open_sky_aircraft.dart';
import 'package:skycase/models/parking.dart';
import 'package:skycase/models/poi.dart';
import 'package:skycase/models/runways.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/models/taxiway_label.dart';
import 'package:skycase/models/taxiway_segment.dart';
import 'package:skycase/models/turbulence_event.dart';
import 'package:skycase/models/vors.dart';
import 'package:skycase/models/waypoints.dart';
import 'package:skycase/providers/auto_flight_provider.dart';
import 'package:skycase/providers/auto_simlink_provider.dart';
import 'package:skycase/providers/deep_zoom_provider.dart';
import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/screens/ground_ops/ground_ops_screen.dart';
import 'package:skycase/services/aircraft_service.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/distance_tracker.dart';
import 'package:skycase/services/flight_log_service.dart';
import 'package:skycase/services/flight_plan_service.dart';
import 'package:skycase/services/ground_service.dart';
import 'package:skycase/services/metar_service.dart';
import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/utils/airport_details_repository.dart';
import 'package:skycase/utils/airport_repository.dart';
import 'package:skycase/utils/airway_repository.dart';
import 'package:skycase/utils/cockpit_vibration.dart';
import 'package:skycase/utils/global_poi.dart';
import 'package:skycase/utils/nav_repository.dart';
import 'package:skycase/utils/navigraph_prefs.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/utils/waypoint_repository.dart';
import 'package:skycase/widgets/aircraft_marker_icon.dart';
import 'package:skycase/widgets/deep_zoom_grid_layer.dart';
import 'package:skycase/widgets/map_overlay.dart';
import 'package:skycase/widgets/map_tile_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skycase/widgets/navigraph_view.dart' show NavigraphWebview;
import 'package:skycase/widgets/ndb_marker_painter.dart';
import 'package:skycase/widgets/vor_marker_painter.dart';
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

class LandingReplaySample {
  final double lat;
  final double lng;
  final double heading;
  final double airspeed;
  final double altitude;
  final double verticalSpeed;
  final bool onGround;
  final DateTime timestamp;

  LandingReplaySample({
    required this.lat,
    required this.lng,
    required this.heading,
    required this.airspeed,
    required this.altitude,
    required this.verticalSpeed,
    required this.onGround,
    required this.timestamp,
  });

  Landing2dSample toLanding2dSample() {
    return Landing2dSample(
      lat: lat,
      lng: lng,
      heading: heading,
      airspeed: airspeed,
      altitude: altitude,
      verticalSpeed: verticalSpeed,
      onGround: onGround,
      timestamp: timestamp,
    );
  }
}

class LiveMapVisuals {
  final List<Polyline> trailPolylines;
  final List<Polyline> headingBugPolylines;
  final List<Marker> markers;

  const LiveMapVisuals({
    required this.trailPolylines,
    required this.headingBugPolylines,
    required this.markers,
  });

  const LiveMapVisuals.empty()
    : trailPolylines = const [],
      headingBugPolylines = const [],
      markers = const [];
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

  static const double _lastRealTileZoom = 10.0;

  static const List<MapTileOption> tileLayers = [
    MapTileOption(
      name: 'SkyCase Dark',
      url: 'http://38.242.241.46:8080/styles/skycase-dark/{z}/{x}/{y}.png',
      subdomains: [],
      mapBackgroundColor: Color(0xFF08121C),
      fallbackGridColor: Color(0xFF5FA8D3),
      fallbackCrossColor: Color(0xFF7FC4E8),
    ),
    MapTileOption(
      name: 'SkyCase Light',
      url: 'http://38.242.241.46:8080/styles/skycase-light/{z}/{x}/{y}.png',
      subdomains: [],
      mapBackgroundColor: Color(0xFFEAF2F8),
      fallbackGridColor: Color(0xFF7EA4C2),
      fallbackCrossColor: Color(0xFF9BB9D1),
    ),
  ];

  DateTime? _startTime;
  DateTime? _endTime;
  double _maxAltitude = 0.0;
  double _airspeedSum = 0.0;
  int _airspeedSamples = 0;
  Duration _cruiseDuration = Duration.zero;
  DateTime? _lastCruiseStart;

  DateTime? _lastSocketData;
  Timer? _reconnectTimer;
  final Stopwatch _connectionTimer = Stopwatch();
  LatLng? _initialCenter;

  final ValueNotifier<List<Marker>> _airportMarkersNotifier =
      ValueNotifier<List<Marker>>([]);
  Timer? _airportUpdateThrottle;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _initialCenterReady = false;

  double _mapRotation = 0.0;

  List<Map<String, dynamic>> _backendTrail = [];
  DateTime? _lastBackendTrailUpdate;
  final List<LandingReplaySample> _landingReplayBuffer = [];
  final List<LandingReplaySample> _landingReplayFinal = [];
  bool _recordLandingRollout = false;
  DateTime? _touchdownTime;
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

  String? _lastPushedJobPhase;
  DateTime? _lastPhasePushTime;

  bool _showPoi = false;

  double _infoCardTop = 110;
  double _infoCardLeft = 0;
  bool _infoCardInitialized = false;

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
  bool _userTouchingMap = false;
  Timer? _touchReleaseTimer;
  bool _isFinalizingFlight = false;
  Poi? _selectedPoi;

  bool _showSideMenu = false;

  dynamic _selectedMapObject;
  String? _selectedMapObjectType; // 'vor' | 'ndb' | 'parking' | 'waypoint'

  Poi? _nearbyPoiAlert;
  DateTime? _lastPoiAlertTime;
  final Map<String, DateTime> _dismissedPoiAlerts = {};

  static const double _poiAlertRangeNm = 15.0;
  static const Duration _poiAlertCooldown = Duration(minutes: 3);

  Poi? _activePoiTarget;
  DateTime? _poiInsideSince;
  bool _poiReached = false;

  static const double _poiReachRadiusNm = 1.5;

  final Set<String> _confirmedPoiNames = {};

  Duration get _requiredPoiHoldTime =>
      isHelicopter ? const Duration(seconds: 20) : const Duration(seconds: 10);

  Timer? _groundOverlayThrottle;

  // =============== AIRWAY STATE ===============
  List<AirwaySegment> _airways = [];
  final ValueNotifier<List<Polyline>> _airwayPolylinesNotifier =
      ValueNotifier<List<Polyline>>([]);
  Timer? _airwayThrottle;
  double? _lastAirwayZoom;
  LatLngBounds? _lastAirwayBounds;
  bool _showAirways = false;
  final ValueNotifier<List<Marker>> _airwayLabelsNotifier =
      ValueNotifier<List<Marker>>([]);

  final ValueNotifier<List<Marker>> _parkingMarkersNotifier =
      ValueNotifier<List<Marker>>([]);

  final ValueNotifier<List<Marker>> _vorMarkersNotifier =
      ValueNotifier<List<Marker>>([]);

  final ValueNotifier<List<Marker>> _ndbMarkersNotifier =
      ValueNotifier<List<Marker>>([]);

  final ValueNotifier<List<Marker>> _waypointMarkersNotifier =
      ValueNotifier<List<Marker>>([]);

  final ValueNotifier<LiveMapVisuals> _liveMapVisualsNotifier =
      ValueNotifier<LiveMapVisuals>(const LiveMapVisuals.empty());

  String? _cinematicHudMessage;
  IconData? _cinematicHudIcon;
  Color _cinematicHudAccent = Colors.cyanAccent;
  Timer? _cinematicHudTimer;

  late final AnimationController _hudFxController;

  late AnimationController _aircraftSpinController;

  static const double kTileFadeCutoffZoom = 10.8;

  LatLng? _endCheckStartPos;
  DateTime? _endCheckSince;
  DateTime? _endFlightLostSince;

  @override
  void initState() {
    super.initState();
    _connectionTimer.start();

    // 1️⃣ Restore UI shell first
_loadUiShellState();

// 2️⃣ Restore runtime flight snapshot
_loadInFlight();

// 3️⃣ StartPoint + Trail
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
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
      if (_mapReady &&
          _followAircraft &&
          !_userTouchingMap &&
          simData != null) {
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
        _throttledUpdateAirportMarkers();
        _throttledUpdateAirways();
        _throttledUpdateParkingMarkers();
        _throttledUpdateVorMarkers();
        _throttledUpdateNdbMarkers();
        _throttledUpdateWaypointMarkers();
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

    _fadeController.removeListener(_refreshLiveMapVisuals);

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

    _hudFxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _aircraftSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
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
    final cruise = _currentFlight!.cruiseAltitude;
    return simData!.altitude >= cruise - 200 &&
        simData!.altitude <= cruise + 300;
  }

  double _buildAircraftRotationAngle() {
    final s = simData;
    if (s == null) return 0.0;

    final double airspeed = s.airspeed;
    final double heading = s.heading;

    // Helicopter hovering → north-up
    if (isHelicopter && airspeed < 20) return 0.0;

    final normalized = (heading % 360 + 360) % 360;
    return normalized * (pi / 180);
  }

  void _refreshLiveMapVisuals() {
    final List<Polyline> trailPolylines = [];
    final List<Polyline> headingBugPolylines = [];
    final List<Marker> markers = [];

    // --------------------------------------------------
    // Trail
    // --------------------------------------------------
    if (_trail.length > 1) {
      trailPolylines.add(
        Polyline(
          points: List<LatLng>.from(_trail),
          strokeWidth: 4.0,
          color: _getTrailColor(simData?.altitude ?? 0),
        ),
      );
    }

    // --------------------------------------------------
    // Heading bug dotted line
    // --------------------------------------------------
    if (_aircraftLatLng != null && _headingBugTarget != null) {
      final dots = buildDottedLine(
        _aircraftLatLng!,
        _headingBugTarget!,
        dotSpacingMeters: 350,
      );

      for (int i = 0; i < dots.length - 1; i += 2) {
        headingBugPolylines.add(
          Polyline(
            points: [dots[i], dots[i + 1]],
            color: Colors.cyanAccent.withOpacity(_fadeAnimation.value),
            strokeWidth: 2.5,
          ),
        );
      }
    }

    // --------------------------------------------------
    // Aircraft marker
    // --------------------------------------------------
    if (simData != null) {
      markers.add(
        Marker(
          width: 44,
          height: 44,
          point: LatLng(simData!.latitude, simData!.longitude),
          child: AnimatedBuilder(
            animation: _aircraftSpinController,
            builder: (context, _) {
              return AircraftMarkerIcon(
                data: simData!,
                rotationAngle: _buildAircraftRotationAngle(),
                spinPhase: _aircraftSpinController.value,
                color: _getMarkerColor(tileLayers[_mapStyleIndex].name),
                size: 44,
              );
            },
          ),
        ),
      );
    }

    // --------------------------------------------------
    // Home base marker
    // --------------------------------------------------
    if (_homeBase != null) {
      markers.add(
        Marker(
          point: _homeBase!,
          width: 30,
          height: 30,
          child: IgnorePointer(
            ignoring: true,
            child: Tooltip(
              message: 'Home Base',
              child: Icon(
                Icons.home,
                color: Colors.blueAccent,
                size: 28,
                shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
              ),
            ),
          ),
        ),
      );
    }

    // --------------------------------------------------
    // Last destination marker
    // --------------------------------------------------
    if (_lastFlightDestination != null) {
      markers.add(
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
              shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
            ),
          ),
        ),
      );
    }

    // --------------------------------------------------
    // Turbulence markers
    // --------------------------------------------------
    for (final event in _turbulenceEvents) {
      markers.add(
        Marker(
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
      );
    }

    // --------------------------------------------------
    // Flight history markers
    // --------------------------------------------------
    if (_showAllFlights) {
      markers.addAll(_buildFlightHistoryMarkers());
    }

    _liveMapVisualsNotifier.value = LiveMapVisuals(
      trailPolylines: trailPolylines,
      headingBugPolylines: headingBugPolylines,
      markers: markers,
    );
  }

  /// Handle incoming real-time sim data
  void _handleSimUpdate(SimLinkData data) async {
    if (!mounted) return;
    // debugPrint(
    //   "BATTERY CHECK | mission.battery=${data.mission.battery} | volts=${data.mainBusVolts} | avionics=${data.avionicsOn} | combustion=${data.combustion}",
    // );
    _updateNearbyPoiAlert();
    _updatePoiProximityTimer();
    final now = DateTime.now();
    final latlng = LatLng(data.latitude, data.longitude);

    _lastSocketData = now;

    // -------------------------------------------------------
    // SETTINGS / POWER / BASIC STATE
    // -------------------------------------------------------
    if (!_settingsLoaded) return;

    final double volts = data.mainBusVolts;
    final bool avionics = data.avionicsOn;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (volts > 7 && avionics) {
        KeepScreenOn.turnOn();
      } else {
        KeepScreenOn.turnOff();
      }
    }

    _qualifyFlightIfNeeded(data);

    // -------------------------------------------------------
    // INITIAL GROUND STATE
    // -------------------------------------------------------
    _isGrounded ??= data.onGround;

    // -------------------------------------------------------
    // MID-AIR ATTACH
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
      _flightQualified = true;

      await prefs.setBool('in_flight', true);
      await _saveFlightRuntimeSnapshot();

      _livePhase = GroundPhase.airborne;
      _lastAnnouncedPhase = GroundPhase.airborne;
      await CockpitVibration.onPhaseChange(GroundPhase.airborne);

      _pendingPhase = null;
      _pendingPhaseSince = null;
    }

    // -------------------------------------------------------
    // PHASE UPDATE (STRICT / MEANINGFUL ONLY)
    // -------------------------------------------------------
    final GroundPhase? rawPhase = _computePhase(data);
    await _updateMeaningfulPhase(data, rawPhase, now);

    // -------------------------------------------------------
    // RUNWAY ALIGNMENT DETECTION
    // Only if we're active and not already airborne/final parked
    // -------------------------------------------------------
    final bool runwayLike =
        data.onGround &&
        data.airspeed < 15 &&
        rawPhase != null &&
        rawPhase != GroundPhase.parked;

    if (_inFlight && _runwayUsedDeparture == 'N/A' && runwayLike) {
      final heading = data.heading;

      if (_lastHeadingForRunway == null ||
          (heading - _lastHeadingForRunway!).abs() > 5) {
        _lastHeadingForRunway = heading;
        _headingStableSince = now;
      } else {
        final stableSeconds =
            now.difference(_headingStableSince ?? now).inMilliseconds / 1000.0;

        if (stableSeconds >= 2.0) {
          final rwy = _detectRunwayStrict(latlng);

          if (rwy != null) {
            _runwayUsedDeparture = rwy;
          }
        }
      }
    }

    // -------------------------------------------------------
    // RUNWAY EXIT DETECTION
    // -------------------------------------------------------
    if (_runwayPhaseLatched) {
      final bool exitedRunway =
          !data.onRunway && data.onGround && data.airspeed < 40;

      if (exitedRunway) {
        _runwayPhaseLatched = false;
      }
    }

    // -------------------------------------------------------
    // RUNWAY LOCK
    // -------------------------------------------------------
    if (data.onRunway && data.airspeed > 30) {
      _runwayLock = true;
      _runwayExitCandidate = null;
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

    // -------------------------------------------------------
    // TOC AUTO-HIDE
    // -------------------------------------------------------
    if (_tocPoint != null) {
      if (atCruiseAltitude ||
          (simData != null &&
              _currentFlight != null &&
              simData!.altitude > _currentFlight!.cruiseAltitude)) {
        _tocPoint = null;
      }
    }

    // -------------------------------------------------------
    // TOD AUTO-HIDE
    // -------------------------------------------------------
    if (_todPoint != null) {
      if (!atCruiseAltitude) _todPoint = null;
      if (isDescending) _todPoint = null;
      if (_remainingNm < _todDistanceNm) _todPoint = null;
    }

    // -------------------------------------------------------
    // HEADING BUG FADE
    // -------------------------------------------------------
    final headingBug = data.autopilot.headingBug;
    if (_lastHeadingBug == null || _lastHeadingBug != headingBug) {
      _lastHeadingBug = headingBug;
      _fadeController.reset();
      _headingFadeTimer?.cancel();
      _headingFadeTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) _fadeController.forward();
      });
    }

    // -------------------------------------------------------
    // TOC / TOD DISTANCES
    // NOTE: use current packet, not old simData snapshot
    // -------------------------------------------------------
    if (_currentFlight != null) {
      final selectedAlt = data.autopilot.altitudeTarget;

      if (data.verticalSpeed > 200 && data.altitude < selectedAlt - 100) {
        _tocDistanceNm = calculateTOCDistanceNm();
      } else {
        _tocDistanceNm = 0;
      }

      final destElev =
          _currentFlight!.destinationLat != null
              ? (_destinationElevationFt ?? 0)
              : 0;

      if (_cruiseConfirmed && data.altitude >= selectedAlt - 100) {
        _todDistanceNm = calculateTODDistanceNm(destElev);
      } else {
        _todDistanceNm = 0;
      }
    }

    // -------------------------------------------------------
    // UPDATE AIRCRAFT STATE
    // -------------------------------------------------------
    _aircraftLatLng = latlng;
    _aircraftHeading = data.heading;
    _headingBugTarget = _computeTargetFromHeading(latlng, headingBug, 30.0);

    _refreshLiveMapVisuals();

    // -------------------------------------------------------
    // TAKEOFF DETECTION (EVENT)
    // -------------------------------------------------------
    if (_isGrounded == true && data.onGround == false) {
      await _handleTakeoffEvent(data: data, now: now);
    }

    // -------------------------------------------------------
    // AUTO START (taxi out)
    // -------------------------------------------------------
    if (_autoFlightEnabled && !_flightSessionActive) {
      final bool shouldStart =
          data.onGround && data.combustion && data.airspeed > 8;

      if (shouldStart) {
        _flightSessionActive = true;
        _inFlight = true;
        _takeoffTimestamp = now;
        _finalParkedAnnounced = false;

        final prefs = await SharedPreferences.getInstance();
        await DistanceTracker.reset();
        DistanceTracker.start();
        await prefs.setBool('in_flight', true);
        await _saveFlightRuntimeSnapshot();

        _startFlight();
      }
    }

    // -------------------------------------------------------
    // REAL GA FUEL CALCULATION
    // -------------------------------------------------------
    _fuelGallons = data.fuelGallons;

    final double gph = _estimateFuelFlow();

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

    _captureLandingReplaySample(data, now);

    // -------------------------------------------------------
    // LANDING DETECTION (EVENT)
    // -------------------------------------------------------
    if (_isGrounded == false && data.onGround == true) {
      await _handleLandingEvent(
        data: data,
        latlng: latlng,
        now: now,
        isHelicopter: isHelicopter,
        helicopterHasWheels: helicopterHasWheels,
      );
    }
    // -------------------------------------------------------
    // AUTO END (REAL FINAL PARKING ONLY)
    // supports grass/dirt/gravel strips without parking
    // reuses existing runway detection
    // -------------------------------------------------------
    if (_autoFlightEnabled &&
        _flightSessionActive &&
        _startPoint != null &&
        !_isFinalizingFlight) {
      final bool stableStopped = _isStableStopped(data, latlng);

      final detectedIdent = _detectRunwayStrict(latlng);
      final matchedRunway = _getRunwayByIdent(detectedIdent);
      final surface = matchedRunway?.surface.trim().toUpperCase() ?? '';

      final bool softField =
          surface == 'G' || surface == 'D' || surface == 'GR';

      final bool runwayUnsafe =
          !softField && !isHelicopter && data.onRunway && data.airspeed < 20;

      String? parkingHere;
      final airportIcao = _toAirportLocation(latlng)?.icao;
      if (airportIcao != null) {
        parkingHere = detectParkingSpot(
          latlng,
          icao: airportIcao,
          requireFullyParked: true,
        );
      }

      final bool validParking = parkingHere != null;
      final bool parkingBrakeHelps = data.parkingBrake;

      final bool enoughTimeAfterTouchdown =
          _touchdownTime == null ||
          now.difference(_touchdownTime!).inSeconds >= 20;

      final bool shouldFinalize =
          stableStopped &&
          enoughTimeAfterTouchdown &&
          (softField || !runwayUnsafe) &&
          (validParking || parkingBrakeHelps || softField || isHelicopter);

      if (shouldFinalize) {
        _endFlightLostSince = null;
        _pendingFlightEnd = true;
        _pendingEndTime ??= now;

        await _saveFlightRuntimeSnapshot();

        final stableFor = now.difference(_pendingEndTime!).inSeconds;

        if (stableFor >= 12) {
          if (!_finalParkedAnnounced) {
            _finalParkedAnnounced = true;
            await CockpitVibration.onPhaseChange(GroundPhase.parked);
          }

          _isFinalizingFlight = true;

          try {
            final didSave = await _finalizeAndUploadFlight();

            if (didSave) {
              _pendingFlightEnd = false;
              _pendingEndTime = null;
              _endFlightLostSince = null;
              _endCheckStartPos = null;
              _endCheckSince = null;
              _inFlight = false;
              _flightSessionActive = false;
                await _clearFlightRuntimeSnapshot();
            } else {
              _pendingFlightEnd = false;
              _pendingEndTime = null;
              _endFlightLostSince = null;
            }
          } finally {
            _isFinalizingFlight = false;
          }
        }
      } else {
        _endFlightLostSince ??= now;

        final lostFor = now.difference(_endFlightLostSince!).inSeconds;
        if (lostFor >= 4) {
          _pendingFlightEnd = false;
          _pendingEndTime = null;
          _finalParkedAnnounced = false;
          _endFlightLostSince = null;
        }
      }
    }
    // -------------------------------------------------------
    // JOB PHASE ENGINE
    // -------------------------------------------------------
    final gsx = data.gsx;

    if (gsx.availableInSim && gsx.boarding) {
      await _pushJobPhase('loading');
    } else if (gsx.availableInSim &&
        !gsx.boarding &&
        !gsx.refueling &&
        data.onGround &&
        data.parkingBrake &&
        data.combustion) {
      await _pushJobPhase('ready');
    }

    if (gsx.availableInSim && gsx.deboarding) {
      await _pushJobPhase('unloading');
    }

    // -------------------------------------------------------
    // UPDATE GROUND STATE LAST
    // -------------------------------------------------------
    _isGrounded = data.onGround;

    // -------------------------------------------------------
    // TURBULENCE
    // -------------------------------------------------------
    _handleTurbulenceDetection(data, now, latlng);

    // -------------------------------------------------------
    // TELEPORT / LAG DETECTION
    // -------------------------------------------------------
    final timeDelta =
        _lastFixTime != null ? now.difference(_lastFixTime!).inSeconds : 0;
    _lastFixTime = now;

    if (_inFlight && _trail.isNotEmpty) {
      final last = _trail.last;
      final distNm = _calculateDistanceNm(last, latlng);
      final distKm = distNm * 1.852;
      final isLegitMovement = data.airspeed > 40;

      if (distKm > 10 && timeDelta < 8 && !isLegitMovement) {
        return;
      }
    }

    // -------------------------------------------------------
    // DISTANCE TRACKER REFERENCE
    // -------------------------------------------------------
    if (_inFlight && _lastDistancePoint == null) {
      _lastDistancePoint = latlng;
    }

    // -------------------------------------------------------
    // TRACK FLIGHT STATS
    // -------------------------------------------------------
    if (_inFlight) {
      await DistanceTracker.feed(latlng);
      _trackFlightStats(data, latlng, now);
    }

    // -------------------------------------------------------
    // FOLLOW-AIRCRAFT CAMERA
    // -------------------------------------------------------
    if (_followAircraft && _mapReady && !_userTouchingMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        try {
          mapController.move(latlng, mapController.camera.zoom);

          // Rotate whenever follow is active.
          // Only keep north-up for hovering helicopters if desired.
          if (!(isHelicopter && data.airspeed < 20)) {
            _animateRotation(data.heading);
          } else {
            mapController.rotate(0);
            _mapRotation = 0.0;
            _previousHeading = 0.0;
          }
        } catch (_) {}
      });
    }

    // -------------------------------------------------------
    // TRAIL (VISUAL)
    // -------------------------------------------------------
    if (_inFlight && !data.onGround) {
      final last = _trail.isNotEmpty ? _trail.last : null;
      final movedMeters =
          last == null ? 999.0 : _calculateDistanceNm(last, latlng) * 1852.0;

      if (movedMeters >= 1.0) {
        _trail.add(latlng);
_refreshLiveMapVisuals();
await _saveTrail(_trail);
await _saveFlightRuntimeSnapshot();
      }
    }

    // -------------------------------------------------------
    // BACKEND TRAIL
    // -------------------------------------------------------
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
              ? _calculateDistanceNm(lastBackend, latlng) * 1.852
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
        await _saveFlightRuntimeSnapshot();
      }
    }

    if (!mounted) return;

    // simData was already updated by the socket callback.
    // Do not force a second full rebuild here.
    simData = data;
    await _saveUiShellState();
await _saveFlightRuntimeSnapshot();
  }

  /// Rotate map smoothly based on heading
  void _animateRotation(double newHeading) {
    final target = -((newHeading % 360 + 360) % 360);

    double shortestDiff(double from, double to) {
      double diff = (to - from) % 360;

      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;

      return diff;
    }

    final diff = shortestDiff(_previousHeading, target);

    // Ignore tiny heading jitter
    if (diff.abs() < 1.0) return;

    _rotationAnimation = Tween<double>(
      begin: _previousHeading,
      end: _previousHeading + diff,
    ).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeOut),
    );

    _previousHeading = _previousHeading + diff;
    _rotationController.forward(from: 0);
  }

  @override
  void dispose() {
     _saveUiShellState();
  _saveFlightRuntimeSnapshot();
    _reconnectTimer?.cancel();
    _socketService.dispose();
    _heartbeatTimer?.cancel();
    _rotationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _engineVibrate.dispose();
    _powerFlickerCtrl.dispose();
    _groundLabelMarkersNotifier.dispose();
    _airportMarkersNotifier.dispose();
    _airwayPolylinesNotifier.dispose();
    _airwayLabelsNotifier.dispose();
    _parkingMarkersNotifier.dispose();
    _vorMarkersNotifier.dispose();
    _ndbMarkersNotifier.dispose();
    _waypointMarkersNotifier.dispose();
    _fadeController.addListener(_refreshLiveMapVisuals);
    _cinematicHudTimer?.cancel();
    _hudFxController.dispose();
    _parkingUpdateThrottle?.cancel();
    _aircraftSpinController.dispose();
    CockpitVibration.dispose();
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
  // Filter
  bool _showVOR = true;
  final Map<String, List<Vor>> _vorClusters = {};
  Timer? _vorUpdateThrottle;
  double? _lastVorZoom;
  LatLngBounds? _lastVorBounds;

  // NDBs
  List<Ndb> _ndbs = [];
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
  bool _showRunways = true; // toggle via UI
  List<Marker> _runwayMarkers = [];

  // =============== PARKING STATE ===============

  List<ParkingSpot> _parkings = [];
  Timer? _parkingUpdateThrottle;
  double? _lastParkingZoom;
  LatLngBounds? _lastParkingBounds;
  bool _showParking = true;

  // =============== WAYPOINT STATE ===============
  List<Waypoint> _waypoints = [];

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

  // =============== TAXIWAY STATE ===============
  List<TaxiwaySegment> _groundSegments = [];
  List<Polyline> _groundPolylines = [];
  bool _showGround = true;
  List<TaxiwayLabel> _groundLabels = [];
  final ValueNotifier<List<Marker>> _groundLabelMarkersNotifier =
      ValueNotifier<List<Marker>>([]);

  LatLng? _lastGroundQueryPoint;
  DateTime? _lastGroundQueryTime;
  bool _loadingGround = false;

  bool _filterBig = true;
  bool _filterHeli = false;

  LatLng? get currentLatLng =>
      simData != null ? LatLng(simData!.latitude, simData!.longitude) : null;

  bool _pendingFlightEnd = false;
  DateTime? _pendingEndTime;

  bool _runwayLock = false;
  DateTime? _runwayExitCandidate;

  GroundPhase? _lastAnnouncedPhase;
  bool _runwayPhaseLatched = false;

  GroundPhase? _livePhase;
  GroundPhase? _pendingPhase;
  DateTime? _pendingPhaseSince;
  DateTime? _lastLandedEventTime;
  bool _finalParkedAnnounced = false;
  double? _butterScore;
  double? _takeoffScore;
  double? _lastTouchdownVs;
  double? _lastTakeoffPitch;
  bool _hardLanding = false;
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

  List<FlightLog> _flightLogs = [];
  bool _showAllFlights = false;
  bool _loadingFlightLogs = false;
  String? _flightLogsUserId;
  final bool _showGroundLabels = true;
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

  Future<void> _pushJobPhase(String phase) async {
    final jobId = widget.jobId;
    if (jobId == null || jobId.isEmpty) return;

    final user = context.read<UserProvider>().user;
    if (user == null) return;

    if (_lastPushedJobPhase == phase) return;
    if (!_canTransitionToJobPhase(phase)) return;

    final now = DateTime.now();
    if (_lastPhasePushTime != null &&
        now.difference(_lastPhasePushTime!).inMilliseconds < 1200) {
      return;
    }

    try {
      final updated = await DispatchService.updatePhase(jobId, user.id, phase);

      if (updated != null) {
        _lastPushedJobPhase = updated.phase;
        _lastPhasePushTime = now;
        debugPrint('✅ Job phase → ${updated.phase}');
      }
    } catch (e) {
      debugPrint('❌ Phase update failed: $e');
    }
  }

  bool _canTransitionToJobPhase(String next) {
    const order = [
      'open',
      'accepted',
      'preparing',
      'loading',
      'ready',
      'enroute',
      'arrived',
      'unloading',
    ];

    final current = _lastPushedJobPhase ?? 'accepted';

    final currentIndex = order.indexOf(current);
    final nextIndex = order.indexOf(next);

    if (currentIndex == -1 || nextIndex == -1) return false;

    return nextIndex > currentIndex;
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

    final deepZoomMode = context.watch<DeepZoomProvider>().mode;
    final useCleanBackgroundAfterNativeZoom =
        deepZoomMode == DeepZoomMode.cleanBackground;

    final shouldShowTileLayer =
        _currentZoom <= _lastRealTileZoom || !useCleanBackgroundAfterNativeZoom;

    final shouldShowDeepZoomGrid =
        _currentZoom > _lastRealTileZoom && useCleanBackgroundAfterNativeZoom;

    return Stack(
      children: [
        // ===========================================================
        // 1. AVATAR MODE → Show GroundOpsScreen INSTEAD of the map _shouldShowGroundOps
        // ===========================================================
        if (_shouldShowGroundOps)
          Positioned.fill(
            child: GroundOpsScreen(
              flight: _currentFlight,
              minimalView: _groundOpsMinimalView,
              onClose: () {
                setState(() => _showGroundOpsManually = false);
              },
            ),
          ),
        // ===========================================================
        // 2. AIRCRAFT MODE → Show the MapScreen as you already built it
        // ===========================================================
        if (!_shouldShowGroundOps) ...[
          // 🔥 Put ALL your existing Map UI here.
          // Nothing changes, you keep 100% of your current code.
          Listener(
            onPointerDown: (_) {
              _touchReleaseTimer?.cancel();
              _userTouchingMap = true;
            },
            onPointerUp: (_) {
              _touchReleaseTimer?.cancel();
              _touchReleaseTimer = Timer(const Duration(milliseconds: 350), () {
                _userTouchingMap = false;
              });
            },
            onPointerCancel: (_) {
              _touchReleaseTimer?.cancel();
              _userTouchingMap = false;
            },
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: _initialCenter ?? initialView,
                initialZoom: 2,
                minZoom: 1,
                maxZoom: 20,
                backgroundColor: tileLayers[_mapStyleIndex].mapBackgroundColor,
                onPositionChanged: (camera, hasGesture) {
                  _mapCenter = camera.center;
                  _currentZoom = camera.zoom;

                  if (_showGround && _showGroundLabels) {
                    final zoom = camera.zoom;
                    if ((_lastZoom == null) ||
                        ((zoom - (_lastZoom ?? zoom)).abs() >= 0.2)) {
                      _groundLabelMarkersNotifier
                          .value = _buildGroundLabelMarkers(_groundLabels);
                      _lastZoom = zoom;
                    }
                  }

                  if (mounted) {
                    setState(() {});
                  }
                },
                onMapReady: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;

                    _mapCenter = mapController.camera.center;
                    _currentZoom = mapController.camera.zoom;

                    setState(() => _mapReady = true);
                    _throttledUpdateAirportMarkers();

                    _groundOverlayThrottle?.cancel();
                    _groundOverlayThrottle = Timer(
                      const Duration(milliseconds: 1000),
                      () {
                        _updateGroundOverlayFromMapCenter();
                        _throttledUpdateParkingMarkers(force: true);
                        _throttledUpdateVorMarkers(force: true);
                        _throttledUpdateNdbMarkers(force: true);
                        _throttledUpdateWaypointMarkers(force: true);
                      },
                    );
                  });
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                  rotationThreshold: 15.0,
                ),
              ),
              children: [
                // Map tile layer
                if (shouldShowTileLayer)
                  TileLayer(
                    urlTemplate: tileLayers[_mapStyleIndex].url,
                    subdomains: tileLayers[_mapStyleIndex].subdomains,
                    userAgentPackageName: 'com.skycase',
                    retinaMode: false,
                    tileDimension: 256,
                    minZoom: 1,
                    maxZoom: 20,
                    maxNativeZoom: _lastRealTileZoom.toInt(),
                    keepBuffer: 0,
                    panBuffer: 0,
                  ),

                if (shouldShowDeepZoomGrid)
                  DeepZoomGridLayer(
                    zoom: _currentZoom,
                    gridColor: tileLayers[_mapStyleIndex].fallbackGridColor,
                    crossColor: tileLayers[_mapStyleIndex].fallbackCrossColor,
                    startZoom: _lastRealTileZoom + 0.2,
                  ),

                // Aircraft trail polyline
                ValueListenableBuilder<LiveMapVisuals>(
                  valueListenable: _liveMapVisualsNotifier,
                  builder: (_, visuals, __) {
                    if (visuals.trailPolylines.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return PolylineLayer(polylines: visuals.trailPolylines);
                  },
                ),

                if (_showGround && _groundPolylines.isNotEmpty)
                  PolylineLayer(polylines: _groundPolylines),

                if (_showGround && _showGroundLabels)
                  ValueListenableBuilder<List<Marker>>(
                    valueListenable: _groundLabelMarkersNotifier,
                    builder: (_, markers, __) {
                      if (markers.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(markers: markers);
                    },
                  ),

                if (_showAllFlights && _flightLogs.isNotEmpty)
                  PolylineLayer(polylines: _buildFlightHistoryPolylines()),

                if (_currentFlight != null &&
                    _buildDisplayedRoute().length >= 2) ...[
                  Builder(
                    builder: (_) {
                      final routePoints = _buildDisplayedRoute();

                      if (routePoints.length < 2) {
                        return const SizedBox.shrink();
                      }

                      return PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 5,
                            color: Colors.cyanAccent,
                          ),
                        ],
                      );
                    },
                  ),
                ],
                ValueListenableBuilder<LiveMapVisuals>(
                  valueListenable: _liveMapVisualsNotifier,
                  builder: (_, visuals, __) {
                    if (visuals.headingBugPolylines.isEmpty)
                      return const SizedBox.shrink();
                    return PolylineLayer(
                      polylines: visuals.headingBugPolylines,
                    );
                  },
                ),

                if (_showRunways) PolylineLayer(polylines: _runwayPolylines),
                if (_showRunways) MarkerLayer(markers: _runwayMarkers),

                if (_showVOR)
                  ValueListenableBuilder<List<Marker>>(
                    valueListenable: _vorMarkersNotifier,
                    builder: (_, markers, __) {
                      if (markers.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(markers: markers);
                    },
                  ),

                if (_showNDB)
                  ValueListenableBuilder<List<Marker>>(
                    valueListenable: _ndbMarkersNotifier,
                    builder: (_, markers, __) {
                      if (markers.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(markers: markers);
                    },
                  ),
                if (_showParking)
                  ValueListenableBuilder<List<Marker>>(
                    valueListenable: _parkingMarkersNotifier,
                    builder: (_, markers, __) {
                      if (markers.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(markers: markers);
                    },
                  ),
                if (_showWaypoints)
                  ValueListenableBuilder<List<Marker>>(
                    valueListenable: _waypointMarkersNotifier,
                    builder: (_, markers, __) {
                      if (markers.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(markers: markers);
                    },
                  ),
                if (_showAirways)
                  ValueListenableBuilder<List<Polyline>>(
                    valueListenable: _airwayPolylinesNotifier,
                    builder: (_, polylines, __) {
                      if (polylines.isEmpty) return const SizedBox.shrink();
                      return PolylineLayer(polylines: polylines);
                    },
                  ),
                if (_showAirways)
                  ValueListenableBuilder<List<Marker>>(
                    valueListenable: _airwayLabelsNotifier,
                    builder: (_, markers, __) {
                      if (markers.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(markers: markers);
                    },
                  ),
                // 💣 Fully skip marker layer below zoom 3.0
                if (_mapReady && mapController.camera.zoom >= 2.0)
                  ValueListenableBuilder<List<Marker>>(
                    valueListenable: _airportMarkersNotifier,
                    builder: (_, markers, __) {
                      if (markers.isEmpty) return const SizedBox.shrink();
                      return MarkerLayer(markers: markers);
                    },
                  ),

                // Aircraft + trail start/end markers including turbulence markers
                ValueListenableBuilder<LiveMapVisuals>(
                  valueListenable: _liveMapVisualsNotifier,
                  builder: (_, visuals, __) {
                    final markers = <Marker>[
                      ...visuals.markers,

                      if (_showPoi)
                        ...visiblePoiForZoom(_currentZoom).map((poi) {
                          return Marker(
                            point: LatLng(poi.lat, poi.lng),
                            width: 96,
                            height: 56,
                            child: GestureDetector(
                              onTap: () => _showPoiInfo(poi),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    poiIconForType(poi.type),
                                    size: 18,
                                    color: poiColorForType(poi.type),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      poi.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ];

                    if (markers.isEmpty) return const SizedBox.shrink();
                    return MarkerLayer(markers: markers);
                  },
                ),
              ],
            ),
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

          // Live data overlay
          if (hasData)
            MapOverlay(
              simData: simData!,
              show: (powerOn || isDataOffline),
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
                    final aircraftPos = LatLng(
                      simData!.latitude,
                      simData!.longitude,
                    );

                    mapController.move(aircraftPos, mapController.camera.zoom);
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

          if (_isConnected && hasData && _settingsLoaded && battOn)
            Positioned(
              top: 50,
              right: 100,
              child: FloatingActionButton.small(
                heroTag: 'ground_ops_btn',
                onPressed: () {
                  setState(() => _showGroundOpsManually = true);
                },
                child: const Icon(Icons.flight_class),
              ),
            ),

          if ((battOn || isDataOffline) && _settingsLoaded)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 800), // Διάρκεια κίνησης
              curve: Curves.easeInOut, // Ομαλή κίνηση
              top: 50,
              right: (simData != null) ? 20 : 16,
              child: FloatingActionButton.small(
                heroTag: 'map_side_menu_btn',
                onPressed: _toggleSideMenu,
                child: const Icon(Icons.menu),
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

          Positioned(
            bottom: 10,
            left: isMobile(context) ? 10 : 40,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              opacity: isDataOffline ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isDataOffline,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.power_settings_new,
                      color: Colors.white,
                      size: 26,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'SimLink offline',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
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

          // 🛩️ AUTOPILOT STATUS PANEL
          if (simData != null && (powerOn || isDataOffline))
            Positioned(
              bottom: isDesktop(context) ? 10 : 20, // adjust to taste
              left: 15,
              child: powerDim(
                _vibrateIfEngineOn(_autopilotPanel(simData!.autopilot)),
              ),
            ),

          // SYSTEM LIGHT STRIP (under the top buttons)
          if (simData != null && (powerOn || battOn))
            Positioned(
              bottom: isDesktop(context) ? 130 : 100,
              left: 12,
              right: 12,
              child: powerDim(
                _vibrateIfEngineOn(
                  _systemStrip(simData!.mission, isDesktop(context)),
                ),
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

          if (hasData && isIcing(simData!))
            Positioned(
              bottom: 250,
              left: 10,
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

          if ((battOn || isDataOffline) && _mapCenter != null && !_showMetar)
            Positioned(
              bottom: 10,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "ZOOM ${_currentZoom.toStringAsFixed(1)}",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],

        if (_showSideMenu) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleSideMenu,
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
          ),
          _buildMapSideMenu(context),
        ],

        if (_currentFlight != null &&
            !isDataOffline &&
            (powerOn || battOn) &&
            !_showMetar &&
            !_showGroundOpsManually)
          Positioned(
            top: isDesktop(context) ? 20 : 100,
            left: 0,
            right: 0,
            child: Center(child: _flightPlanPanel(context)),
          ),

        if (_currentFlight != null &&
            !isDataOffline &&
            (powerOn || battOn) &&
            !_showMetar &&
            !_showGroundOpsManually &&
            simData != null)
          Positioned(
            bottom: isDesktop(context) ? 250 : 220, // 👈 adjust if needed
            left: 10,

            child: _busOatPanel(),
          ),
        if (_selectedMapObject != null)
          Positioned(
            left: _infoCardLeft,
            top: _infoCardTop,
            child: _buildDraggableSelectedObjectCard(context),
          ),

        if (simData != null && (powerOn || isDataOffline))
          Positioned(
            bottom: isDesktop(context) ? 130 : 100, // 👈 adjust if needed
            left: 180,
            child: _comRadioOverlay(simData!),
          ),

        if (_nearbyPoiAlert != null &&
            _selectedMapObject == null &&
            (powerOn || isDataOffline))
          Positioned(top: 150, right: 16, child: _buildNearbyPoiAlertCard()),

        if (_cinematicHudMessage != null) _buildCinematicHud(),
      ],
    );
  }

  /// Aircraft marker color based on map style
  Color _getMarkerColor(String tileName) {
    switch (tileName.toLowerCase()) {
      case 'skycase dark':
        return Colors.white;
      case 'skycase light':
        return Colors.black;
      default:
        return const Color.fromARGB(255, 3, 131, 206);
    }
  }

  Color _getTrailColor(double altitude) {
    final themeName = tileLayers[_mapStyleIndex].name.toLowerCase();
    final base = _altitudeTint(altitude);

    switch (themeName) {
      case 'skycase dark':
        return _mix(base, Colors.cyanAccent, 0.40);
      case 'skycase light':
        return _mix(base, Colors.orangeAccent, 0.25);
      default:
        return _mix(base, Colors.deepPurpleAccent, 0.25);
    }
  }

  Color _getTurbulenceColor(String severity) {
    switch (severity) {
      case 'severe':
        return Colors.red.withOpacity(0.5);
      case 'moderate':
      default:
        return Colors.yellow.withOpacity(0.4);
    }
  }

  List<Poi> visiblePoiForZoom(double zoom) {
    if (zoom < 3.5) {
      return globalPoi
          .where(
            (p) =>
                p.name == 'Pyramids of Giza' ||
                p.name == 'Mount Everest' ||
                p.name == 'Great Wall of China' ||
                p.name == 'Grand Canyon' ||
                p.name == 'Machu Picchu' ||
                p.name == 'Uluru' ||
                p.name == 'Bermuda Triangle' ||
                p.name == 'Point Nemo' ||
                p.name == 'Acropolis' ||
                p.name == 'Eiffel Tower',
          )
          .toList();
    }

    if (zoom < 5.5) {
      return globalPoi
          .where((p) => p.type != 'historic' || p.name.length < 18)
          .toList();
    }

    return globalPoi;
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

  void _showAirportInfo(Airport airport) {
    showGeneralDialog(
      context: context,
      barrierLabel: "Airport Info",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 700;
        final double panelWidth = isMobile ? screenWidth * 0.94 : 430;

        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                height: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(-4, 0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyanAccent,
                                  width: 2.5,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.local_airport,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

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

                            const SizedBox(width: 8),

                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        Divider(color: Colors.white24),
                        const SizedBox(height: 12),

                        // ============================================================
                        // BASIC AIRPORT INFO
                        // ============================================================
                        _infoRow("ICAO", airport.icao),
                        _infoRow("Name", airport.name),
                        _infoRow("Country", airport.country),
                        _infoRow(
                          "Elevation",
                          "${airport.elevation.toStringAsFixed(0)} ft",
                        ),
                        _infoRow(
                          "Type",
                          airport.isMilitary ? "Military" : "Civilian",
                        ),

                        const SizedBox(height: 20),

                        // ============================================================
                        // AIRPORT FREQUENCIES
                        // ============================================================
                        Builder(
                          builder: (_) {
                            final freqs = _freqByIcao[airport.icao] ?? [];

                            if (freqs.isEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  const Text(
                                    "No frequencies available",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final unique = <String, AirportFrequency>{};
                            for (final f in freqs) {
                              unique["${f.type}_${f.frequency}"] = f;
                            }

                            final cleanList = unique.values.toList();

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
                                  final mhz = (f.frequency / 1000.0)
                                      .toStringAsFixed(3);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
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
                                                        f
                                                            .description!
                                                            .isNotEmpty
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

                        const SizedBox(height: 20),

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
                              backgroundColor: Colors.cyanAccent.withOpacity(
                                0.2,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: animation, child: child),
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

  Map<String, dynamic>? _latLngToJson(LatLng? point) {
  if (point == null) return null;
  return {
    'lat': point.latitude,
    'lng': point.longitude,
  };
}

DateTime? _readDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Future<void> _saveUiShellState() async {
  final prefs = await SharedPreferences.getInstance();

  final data = <String, dynamic>{
    'followAircraft': _followAircraft,
    'mapRotation': _mapRotation,
    'currentZoom': _currentZoom,
    'mapCenter': _latLngToJson(_mapCenter),
    'showSideMenu': _showSideMenu,
    'showMetar': _showMetar,
    'showRawMetar': _showRawMetar,
    'showPoi': _showPoi,
    'showAirways': _showAirways,
    'showRunways': _showRunways,
    'showParking': _showParking,
    'showWaypoints': _showWaypoints,
    'showVOR': _showVOR,
    'showNDB': _showNDB,
    'showGround': _showGround,
    'showAllFlights': _showAllFlights,
    'showGroundOpsManually': _showGroundOpsManually,
    'infoCardTop': _infoCardTop,
    'infoCardLeft': _infoCardLeft,
    'selectedMapObjectType': _selectedMapObjectType,
  };

  await prefs.setString('map_ui_shell_state', jsonEncode(data));
}

Future<void> _loadUiShellState() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('map_ui_shell_state');
  if (raw == null) return;

  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;

    _followAircraft = data['followAircraft'] ?? true;
    _mapRotation = (data['mapRotation'] as num?)?.toDouble() ?? 0.0;
    _currentZoom = (data['currentZoom'] as num?)?.toDouble() ?? _currentZoom;

    final center = data['mapCenter'];
    if (center != null) {
      _mapCenter = LatLng(
        (center['lat'] as num).toDouble(),
        (center['lng'] as num).toDouble(),
      );
    }

    _showSideMenu = data['showSideMenu'] == true;
    _showMetar = data['showMetar'] == true;
    _showRawMetar = data['showRawMetar'] != false;
    _showPoi = data['showPoi'] == true;
    _showAirways = data['showAirways'] == true;
    _showRunways = data['showRunways'] != false;
    _showParking = data['showParking'] != false;
    _showWaypoints = data['showWaypoints'] == true;
    _showVOR = data['showVOR'] != false;
    _showNDB = data['showNDB'] == true;
    _showGround = data['showGround'] != false;
    _showAllFlights = data['showAllFlights'] == true;
    _showGroundOpsManually = data['showGroundOpsManually'] == true;

    _infoCardTop = (data['infoCardTop'] as num?)?.toDouble() ?? _infoCardTop;
    _infoCardLeft = (data['infoCardLeft'] as num?)?.toDouble() ?? _infoCardLeft;
    _selectedMapObjectType = data['selectedMapObjectType'] as String?;
  } catch (e) {
    debugPrint('❌ Failed to restore UI shell state: $e');
  }
}

Future<void> _saveFlightRuntimeSnapshot() async {
  final prefs = await SharedPreferences.getInstance();

  final data = <String, dynamic>{
    'inFlight': _inFlight,
    'flightSessionActive': _flightSessionActive,
    'flightQualified': _flightQualified,
    'startTime': _startTime?.toIso8601String(),
    'takeoffTimestamp': _takeoffTimestamp?.toIso8601String(),
    'touchdownTime': _touchdownTime?.toIso8601String(),
    'startPoint': _latLngToJson(_startPoint),
    'trail': _trail
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList(),
    'backendTrail': _backendTrail,
    'isGrounded': _isGrounded,
    'pendingFlightEnd': _pendingFlightEnd,
    'pendingEndTime': _pendingEndTime?.toIso8601String(),
    'runwayUsedDeparture': _runwayUsedDeparture,
    'runwayUsedArrival': _runwayUsedArrival,
    'parkingStart': _parkingStart,
    'parkingEnd': _parkingEnd,
    'maxAltitude': _maxAltitude,
    'airspeedSum': _airspeedSum,
    'airspeedSamples': _airspeedSamples,
    'cruiseConfirmed': _cruiseConfirmed,
    'fuelGallons': _fuelGallons,
    'fuelMinutesLeft': _fuelMinutesLeft,
    'finalParkedAnnounced': _finalParkedAnnounced,
  };

  await prefs.setString('map_flight_runtime', jsonEncode(data));
}

Future<void> _loadFlightRuntimeSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('map_flight_runtime');
  if (raw == null) return;

  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;

    _inFlight = data['inFlight'] == true;
    _flightSessionActive = data['flightSessionActive'] == true;
    _flightQualified = data['flightQualified'] == true;

    _startTime = _readDateTime(data['startTime']);
    _takeoffTimestamp = _readDateTime(data['takeoffTimestamp']);
    _touchdownTime = _readDateTime(data['touchdownTime']);

    final start = data['startPoint'];
    if (start != null) {
      _startPoint = LatLng(
        (start['lat'] as num).toDouble(),
        (start['lng'] as num).toDouble(),
      );
    }

    final trail = (data['trail'] as List? ?? []);
    _trail = trail
        .map((e) => LatLng(
              (e['lat'] as num).toDouble(),
              (e['lng'] as num).toDouble(),
            ))
        .toList();

    final backendTrail = (data['backendTrail'] as List? ?? []);
    _backendTrail = List<Map<String, dynamic>>.from(
      backendTrail.map((e) => Map<String, dynamic>.from(e)),
    );

    _isGrounded = data['isGrounded'] as bool?;
    _pendingFlightEnd = data['pendingFlightEnd'] == true;
    _pendingEndTime = _readDateTime(data['pendingEndTime']);

    _runwayUsedDeparture = data['runwayUsedDeparture'] as String?;
    _runwayUsedArrival = data['runwayUsedArrival'] as String?;
    _parkingStart = data['parkingStart'] as String?;
    _parkingEnd = data['parkingEnd'] as String?;

    _maxAltitude = (data['maxAltitude'] as num?)?.toDouble() ?? 0.0;
    _airspeedSum = (data['airspeedSum'] as num?)?.toDouble() ?? 0.0;
    _airspeedSamples = (data['airspeedSamples'] as num?)?.toInt() ?? 0;

    _cruiseConfirmed = data['cruiseConfirmed'] == true;
    _fuelGallons = (data['fuelGallons'] as num?)?.toDouble() ?? 0.0;
    _fuelMinutesLeft = (data['fuelMinutesLeft'] as num?)?.toDouble() ?? 999.0;

    _finalParkedAnnounced = data['finalParkedAnnounced'] == true;

    if (!mounted) return;
    setState(() {});
    _refreshLiveMapVisuals();
  } catch (e) {
    debugPrint('❌ Failed to restore flight runtime snapshot: $e');
  }
}

Future<void> _clearFlightRuntimeSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('map_flight_runtime');
  await prefs.remove('flight_trail');
  await prefs.remove('start_lat');
  await prefs.remove('start_lng');
}


 Future<void> _saveTrail(List<LatLng> trail) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = jsonEncode(
    trail
        .map((e) => {'lat': e.latitude, 'lng': e.longitude})
        .toList(),
  );
  await prefs.setString('flight_trail', encoded);
}

Future<void> _loadTrail() async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = prefs.getString('flight_trail');
  if (encoded == null) return;

  try {
    final List<dynamic> raw = jsonDecode(encoded);
    final restored = raw
        .map<LatLng>((e) => LatLng(
              (e['lat'] as num).toDouble(),
              (e['lng'] as num).toDouble(),
            ))
        .toList();

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _trail
          ..clear()
          ..addAll(restored);
      });
      _refreshLiveMapVisuals();
      debugPrint("🟢 Trail restored with ${_trail.length} points.");
    });
  } catch (e) {
    debugPrint('❌ Error loading trail: $e');
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
  await _loadFlightRuntimeSnapshot();
}

  Future<void> _loadAllFlightLogs() async {
    if (_loadingFlightLogs) return;

    setState(() => _loadingFlightLogs = true);

    try {
      final token = await SessionManager.loadToken();

      if (token == null) {
        if (!mounted) return;
        setState(() => _loadingFlightLogs = false);
        return;
      }

      final userId = _extractUserIdFromToken(token);
      if (userId == null || userId.isEmpty) {
        if (!mounted) return;
        setState(() => _loadingFlightLogs = false);
        return;
      }

      _flightLogsUserId = userId;

      final logs = await FlightLogService.getFlightLogs(userId);

      if (!mounted) return;
      setState(() {
        _flightLogs = logs;
        _loadingFlightLogs = false;
      });
    } catch (e) {
      print('❌ Failed loading all flight logs: $e');
      if (!mounted) return;
      setState(() => _loadingFlightLogs = false);
    }
  }

  String? _extractUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );

      final data = jsonDecode(payload) as Map<String, dynamic>;

      return data['id']?.toString() ??
          data['_id']?.toString() ??
          data['userId']?.toString();
    } catch (e) {
      print('❌ Could not decode token for userId: $e');
      return null;
    }
  }

  void _captureLandingReplaySample(SimLinkData data, DateTime now) {
    final sample = LandingReplaySample(
      lat: data.latitude,
      lng: data.longitude,
      heading: data.heading,
      airspeed: data.airspeed,
      altitude: data.altitude,
      verticalSpeed: data.verticalSpeed,
      onGround: data.onGround,
      timestamp: now,
    );

    _landingReplayBuffer.add(sample);

    _landingReplayBuffer.removeWhere(
      (e) => now.difference(e.timestamp).inSeconds > 30,
    );

    if (_recordLandingRollout) {
      _landingReplayFinal.add(sample);

      final touchdownAge =
          _touchdownTime == null
              ? 0
              : now.difference(_touchdownTime!).inSeconds;

      if (touchdownAge > 25 || data.airspeed < 20) {
        _recordLandingRollout = false;
      }
    }
  }

  double _estimateRunwayHeading(String? runway) {
    if (runway == null || runway.isEmpty) return 0;

    final match = RegExp(r'(\d{2})').firstMatch(runway);
    if (match == null) return 0;

    final numPart = int.tryParse(match.group(1)!);
    if (numPart == null) return 0;

    return numPart * 10.0;
  }

  Landing2d? _buildLanding2dPayload() {
    if (_landingReplayFinal.isEmpty) return null;

    LandingReplaySample? touchdown;

    for (final sample in _landingReplayFinal) {
      if (sample.onGround) {
        touchdown = sample;
        break;
      }
    }

    touchdown ??= _landingReplayFinal.last;

    final rolloutSeconds =
        _touchdownTime == null
            ? 0
            : DateTime.now().difference(_touchdownTime!).inSeconds;

    return Landing2d(
      runway: _runwayUsedArrival ?? '',
      runwayHeading: _estimateRunwayHeading(_runwayUsedArrival),
      touchdownLat: touchdown.lat,
      touchdownLng: touchdown.lng,
      touchdownHeading: touchdown.heading,
      touchdownVerticalSpeed: touchdown.verticalSpeed,
      touchdownGroundSpeed: touchdown.airspeed,
      touchdownPitch: simData?.pitch ?? 0,
      touchdownBank: simData?.slipBetaDeg ?? 0,
      hardLanding: touchdown.verticalSpeed.abs() > 500,
      butterScore: (logSafeInt(_lastLandingRating) ?? 0),
      rolloutSeconds: rolloutSeconds,
      samples: _landingReplayFinal.map((e) => e.toLanding2dSample()).toList(),
    );
  }

  int? logSafeInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));
  }

  List<Polyline> _buildFlightHistoryPolylines() {
    return _flightLogs.where((log) => log.trail.length >= 2).map((log) {
      final start = log.trail.first;
      final end = log.trail.last;

      return Polyline(
        points: [LatLng(start.lat, start.lng), LatLng(end.lat, end.lng)],
        strokeWidth: 2.2,
        color: const Color.fromARGB(255, 57, 35, 255).withOpacity(0.55),
      );
    }).toList();
  }

  List<Marker> _buildFlightHistoryMarkers() {
    final markers = <Marker>[];

    for (final log in _flightLogs) {
      if (log.trail.isEmpty) continue;

      final start = log.trail.first;
      final end = log.trail.last;

      markers.add(
        Marker(
          point: LatLng(start.lat, start.lng),
          width: 20,
          height: 20,
          child: const Icon(
            Icons.flight_takeoff,
            size: 14,
            color: Colors.cyanAccent,
          ),
        ),
      );

      if (log.trail.length > 1) {
        markers.add(
          Marker(
            point: LatLng(end.lat, end.lng),
            width: 20,
            height: 20,
            child: const Icon(
              Icons.flight_land,
              size: 14,
              color: Colors.redAccent,
            ),
          ),
        );
      }
    }

    return markers;
  }

  IconData poiIconForType(String type) {
    switch (type) {
      case 'historic':
        return Icons.account_balance;
      case 'landmark':
        return Icons.location_city;
      case 'natural':
        return Icons.terrain;
      case 'weird':
        return Icons.visibility;
      default:
        return Icons.place;
    }
  }

  Color poiColorForType(String type) {
    switch (type) {
      case 'historic':
        return Colors.amber;
      case 'landmark':
        return Colors.lightBlueAccent;
      case 'natural':
        return Colors.lightGreenAccent;
      case 'weird':
        return Colors.deepPurpleAccent;
      default:
        return Colors.white;
    }
  }

  Future<void> _saveTurbulenceEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _turbulenceEvents.map((e) => e.toJson()).toList();
    await prefs.setString('turbulence_events', jsonEncode(jsonList));
  }

  Future<void> _loadTurbulenceEvents() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Never restore turbulence into a fresh/non-active session
    if (!_inFlight || _currentFlight == null) {
      await prefs.remove('turbulence_events');
      if (!mounted) return;

      setState(() {
        _turbulenceEvents.clear();
      });
      _refreshLiveMapVisuals();
      return;
    }

    final encoded = prefs.getString('turbulence_events');
    if (encoded == null) return;

    try {
      final List<dynamic> raw = jsonDecode(encoded);

      if (!mounted) return;
      setState(() {
        _turbulenceEvents.clear();
        _turbulenceEvents.addAll(raw.map((e) => TurbulenceEvent.fromJson(e)));
      });
      _refreshLiveMapVisuals();
    } catch (e) {
      print('❌ Error loading turbulence events: $e');
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

    _updateLastTurbSamples(data);

    _refreshLiveMapVisuals();
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
    await _resetLiveFlightVisuals();
    print("🧪 StartFlight — userId = $userId");

    _livePhase = null;
    _pendingPhase = null;
    _pendingPhaseSince = null;
    _lastLandedEventTime = null;
    _finalParkedAnnounced = false;
    _lastAnnouncedPhase = null;

    // ------------------------------------------------------------
    // 🔗 Bind flight to active job (if any)
    // ------------------------------------------------------------
    if (widget.jobId != null && widget.jobId!.isNotEmpty) {
      await prefs.setString('flight_job_id', widget.jobId!);
      print("🧭 Flight bound to job ${widget.jobId}");
    } else if (userId != null) {
      final activeJob = await DispatchService.getActiveJob(userId);

      if (activeJob != null) {
        await prefs.setString('flight_job_id', activeJob.id);
        print("🧭 Flight bound to job ${activeJob.id}");
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
    _refreshLiveMapVisuals();

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
    if (_isFinalizingFlight) return;

    _isFinalizingFlight = true;

    try {
      final didSave = await _finalizeAndUploadFlight();

      if (!didSave) {
        print("⚠️ Manual end failed — flight not cleaned up");
        showHudMessage("⚠️ Could not save flight");
      }
    } finally {
      _isFinalizingFlight = false;
    }
  }

  void _throttledUpdateAirportMarkers({bool force = false}) {
    if (_airportUpdateThrottle?.isActive ?? false) return;

    _airportUpdateThrottle = Timer(const Duration(milliseconds: 250), () {
      if (!_mapReady || _airports.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final camera = mapController.camera;
        if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

        final zoom = camera.zoom;
        final bounds = camera.visibleBounds;

        if (!force && zoom == _lastZoom && bounds == _lastBounds) return;

        if (!force) {
          _lastZoom = zoom;
          _lastBounds = bounds;
        }

        const double hideZoom = 7.0;
        const double detailZoom = 11.0;
        const double clusterBucketSize = 2.5;

        // =======================================================
        // 1) HARD HIDE
        // =======================================================
        if (zoom < hideZoom) {
          _airportMarkersNotifier.value = [];
          return;
        }

        final visibleAirports =
            _airports
                .where((a) => bounds.contains(LatLng(a.lat, a.lon)))
                .toList();

        final List<Marker> markers = [];

        // =======================================================
        // 2) DETAIL MODE
        // =======================================================
        if (zoom >= detailZoom) {
          for (final airport in visibleAirports) {
            final cat = categorizeAirport(airport);

            if ((cat == AirportCategory.airport && !_filterBig) ||
                (cat == AirportCategory.heli && !_filterHeli)) {
              continue;
            }

            final pos = LatLng(airport.lat, airport.lon);
            final isJobDest =
                widget.jobTo != null &&
                airport.icao == widget.jobTo!.toUpperCase();

            final baseColor = markerColor(cat);

            final showLabel = zoom >= 12.0;

            markers.add(
              Marker(
                key: ValueKey('airport_${airport.icao}_$zoom'),
                point: pos,
                width: showLabel ? 84 : 40,
                height: showLabel ? 52 : 40,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAirportInfo(airport),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isJobDest ? 18 : 14,
                        height: isJobDest ? 18 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isJobDest ? Colors.orangeAccent : baseColor,
                          boxShadow: [
                            BoxShadow(
                              color: (isJobDest
                                      ? Colors.orangeAccent
                                      : baseColor)
                                  .withOpacity(1.0),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),

                      if (showLabel)
                        Transform.rotate(
                          angle: _mapRotation * (pi / 180),
                          child: Container(
                            margin: const EdgeInsets.only(top: 3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              airport.icao,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'RobotoMono',
                              ),
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
        // =======================================================
        // 3) CLUSTER MODE
        // =======================================================
        else {
          clusters.clear();

          for (final airport in visibleAirports) {
            final cat = categorizeAirport(airport);

            if ((cat == AirportCategory.airport && !_filterBig) ||
                (cat == AirportCategory.heli && !_filterHeli)) {
              continue;
            }

            final key =
                '${(airport.lat / clusterBucketSize).floor()}_${(airport.lon / clusterBucketSize).floor()}';

            clusters.putIfAbsent(key, () => []).add(airport);
          }

          for (final group in clusters.values) {
            final avgLat =
                group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
            final avgLon =
                group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;

            final AirportCategory cat = categorizeAirport(group.first);
            final Color dotColor = markerColor(cat);
            final bool isSingle = group.length == 1;
            final String countLabel =
                group.length > 9 ? '9+' : '${group.length}';

            markers.add(
              Marker(
                point: LatLng(avgLat, avgLon),
                width: 28,
                height: 28,
                child: IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isSingle ? 5 : 8,
                          height: isSingle ? 5 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withOpacity(0.95),
                                blurRadius: isSingle ? 8 : 10,
                                spreadRadius: isSingle ? 0.8 : 1.2,
                              ),
                            ],
                          ),
                        ),
                        if (!isSingle) ...[
                          const SizedBox(height: 2),
                          Text(
                            countLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }

        if (mounted) {
          _airportMarkersNotifier.value = markers;
        }

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

      final bool connectionStateChanged =
          !_isConnected || _isConnecting || _isReconnecting;

      // Update live sim packet WITHOUT forcing a rebuild here.
      simData = data;

      // Only rebuild if connection flags actually changed.
      if (connectionStateChanged) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _isReconnecting = false;
        });
      } else {
        _isConnected = true;
        _isConnecting = false;
        _isReconnecting = false;
      }

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
          _lastFlightDestination = LatLng(
            logs.first.endLocation!.lat,
            logs.first.endLocation!.lng,
          );
          _initialCenter = _lastFlightDestination;
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
          _initialCenter ??= _homeBase;
        }
      } catch (e) {
        print('❌ Failed to fetch HQ: $e');
      }
    }

    _initialCenter ??= const LatLng(37.9838, 23.7275);

    if (!mounted) return;
    setState(() {
      _initialCenterReady = true;
    });

    _refreshLiveMapVisuals();
  }

  

 void _disconnectFromSimLink() async {
  final fallbackCenter =
      _mapCenter ??
      (simData != null
          ? LatLng(simData!.latitude, simData!.longitude)
          : _initialCenter);

  debugPrint("🔌 SimLink disconnect requested");

  await _saveUiShellState();
  await _saveFlightRuntimeSnapshot();
  await _socketService.dispose();

  simData = null;

  if (!mounted) return;
  setState(() {
    _isConnected = false;
    _isConnecting = false;
    _isReconnecting = false;
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    try {
      if (fallbackCenter != null) {
        mapController.move(fallbackCenter, _currentZoom);
      }
      mapController.rotate(_mapRotation);
    } catch (_) {}
  });
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

    // ✅ Reset old route visuals before building a new route
    await _resetPlannedRouteOnly();

    final distanceNm = _calculateDistanceNm(origin, destination);
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

    if (mounted) {
      setState(() {
        _currentFlight = flight;
      });
    }

    _checkFuelRange();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🧭 Direct flight to $destinationIcao set')),
      );
    }
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
    if (!mounted) return;

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

    // Χρησιμοποιούμε το airspeed από το SimLinkData σου
    final double speed = (simData!.airspeed).clamp(50, 500).toDouble();
    final double currentAlt = simData!.altitude;

    // ΠΑΝΤΑ κοιτάμε τι έχει βάλει ο χρήστης στο Autopilot Target
    // Αν είναι 0, πέφτουμε στο Cruise Altitude του Flight Plan
    final double targetAlt =
        simData!.autopilot.altitudeTarget > 0
            ? simData!.autopilot.altitudeTarget
            : (_currentFlight!.cruiseAltitude?.toDouble() ?? 0);

    // ---------- 1. DESTINATION ETA ----------
    etaDest = (_remainingNm / speed) * 60;

    // ---------- 2. TOC (Top of Climb) ----------
    // Αν το τρέχον υψόμετρο είναι κάτω από το Target του Autopilot
    if (simData!.verticalSpeed > 100 && currentAlt < (targetAlt - 100)) {
      double altToClimb = targetAlt - currentAlt;
      // Χρησιμοποιούμε το Vertical Speed Target αν υπάρχει, αλλιώς το τρέχον VS
      double vsForCalc =
          simData!.autopilot.verticalSpeedTarget.abs() > 0
              ? simData!.autopilot.verticalSpeedTarget.abs()
              : simData!.verticalSpeed.abs();

      etaTOC = (altToClimb / vsForCalc);
      requiredClimbFpm = altToClimb / (etaTOC! > 0 ? etaTOC! : 1);
    } else {
      etaTOC = 0;
      requiredClimbFpm = 0;
    }

    // ---------- 3. TOD (Top of Descent) - Dynamic 3-to-1 ----------
    // Εδώ το target είναι το Elevation του προορισμού (αν δεν το έχεις, βάλε 2000ft standard)
    double arrivalAlt = 2000.0;
    double altToLose = (currentAlt - arrivalAlt).clamp(0, 45000);

    // Πόσα μίλια χρειαζόμαστε για να χάσουμε το υψόμετρο (3nm ανά 1000ft)
    double nmNeededForDescent = (altToLose / 1000) * 3;

    // Απόσταση μέχρι το TOD
    double distToTod = _remainingNm - nmNeededForDescent;

    if (currentAlt > (arrivalAlt + 500) && distToTod > 0) {
      etaTOD = (distToTod / speed) * 60;

      // Πόσο VS θα χρειαστεί αν ξεκινούσαμε την κάθοδο ΤΩΡΑ
      double timeToDest = (_remainingNm / speed) * 60;
      requiredDescentFpm = timeToDest > 0 ? altToLose / timeToDest : 0;
    } else {
      etaTOD = 0;
      requiredDescentFpm = 0;
    }
  }

  void _computeTocTodPoints() {
    if (_currentFlight == null || simData == null) {
      _tocPoint = null;
      _todPoint = null;
      return;
    }

    final LatLng currentPos = LatLng(simData!.latitude, simData!.longitude);
    final LatLng dest = _airportCoords[_currentFlight!.destinationIcao]!;

    final double speed = (simData!.airspeed).clamp(50, 500).toDouble();
    final double currentAlt = simData!.altitude;
    final double targetAlt =
        simData!.autopilot.altitudeTarget > 0
            ? simData!.autopilot.altitudeTarget
            : (_currentFlight!.cruiseAltitude?.toDouble() ?? 0);

    // --------- 1. TOC POINT (Top of Climb) ---------
    // Αν ανεβαίνουμε και το Target Alt είναι ψηλότερα από εμάς
    if (simData!.verticalSpeed > 200 && currentAlt < (targetAlt - 200)) {
      double altToClimb = targetAlt - currentAlt;
      double vs =
          simData!.autopilot.verticalSpeedTarget.abs() > 0
              ? simData!.autopilot.verticalSpeedTarget.abs()
              : simData!.verticalSpeed.abs();

      double minutesToReach = altToClimb / vs;
      double nmToTOC = (speed / 60) * minutesToReach;

      // Το TOC μπαίνει 'nmToTOC' μίλια μπροστά από εμάς προς τον προορισμό
      _tocPoint = _pointOnRoute(currentPos, dest, nmToTOC);
    } else {
      _tocPoint = null;
    }

    // --------- 2. TOD POINT (Top of Descent) ---------
    // Χρησιμοποιούμε τον κανόνα 3-to-1 για να βρούμε ΠΟΣΑ ΜΙΛΙΑ ΠΡΙΝ το Dest είναι το TOD
    double arrivalAlt = 2000.0;
    double altToLose = (currentAlt - arrivalAlt).clamp(0, 45000);
    double nmNeededForDescent = (altToLose / 1000) * 3;

    // Το TOD είναι 'nmNeededForDescent' μίλια ΠΡΙΝ τον προορισμό
    // Άρα η απόσταση από εμάς είναι: (Απόσταση μέχρι Dest) - (Απόσταση καθόδου)
    double distFromCurrentToTod = _remainingNm - nmNeededForDescent;

    if (currentAlt > (arrivalAlt + 500) && distFromCurrentToTod > 0) {
      _todPoint = _pointOnRoute(currentPos, dest, distFromCurrentToTod);
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
      _mapStyleIndex = saved;
      _refreshLiveMapVisuals();
      if (mounted) setState(() {});
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

  void showHudMessage(
    String message, {
    IconData icon = Icons.airplanemode_active,
    Color accent = Colors.cyanAccent,
  }) {
    if (!mounted) return;

    _cinematicHudTimer?.cancel();

    setState(() {
      _cinematicHudMessage = message;
      _cinematicHudIcon = icon;
      _cinematicHudAccent = accent;
    });

    _hudFxController.stop();
    _hudFxController.reset();
    _hudFxController.forward();

    _cinematicHudTimer = Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;
      await _hudFxController.reverse();
      if (!mounted) return;
      setState(() {
        _cinematicHudMessage = null;
        _cinematicHudIcon = null;
      });
    });
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
    await NavRepository().loadVors();
    if (!mounted) return;
    setState(() {
      _vors = NavRepository().vors; // Ίδια ονομασία!
    });
  }

  void _throttledUpdateVorMarkers({bool force = false}) {
    if (_vorUpdateThrottle?.isActive ?? false) return;

    _vorUpdateThrottle = Timer(const Duration(milliseconds: 250), () {
      if (!_mapReady || !_showVOR || _vors.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final camera = mapController.camera;
        if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

        final zoom = camera.zoom;
        final bounds = camera.visibleBounds;

        if (!force && zoom == _lastVorZoom && bounds == _lastVorBounds) return;

        if (!force) {
          _lastVorZoom = zoom;
          _lastVorBounds = bounds;
        }

        const double hideZoom = 7.5;
        const double detailZoom = 10.5;
        const double clusterBucketSize = 2.2;

        if (zoom < hideZoom) {
          _vorMarkersNotifier.value = [];
          return;
        }

        final rawVisible =
            _vors.where((v) => bounds.contains(LatLng(v.lat, v.lon))).toList();

        final Map<String, Vor> uniqueVisible = {};
        for (final v in rawVisible) {
          final key =
              '${v.ident}_${v.lat.toStringAsFixed(4)}_${v.lon.toStringAsFixed(4)}';
          uniqueVisible[key] = v;
        }

        final visible = uniqueVisible.values.toList();

        final List<Marker> markers = [];

        if (zoom >= detailZoom) {
          for (final v in visible) {
            markers.add(
              Marker(
                point: LatLng(v.lat, v.lon),
                width: zoom >= 11.5 ? 72 : 30,
                height: zoom >= 11.5 ? 48 : 30,
                child: _buildSingleVorMarker(v, zoom),
              ),
            );
          }
        } else {
          _vorClusters.clear();

          for (final v in visible) {
            final key =
                '${(v.lat / clusterBucketSize).floor()}_${(v.lon / clusterBucketSize).floor()}';
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
                width: 26,
                height: 26,
                child: _buildVorClusterMarker(group, zoom),
              ),
            );
          }
        }

        if (mounted) {
          _vorMarkersNotifier.value = markers;
        }
      });
    });
  }

  Future<void> _loadNdbs() async {
    await NavRepository().loadNdbs();
    if (!mounted) return;
    setState(() {
      _ndbs = NavRepository().ndbs; // Ίδια ονομασία!
    });
  }

  List<Marker> _buildNdbDetailMarkers(List<Ndb> visible) {
    return visible.map((n) {
      return Marker(
        point: LatLng(n.lat, n.lon),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedMapObject = n;
              _selectedMapObjectType = 'ndb';
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(
                  painter: NdbMarkerPainter(
                    color: Colors.orange,
                    strokeColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xCC111111),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  n.ident,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _throttledUpdateNdbMarkers({bool force = false}) {
    if (_ndbUpdateThrottle?.isActive ?? false) return;

    _ndbUpdateThrottle = Timer(const Duration(milliseconds: 250), () {
      if (!_mapReady || !_showNDB || _ndbs.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final camera = mapController.camera;
        if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

        final zoom = camera.zoom;
        final bounds = camera.visibleBounds;

        if (!force && zoom == _lastNdbZoom && bounds == _lastNdbBounds) return;

        if (!force) {
          _lastNdbZoom = zoom;
          _lastNdbBounds = bounds;
        }

        const double hideZoom = 8.0;
        const double detailZoom = 11.0;
        const double clusterBucketSize = 2.0;

        if (zoom < hideZoom) {
          _ndbMarkersNotifier.value = [];
          return;
        }

        final visible =
            _ndbs.where((n) => bounds.contains(LatLng(n.lat, n.lon))).toList();

        final List<Marker> markers = [];

        if (zoom >= detailZoom) {
          markers.addAll(_buildNdbDetailMarkers(visible));
        } else {
          _ndbClusters.clear();

          for (final n in visible) {
            final key =
                '${(n.lat / clusterBucketSize).floor()}_${(n.lon / clusterBucketSize).floor()}';
            _ndbClusters.putIfAbsent(key, () => []).add(n);
          }

          for (final group in _ndbClusters.values) {
            final avgLat =
                group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
            final avgLon =
                group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;

            final bool isSingle = group.length == 1;
            final String countLabel =
                group.length > 9 ? '9+' : '${group.length}';

            markers.add(
              Marker(
                point: LatLng(avgLat, avgLon),
                width: 26,
                height: 26,
                child: IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isSingle ? 6 : 9,
                          height: isSingle ? 6 : 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orangeAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orangeAccent.withOpacity(0.95),
                                blurRadius: isSingle ? 8 : 10,
                                spreadRadius: isSingle ? 0.8 : 1.2,
                              ),
                            ],
                          ),
                        ),
                        if (!isSingle)
                          Text(
                            countLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }

        if (mounted) {
          _ndbMarkersNotifier.value = markers;
        }
      });
    });
  }

  Future<void> _loadRunways() async {
    await AirportDetailsRepository().loadRunways();
    if (!mounted) return;
    setState(() {
      _runways = AirportDetailsRepository().runways; // Ίδια ονομασία!
    });
  }

  List<Polyline> _buildRunwayPolylines(List<Runway> visible) {
    final zoom = mapController.camera.zoom;

    double getWidth(Runway r) {
      final base = (r.width / 8).clamp(3.0, 16.0);

      if (zoom < 11) return 0;
      if (zoom < 12) return base * 0.5;
      if (zoom < 13) return base * 0.7;
      if (zoom < 14) return base;
      return base * 1.2;
    }

    return visible.map((r) {
      return Polyline(
        points: [LatLng(r.end1Lat, r.end1Lon), LatLng(r.end2Lat, r.end2Lon)],
        strokeWidth: getWidth(r),
        color: _runwayColorForSurface(r.surface),
        borderStrokeWidth: zoom >= 13 ? 1.2 : 0.6,
        borderColor: Colors.black.withOpacity(0.4),
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

      if (!force && zoom == _lastParkingZoom && bounds == _lastParkingBounds) {
        return;
      }

      if (!force) {
        _lastParkingZoom = zoom;
        _lastParkingBounds = bounds;
      }

      // hide below detail zoom
      if (zoom < 15.0) {
        _parkingMarkersNotifier.value = [];
        return;
      }

      final visible =
          _parkings.where((p) {
            return bounds.contains(LatLng(p.lat, p.lon));
          }).toList();

      final List<Marker> markers = [];

      for (final p in visible) {
        markers.add(
          Marker(
            point: LatLng(p.lat, p.lon),
            width: 26,
            height: 26,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMapObject = p;
                  _selectedMapObjectType = 'parking';
                });
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

      _parkingMarkersNotifier.value = markers;
    });
  }

  Future<void> _loadParking() async {
    await AirportDetailsRepository().loadParking();
    if (!mounted) return;
    setState(() {
      // Κρατάμε και τις δύο μεταβλητές σου αν τις χρησιμοποιείς και τις δύο
      _parkings = AirportDetailsRepository().parkingSpots;
      _parkingSpots = AirportDetailsRepository().parkingSpots;
    });
  }

  Future<void> _loadWaypoints() async {
    final repo = WaypointRepository();
    await repo.load(); // Αυτό πλέον δεν θα σου "παγώνει" την οθόνη!

    if (!mounted) return;

    setState(() {
      _waypoints = repo.waypoints;
    });
  }

  void _throttledUpdateWaypointMarkers({bool force = false}) {
    if (_waypointThrottle?.isActive ?? false) return;

    _waypointThrottle = Timer(const Duration(milliseconds: 250), () {
      if (!_mapReady || !_showWaypoints || _waypoints.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final camera = mapController.camera;
        if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

        final zoom = camera.zoom;
        final bounds = camera.visibleBounds;

        if (!force &&
            zoom == _lastWaypointZoom &&
            _lastWaypointBounds == bounds) {
          return;
        }

        if (!force) {
          _lastWaypointZoom = zoom;
          _lastWaypointBounds = bounds;
        }

        const double hideZoom = 9.0;
        const double detailZoom = 12.0;
        const double clusterBucketSize = 1.6;

        if (zoom < hideZoom) {
          _waypointMarkersNotifier.value = [];
          return;
        }

        final visible =
            _waypoints
                .where((w) => bounds.contains(LatLng(w.lat, w.lon)))
                .toList();

        final List<Marker> markers = [];

        if (zoom >= detailZoom) {
          for (final w in visible) {
            final showLabel = zoom >= 13.0;

            markers.add(
              Marker(
                point: LatLng(w.lat, w.lon),
                width: showLabel ? 64 : 24,
                height: showLabel ? 34 : 24,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMapObject = w;
                      _selectedMapObjectType = 'waypoint';
                    });
                  },
                  child: SizedBox(
                    width: showLabel ? 64 : 24,
                    height: showLabel ? 34 : 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.cyanAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.95),
                                blurRadius: 8,
                                spreadRadius: 0.8,
                              ),
                            ],
                          ),
                        ),
                        if (showLabel)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 60),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xCC111111),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(0.45),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                w.ident,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        } else {
          _waypointClusters.clear();

          for (final w in visible) {
            final key =
                '${(w.lat / clusterBucketSize).floor()}_${(w.lon / clusterBucketSize).floor()}';
            _waypointClusters.putIfAbsent(key, () => []).add(w);
          }

          for (final group in _waypointClusters.values) {
            final avgLat =
                group.map((e) => e.lat).reduce((a, b) => a + b) / group.length;
            final avgLon =
                group.map((e) => e.lon).reduce((a, b) => a + b) / group.length;

            final bool isSingle = group.length == 1;
            final String countLabel =
                group.length > 9 ? '9+' : '${group.length}';

            markers.add(
              Marker(
                point: LatLng(avgLat, avgLon),
                width: 24,
                height: 24,
                child: IgnorePointer(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isSingle ? 5 : 8,
                          height: isSingle ? 5 : 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.cyanAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.95),
                                blurRadius: isSingle ? 8 : 10,
                                spreadRadius: isSingle ? 0.8 : 1.2,
                              ),
                            ],
                          ),
                        ),
                        if (!isSingle)
                          Text(
                            countLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        }

        if (mounted) {
          _waypointMarkersNotifier.value = markers;
        }
      });
    });
  }

  Future<void> _loadAirportFrequencies() async {
    await FrequencyRepository().load();
    if (!mounted) return;
    setState(() {
      _frequencies = FrequencyRepository().allFrequencies; // Ίδια ονομασία!
      _freqByIcao = FrequencyRepository().freqByIcao; // Ίδια ονομασία!
    });
  }

  Future<void> _loadAirways() async {
    final repo = AirwayRepository();
    await repo.load();

    if (!mounted) return;

    setState(() {
      _airways = repo.segments;
    });
  }

  void _throttledUpdateAirways({bool force = false}) {
    if (_airwayThrottle?.isActive ?? false) return;

    _airwayThrottle = Timer(const Duration(milliseconds: 250), () {
      if (!_mapReady || !_showAirways || _airways.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final camera = mapController.camera;
        if (camera.zoom.isNaN || camera.visibleBounds.north == 0) return;

        final zoom = camera.zoom;
        final bounds = camera.visibleBounds;

        if (!force && zoom == _lastAirwayZoom && bounds == _lastAirwayBounds) {
          return;
        }

        if (!force) {
          _lastAirwayZoom = zoom;
          _lastAirwayBounds = bounds;
        }

        const double hideZoom = 7.5;
        const double labelZoom = 9.2;

        final int labelEvery =
            zoom >= 11.5
                ? 3
                : zoom >= 10.5
                ? 4
                : zoom >= 9.5
                ? 6
                : 8;

        if (zoom < hideZoom) {
          _airwayPolylinesNotifier.value = [];
          _airwayLabelsNotifier.value = [];
          return;
        }

        final visible =
            _airways.where((a) {
              final from = LatLng(a.fromLat, a.fromLon);
              final to = LatLng(a.toLat, a.toLon);

              return bounds.contains(from) || bounds.contains(to);
            }).toList();

        final newPolylines = <Polyline>[];
        final newLabels = <Marker>[];

        // Prevent label spam for the same airway in the same viewport bucket.
        final placedLabelKeys = <String>{};

        for (int i = 0; i < visible.length; i++) {
          final a = visible[i];
          final from = LatLng(a.fromLat, a.fromLon);
          final to = LatLng(a.toLat, a.toLon);

          newPolylines.add(
            Polyline(
              points: [from, to],
              strokeWidth: zoom >= 10.5 ? 1.8 : 1.1,
              color: _airwayColor(a),
            ),
          );

          if (zoom < labelZoom) continue;

          final airwayName = a.airwayName.trim();
          if (airwayName.isEmpty) continue;

          // Label every few segments only, so the map stays readable.
          if (i % labelEvery != 0) continue;

          final mid = LatLng(
            (from.latitude + to.latitude) / 2,
            (from.longitude + to.longitude) / 2,
          );

          // Bucket labels so same airway doesn’t repeat too tightly together.
          final bucketKey =
              '${airwayName}_'
              '${(mid.latitude * 2).floor()}_'
              '${(mid.longitude * 2).floor()}';

          if (placedLabelKeys.contains(bucketKey)) continue;
          placedLabelKeys.add(bucketKey);

          newLabels.add(
            Marker(
              point: mid,
              width: 64,
              height: 22,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1A1A1A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _airwayColor(a).withOpacity(0.8),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      airwayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _airwayColor(a),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        _airwayPolylinesNotifier.value = newPolylines;
        _airwayLabelsNotifier.value = newLabels;
      });
    });
  }

  Color _airwayColor(AirwaySegment a) {
    switch ((a.airwayType ?? '').toUpperCase()) {
      case 'V':
        return Colors.cyanAccent.withOpacity(0.65);
      case 'J':
        return Colors.deepPurpleAccent.withOpacity(0.70);
      default:
        return Colors.white70.withOpacity(0.55);
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
      {'delay': 2400, 'fn': _loadAirways},
      {'delay': 2800, 'fn': _loadAirportFrequencies},
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

  String? _detectRunway(
    LatLng pos, {
    double? headingOverride,
    bool requireOnRunway = false,
    double airportRadiusMeters = 5000,
    double runwayDistanceMeters = 1200,
    double headingTolerance = 35,
  }) {
    if (simData == null) return null;
    if (requireOnRunway && !simData!.onRunway) return null;

    final currentIcao = _detectCurrentAirportIcao(pos);
    if (currentIcao == null) return null;

    final airportPos = _airportCoords[currentIcao];
    if (airportPos == null) return null;

    final distance = const Distance();
    final aircraftHeading = headingOverride ?? simData!.heading;

    String? bestIdent;
    double bestScore = double.infinity;

    for (final rwy in _runways) {
      final mid = _runwayMidpoint(rwy);

      final airportDist = distance.as(LengthUnit.Meter, mid, airportPos);
      if (airportDist > airportRadiusMeters) continue;

      final runwayDist = distance.as(LengthUnit.Meter, pos, mid);
      if (runwayDist > runwayDistanceMeters) continue;

      final d1 = _headingDiff(aircraftHeading, rwy.end1Heading);
      final d2 = _headingDiff(aircraftHeading, rwy.end2Heading);

      final headingDiff = min(d1, d2);
      final ident = d1 <= d2 ? rwy.end1Ident : rwy.end2Ident;

      final headingPenalty =
          headingDiff <= headingTolerance
              ? headingDiff * 15.0
              : 1000.0 + headingDiff * 25.0;

      final score = runwayDist + headingPenalty;

      if (score < bestScore) {
        bestScore = score;
        bestIdent = ident;
      }
    }

    if (bestIdent != null) {
      print(
        "🛫🛬 Runway detected: $currentIcao RWY $bestIdent "
        "(score=${bestScore.toStringAsFixed(1)})",
      );
    }

    return bestIdent;
  }

  String? _detectRunwayStrict(LatLng pos) {
    return _detectRunway(
      pos,
      requireOnRunway: true,
      runwayDistanceMeters: 900,
      headingTolerance: 20,
    );
  }

  String? _detectRunwayRelaxed(LatLng pos) {
    return _detectRunway(
      pos,
      requireOnRunway: false,
      runwayDistanceMeters: 1200,
      headingTolerance: 45,
    );
  }

  String? _resolveArrivalRunway() {
    if (_landingSnapshot?.runway != null &&
        _landingSnapshot!.runway!.trim().isNotEmpty) {
      return _landingSnapshot!.runway;
    }

    if (_landingSnapshot?.position != null) {
      final retry = _detectRunway(
        _landingSnapshot!.position,
        requireOnRunway: false,
        runwayDistanceMeters: 900,
        headingTolerance: 35,
      );
      if (retry != null && retry.trim().isNotEmpty) {
        return retry;
      }
    }

    if (simData != null) {
      final endPos = LatLng(simData!.latitude, simData!.longitude);
      final retry = _detectRunway(
        endPos,
        requireOnRunway: false,
        runwayDistanceMeters: 1200,
        headingTolerance: 45,
      );
      if (retry != null && retry.trim().isNotEmpty) {
        return retry;
      }
    }

    if (_trail.isNotEmpty) {
      final retry = _detectRunway(
        _trail.last,
        requireOnRunway: false,
        runwayDistanceMeters: 1200,
        headingTolerance: 45,
      );
      if (retry != null && retry.trim().isNotEmpty) {
        return retry;
      }
    }

    return null;
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

  List<LatLng> _buildDisplayedRoute() {
    final f = _currentFlight;
    if (f == null) return const [];

    final custom = _buildCustomRoute();

    if (custom.length >= 2) {
      return custom;
    }

    if (f.originLat != null &&
        f.originLng != null &&
        f.destinationLat != null &&
        f.destinationLng != null) {
      return [
        LatLng(f.originLat!, f.originLng!),
        LatLng(f.destinationLat!, f.destinationLng!),
      ];
    }

    final origin =
        f.originIcao == 'LIVEPOS'
            ? (f.originLat != null && f.originLng != null
                ? LatLng(f.originLat!, f.originLng!)
                : null)
            : _airportCoords[f.originIcao];

    final destination = _airportCoords[f.destinationIcao];

    if (origin != null && destination != null) {
      return [origin, destination];
    }

    return const [];
  }

  List<LatLng> _buildCustomRoute() {
    final f = _currentFlight;
    if (f == null) return const [];

    final List<LatLng> points = [];

    if (f.originLat != null && f.originLng != null) {
      points.add(LatLng(f.originLat!, f.originLng!));
    }

    final wp = f.waypoints;
    if (wp != null && wp.isNotEmpty) {
      for (final Waypoint w in wp) {
        if (w.lat == 0.0 && w.lon == 0.0) continue;
        points.add(LatLng(w.lat, w.lon));
      }
    }

    if (f.destinationLat != null && f.destinationLng != null) {
      points.add(LatLng(f.destinationLat!, f.destinationLng!));
    }

    return points;
  }

  Future<bool> _finalizeAndUploadFlight() async {
    if (!_inFlight) return false;

    final s = simData;
    if (s == null) return false;

    if (!s.onGround) return false;
    if (s.airspeed > 8) return false;

    final detectedIdent = _detectRunwayStrict(LatLng(s.latitude, s.longitude));
    final matchedRunway = _getRunwayByIdent(detectedIdent);
    final surface = matchedRunway?.surface.trim().toUpperCase() ?? '';
    final bool softField = surface == 'G' || surface == 'D' || surface == 'GR';

    if (!isHelicopter && !softField && s.onRunway) return false;

    final prefs = await SharedPreferences.getInstance();
    _endTime = DateTime.now();

    if (!_flightQualified) {
      debugPrint("🛑 Flight ended but NEVER QUALIFIED — discarding");
      await _cleanupFlight(prefs);
      return false;
    }

    if (_startTime == null) {
      await _cleanupFlight(prefs);
      return false;
    }

    DistanceTracker.stop();
    final distanceNm = DistanceTracker.getNm();
    final flightDuration = _endTime!.difference(_startTime!).inMinutes;

    print(
      '[SkyCase] FINALIZE | distanceNm=$distanceNm | '
      'duration=$flightDuration | maxAlt=$_maxAltitude',
    );

    final jobId = prefs.getString('flight_job_id');
    final flightType = jobId != null ? 'job' : 'free';

    final LatLng? endLatLng = _trail.isNotEmpty ? _trail.last : currentLatLng;

    _runwayUsedArrival = _resolveArrivalRunway();

    String? finalParkingEnd = _parkingEnd;

    if ((finalParkingEnd == null || finalParkingEnd.isEmpty) &&
        simData != null &&
        _landingSnapshot != null &&
        _canDetectParking(simData!)) {
      final endPos = LatLng(simData!.latitude, simData!.longitude);

      finalParkingEnd = detectParkingSpot(
        endPos,
        icao: _landingSnapshot!.icao ?? '',
        requireFullyParked: true,
        maxDistanceMeters: 600,
      );
    }

    print('[SkyCase] ✈️ Arrival Runway: ${_runwayUsedArrival ?? 'NONE'}');
    print('[SkyCase] 🅿️ Parking Spot: ${finalParkingEnd ?? 'NONE'}');

    final userId = prefs.getString('user_id') ?? '';

    final avgAirspeed =
        _airspeedSamples > 0 ? (_airspeedSum / _airspeedSamples) : 0;

    final startLoc = _toAirportLocation(
      _startPoint,
    )?.copyWith(runway: _runwayUsedDeparture, parking: _parkingStart);

    final endLoc = _toAirportLocation(
      endLatLng,
    )?.copyWith(runway: _runwayUsedArrival, parking: finalParkingEnd);

    final finalDistanceNm =
        distanceNm < 1.0
            ? double.parse(distanceNm.toStringAsFixed(4))
            : distanceNm;

    final turbCounts = {
      'moderate':
          _turbulenceEvents.where((e) => e.severity == 'moderate').length,
      'severe': _turbulenceEvents.where((e) => e.severity == 'severe').length,
    };
    final landing2d = _buildLanding2dPayload();

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
      events: {
        'turbulenceCount': turbCounts,
        'butterScore': _butterScore,
        'takeoffScore': _takeoffScore,
        'hardLanding': _hardLanding,
        'touchdownVerticalSpeed': _lastTouchdownVs,
        'takeoffPitch': _lastTakeoffPitch,
      },
      trail: _backendTrail.map((e) => FlightTrailPoint.fromJson(e)).toList(),
      landing2d: landing2d,
      type: flightType,
      jobId: jobId,
    );

    print('[DEBUG] endLoc.toJson() = ${endLoc?.toJson()}');
    print('[DEBUG] log.endLocation?.parking = ${log.endLocation?.parking}');
    print('[SkyCase] 📤 Uploading log:');
    print(jsonEncode(log.toJson()));

    if (endLoc?.icao.isNotEmpty == true) {
      await prefs.setString('last_destination_icao', endLoc!.icao);
    }

    final newFlightId = await FlightLogService.uploadFlightLog(log);

    if (newFlightId == null) {
      print("❌ Flight log upload failed — preserving flight state");
      showHudMessage("❌ Flight log upload failed");
      return false;
    }

    _inFlight = false;
    _flightSessionActive = false;
    await prefs.setBool('in_flight', false);

    _pulseController.stop();
    DistanceTracker.stop();

    final aircraftUuid = prefs.getString("current_aircraft_uuid");

    if (aircraftUuid != null && flightDuration > 0) {
      await AircraftService.addHours(
        aircraftUuid: aircraftUuid,
        minutes: flightDuration,
      );

      print("⏱️ Added $flightDuration min to aircraft $aircraftUuid");
    }

    if (jobId != null) {
      await DispatchService.completeJob(jobId, userId);

      showHudMessage(
        "🛬 Arrived at ${_landingSnapshot?.icao ?? 'destination'}",
      );

      await Future.delayed(const Duration(seconds: 1));
      showHudMessage("🎉 Dispatch Job Completed!");
    }

    if (mounted) {
      await _showFlightSummaryDialog(log, startLoc, endLoc);
      await context.read<UserProvider>().refreshProfile();
    }

    await _cleanupFlight(prefs);
    return true;
  }

  GroundPhase? _computePhase(SimLinkData d) {
    final double speed = d.airspeed;

    final bool nearlyStill = speed < 2.0;
    final bool slowMove = speed >= 2.0 && speed < 15.0;
    final bool fastGroundMove = speed >= 15.0;

    // -----------------------------
    // AIRBORNE
    // -----------------------------
    if (!d.onGround) {
      return GroundPhase.airborne;
    }

    // -----------------------------
    // TAKEOFF
    // Only when actually rolling on runway
    // -----------------------------
    if (d.onRunway && fastGroundMove) {
      return GroundPhase.takeoff;
    }

    // -----------------------------
    // PUSHBACK
    // Real pushback only:
    // moving slowly, engines off, brake released
    // -----------------------------
    if (slowMove && !d.combustion && !d.parkingBrake) {
      return GroundPhase.pushback;
    }

    // -----------------------------
    // TAXI
    // powered movement on ground
    // -----------------------------
    if ((slowMove || fastGroundMove) && d.combustion && !d.parkingBrake) {
      return GroundPhase.taxi;
    }

    // -----------------------------
    // STOPPED
    // holding short / paused / waiting
    // not final parked
    // -----------------------------
    if (nearlyStill && d.combustion && !d.parkingBrake && d.onGround) {
      return GroundPhase.stopped;
    }

    // -----------------------------
    // PARKED is NOT returned here.
    // Final parked should only come from
    // confirmed shutdown / end-flight logic.
    // -----------------------------
    return null;
  }

  bool _canDetectParking(SimLinkData d) {
    if (!d.onGround) return false;
    if (d.onRunway) return false;
    if (!d.parkingBrake) return false;
    if (d.airspeed >= 1.0) return false;
    if (_lastLandedEventTime == null) return false;

    // must have actually landed recently / this session
    final sinceLanding = DateTime.now().difference(_lastLandedEventTime!);
    if (sinceLanding.inSeconds < 15) return false;

    return true;
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

  bool _showGroundOpsManually = false;

  bool get _isAvatarGroundOps => simData?.isAvatar ?? false;
  bool get _shouldShowGroundOps => _isAvatarGroundOps || _showGroundOpsManually;
  bool get _groundOpsMinimalView =>
      _showGroundOpsManually && !_isAvatarGroundOps;

  double getBusVolts() {
    final v = simData?.mainBusVolts;

    if (v == null || v.isNaN || v <= 1) {
      return 28.0; // fallback for unsupported aircraft
    }

    return v;
  }

  String? _phaseHudMessage(GroundPhase phase) {
    switch (phase) {
      case GroundPhase.pushback:
        return "↩️ Pushback";
      case GroundPhase.taxi:
        return "🚕 Taxi";
      case GroundPhase.stopped:
        return "⏸ Stopped";
      case GroundPhase.takeoff:
        return "🛫 Takeoff";
      case GroundPhase.airborne:
        return "✈️ Airborne";
      case GroundPhase.landed:
        return "🛬 Landed";
      case GroundPhase.parked:
        return "🅿️ Parked";
    }
  }

  Future<void> _updateMeaningfulPhase(
    SimLinkData data,
    GroundPhase? rawPhase,
    DateTime now,
  ) async {
    const holdMs = 2200;

    if (rawPhase == null) {
      _pendingPhase = null;
      _pendingPhaseSince = null;
      return;
    }

    if (rawPhase != GroundPhase.airborne && rawPhase != GroundPhase.landed) {
      _pendingPhase = null;
      _pendingPhaseSince = null;
      return;
    }

    // keep the rest only if you still want the existing debounce logic
  }

  void _showPoiInfo(Poi poi) {
    final user = context.read<UserProvider>().user;
    final visited = user?.stats.visitedPois ?? const <String>[];
    final isVisited = visited.contains(poi.id);
    final visits = user?.stats.poiVisitCounts[poi.id] ?? 0;
    final loiterMinutes = user?.stats.poiTotalLoiterMinutes[poi.id] ?? 0.0;

    showGeneralDialog(
      context: context,
      barrierLabel: "POI Info",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 700;
        final double panelWidth = isMobile ? screenWidth * 0.94 : 430;

        final Color typeColor = poiColorForType(poi.type);

        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                height: double.infinity,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(-4, 0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: typeColor.withOpacity(0.18),
                              child: Icon(
                                poiIconForType(poi.type),
                                color: typeColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    poi.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    [
                                      if (poi.country != null) poi.country!,
                                      if (poi.era != null) poi.era!,
                                    ].join(' • '),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isVisited
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isVisited
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                            ),
                          ),
                          child: Text(
                            isVisited ? 'Visited' : 'Not visited yet',
                            style: TextStyle(
                              color:
                                  isVisited
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (poi.shortDescription.isNotEmpty) ...[
                          Text(
                            poi.shortDescription,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        Text(
                          poi.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),

                        const SizedBox(height: 18),
                        Divider(color: Colors.white24),
                        const SizedBox(height: 12),

                        _infoRow('Type', poi.type),
                        _infoRow(
                          'Coordinates',
                          '${poi.lat.toStringAsFixed(4)}, ${poi.lng.toStringAsFixed(4)}',
                        ),
                        _infoRow('Visits', '$visits'),
                        _infoRow(
                          'Loiter Time',
                          '${loiterMinutes.toStringAsFixed(1)} min',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleSideMenu() {
    if (!mounted) return;
    setState(() => _showSideMenu = !_showSideMenu);
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    bool closeMenuOnTap = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle:
          subtitle == null
              ? null
              : Text(subtitle, style: const TextStyle(color: Colors.white60)),
      onTap: () {
        onTap();

        if (closeMenuOnTap && mounted) {
          setState(() => _showSideMenu = false);
        }
      },
    );
  }

  Widget _buildMapSideMenu(BuildContext context) {
    final hasData = simData != null;
    final canUseGeneralButtons = battOn || isDataOffline;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      top: 0,
      bottom: 0,
      right: _showSideMenu ? 0 : -320,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // absorb taps so background tap-close does not fire
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.94),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 18,
                  offset: Offset(-4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Map Menu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleSideMenu,
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (canUseGeneralButtons) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.layers_outlined,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Map Style',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Row(
                              children: List.generate(tileLayers.length, (
                                index,
                              ) {
                                final isSelected = _mapStyleIndex == index;
                                final option = tileLayers[index];

                                Color activeColor;
                                switch (option.name.toLowerCase()) {
                                  case 'skycase dark':
                                    activeColor = Colors.cyanAccent;
                                    break;
                                  case 'skycase light':
                                    activeColor = Colors.blueAccent;
                                    break;
                                  default:
                                    activeColor = Colors.cyanAccent;
                                }

                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          index < tileLayers.length - 1 ? 6 : 0,
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () async {
                                        if (_mapStyleIndex == index) return;

                                        setState(() {
                                          _mapStyleIndex = index;
                                        });
                                        _refreshLiveMapVisuals();

                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setInt(_mapStyleKey, index);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? activeColor.withOpacity(
                                                    0.14,
                                                  )
                                                  : Colors.white.withOpacity(
                                                    0.03,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color:
                                                isSelected
                                                    ? activeColor
                                                    : Colors.white10,
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              option.name,
                                              maxLines: 1,
                                              softWrap: false,
                                              style: TextStyle(
                                                color:
                                                    isSelected
                                                        ? activeColor
                                                        : Colors.white70,
                                                fontSize: 12,
                                                fontWeight:
                                                    isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                        ],

                        if (canUseGeneralButtons)
                          _menuTile(
                            icon: Icons.home_outlined,
                            title: 'Return Home',
                            onTap: () async {
                              await _saveTrail(_trail);
                              if (!mounted) return;
                              Navigator.pop(context);
                            },
                          ),

                        if (canUseGeneralButtons)
                          _menuTile(
                            icon: Icons.search,
                            title: 'ICAO Search',
                            onTap: () {
                              _openIcaoSearchDialog();
                            },
                          ),

                        if (_isConnected &&
                            hasData &&
                            (battOn || isDataOffline))
                          _menuTile(
                            icon: Icons.cloud_outlined,
                            title: _showMetar ? 'Hide METAR' : 'Show METAR',
                            closeMenuOnTap: false,
                            onTap: () {
                              setState(() => _showMetar = !_showMetar);
                            },
                          ),

                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                          child: Text(
                            'Filters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 1),

                        _menuTile(
                          icon: Icons.flight,
                          iconColor:
                              _filterBig ? Colors.cyanAccent : Colors.white70,
                          title: _filterBig ? 'Hide Airports' : 'Show Airports',
                          subtitle: 'Show normal airports',
                          closeMenuOnTap: false,
                          onTap: () {
                            setState(() => _filterBig = !_filterBig);
                            _throttledUpdateAirportMarkers(force: true);
                          },
                        ),

                        _menuTile(
                          icon: Icons.airplane_ticket,
                          iconColor:
                              _filterHeli
                                  ? Colors.orangeAccent
                                  : Colors.white70,
                          title:
                              _filterHeli ? 'Hide Heliports' : 'Show Heliports',
                          subtitle: 'Show heliports',
                          closeMenuOnTap: false,
                          onTap: () {
                            setState(() => _filterHeli = !_filterHeli);
                            _throttledUpdateAirportMarkers(force: true);
                          },
                        ),

                        _menuTile(
                          icon: Icons.linear_scale,
                          iconColor:
                              _showRunways
                                  ? Colors.yellowAccent
                                  : Colors.white70,
                          title: _showRunways ? 'Hide Runways' : 'Show Runways',
                          closeMenuOnTap: false,
                          onTap: () {
                            setState(() => _showRunways = !_showRunways);
                            _throttledUpdateRunwayPolylines();
                          },
                        ),

                        _menuTile(
                          icon: Icons.route,
                          iconColor:
                              _showGround
                                  ? Colors.orangeAccent
                                  : Colors.white70,
                          title:
                              _showGround ? 'Hide Taxiways' : 'Show Taxiways',
                          subtitle: 'Show taxiway lines on map',
                          closeMenuOnTap: false,
                          onTap: () {
                            final next = !_showGround;

                            setState(() {
                              _showGround = next;

                              if (!next) {
                                _groundSegments = [];
                                _groundPolylines = [];
                                _groundLabels = [];
                                _groundLabelMarkersNotifier.value = [];
                              }
                            });

                            if (next) {
                              _updateGroundOverlayFromMapCenter();
                            }
                          },
                        ),

                        _menuTile(
                          icon: Icons.local_parking,
                          iconColor:
                              _showParking
                                  ? Colors.greenAccent
                                  : Colors.white70,
                          title: _showParking ? 'Hide Parking' : 'Show Parking',
                          closeMenuOnTap: false,
                          onTap: () {
                            final next = !_showParking;

                            setState(() => _showParking = next);

                            if (!next) {
                              // 🔥 turn OFF → clear immediately
                              _parkingMarkersNotifier.value = [];
                            } else {
                              // 🔥 turn ON → force rebuild of parking layer
                              _throttledUpdateParkingMarkers(force: true);
                            }
                          },
                        ),

                        _menuTile(
                          icon: Icons.radar,
                          iconColor:
                              _showVOR ? Colors.purpleAccent : Colors.white70,
                          title: _showVOR ? 'Hide VOR' : 'Show VOR',
                          closeMenuOnTap: false,
                          onTap: () {
                            final next = !_showVOR;

                            setState(() => _showVOR = next);

                            if (!next) {
                              _vorMarkersNotifier.value = [];
                            } else {
                              _throttledUpdateVorMarkers(force: true);
                            }
                          },
                        ),

                        _menuTile(
                          icon: Icons.wifi_tethering,
                          iconColor:
                              _showNDB
                                  ? Colors.deepOrangeAccent
                                  : Colors.white70,
                          title: _showNDB ? 'Hide NDB' : 'Show NDB',
                          closeMenuOnTap: false,
                          onTap: () {
                            final next = !_showNDB;

                            setState(() => _showNDB = next);

                            if (!next) {
                              _ndbMarkersNotifier.value = [];
                            } else {
                              _throttledUpdateNdbMarkers(force: true);
                            }
                          },
                        ),

                        _menuTile(
                          icon: Icons.alt_route,
                          iconColor:
                              _showWaypoints
                                  ? Colors.lightBlueAccent
                                  : Colors.white70,
                          title:
                              _showWaypoints
                                  ? 'Hide Waypoints'
                                  : 'Show Waypoints',
                          closeMenuOnTap: false,
                          onTap: () {
                            final next = !_showWaypoints;

                            setState(() => _showWaypoints = next);

                            if (!next) {
                              _waypointMarkersNotifier.value = [];
                            } else {
                              _throttledUpdateWaypointMarkers(force: true);
                            }
                          },
                        ),

                        _menuTile(
                          icon: Icons.alt_route,
                          title: _showAirways ? 'Hide Airways' : 'Show Airways',
                          subtitle: 'Victor / jet route segments',
                          iconColor:
                              _showAirways ? Colors.cyanAccent : Colors.white,
                          closeMenuOnTap: false,
                          onTap: () {
                            final next = !_showAirways;

                            setState(() {
                              _showAirways = next;
                            });

                            if (!next) {
                              _airwayPolylinesNotifier.value = [];
                              _airwayLabelsNotifier.value = [];
                            }
                            if (next) {
                              _throttledUpdateAirways(force: true);
                            }
                          },
                        ),

                        if (canUseGeneralButtons)
                          _menuTile(
                            icon: _showAllFlights ? Icons.route : Icons.history,
                            iconColor:
                                _showAllFlights
                                    ? Colors.indigoAccent
                                    : Colors.white70,
                            title:
                                _showAllFlights
                                    ? 'Hide Flight History'
                                    : 'Show Flight History',
                            closeMenuOnTap: false,
                            onTap: () async {
                              if (_showAllFlights) {
                                setState(() => _showAllFlights = false);
                                return;
                              }

                              if (_flightLogs.isEmpty) {
                                await _loadAllFlightLogs();
                              }

                              if (!mounted) return;
                              setState(() => _showAllFlights = true);
                            },
                          ),

                        if (canUseGeneralButtons)
                          _menuTile(
                            icon: _showPoi ? Icons.public : Icons.public_off,
                            iconColor:
                                _showPoi
                                    ? Colors.lightGreenAccent
                                    : Colors.white70,
                            title: _showPoi ? 'Hide POI' : 'Show POI',
                            closeMenuOnTap: false,
                            onTap: () {
                              setState(() => _showPoi = !_showPoi);
                            },
                          ),

                        FutureBuilder<bool>(
                          future: NavigraphPrefs.getHasPremium(),
                          builder: (context, snapshot) {
                            final hasPremium = snapshot.data ?? false;

                            if (!hasPremium) return const SizedBox.shrink();
                            if (Platform.isWindows) {
                              return const SizedBox.shrink();
                            }

                            if (!battOn || !isDataOffline) {
                              return const SizedBox.shrink();
                            }

                            return _menuTile(
                              icon: Icons.map_outlined,
                              title: 'Open Navigraph',
                              closeMenuOnTap: false,
                              iconColor: Colors.blueGrey,
                              onTap: () {
                                _openNavigraphSheet(context);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _flightPlanPanel(BuildContext context) {
    if (_currentFlight == null) return const SizedBox.shrink();

    final bool mobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: mobile ? 300 : 420,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: Colors.orangeAccent,
            size: 16,
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _inFlight
                      ? '${_currentFlight!.originIcao} → ${_currentFlight!.destinationIcao}'
                      : 'Flight Plan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _inFlight
                            ? '${_remainingNm.toStringAsFixed(1)} NM remaining'
                            : 'Tap for details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_inFlight && battOn && !batteryOnly) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _etaHud(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          _smallFlightIconButton(
            icon: Icons.info_outline,
            tooltip: 'Flight Info',
            onTap: () => _showFlightDialog(context),
          ),
          const SizedBox(width: 6),
          _smallFlightIconButton(
            icon: Icons.close,
            tooltip: 'Cancel Flight',
            color: Colors.redAccent,
            onTap: () => _cancelFlight(context, fromDialog: false),
          ),
        ],
      ),
    );
  }

  Widget _smallFlightIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  Widget _busOatPanel() {
    return Container(
      width: MediaQuery.of(context).size.width < 600 ? 300 : 420,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: (battOn && avionicsOn) ? 1.0 : 0.0,
                child: Text(
                  "BUS ${getBusVolts().toStringAsFixed(1)}V",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                "OAT ${simData!.weather.temperature.toStringAsFixed(0)}°C",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comRadioOverlay(SimLinkData d) {
    final bool avionics = d.avionicsOn;
    final bool tx = d.transmitting && avionics;

    return Opacity(
      opacity: avionics ? 1.0 : 0.35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "COM1",
              style: TextStyle(
                fontSize: 9,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatComFrequency(d.com1Active),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 24, 255, 236),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatComFrequency(d.com1Standby),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tx) ...[const SizedBox(width: 6), _txBlink()],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatComFrequency(double raw) {
    if (raw <= 0) return "---.---";

    double mhz;

    if (raw > 1e9) {
      mhz = raw / 1e7;
    } else if (raw > 1e8) {
      mhz = raw / 1e6;
    } else {
      mhz = raw;
    }

    return mhz.toStringAsFixed(3);
  }

  double _distanceNmToPoi(Poi poi) {
    final pos = currentLatLng;
    if (pos == null) return double.infinity;

    return _calculateDistanceNm(pos, LatLng(poi.lat, poi.lng));
  }

  double _bearingToPoi(Poi poi) {
    final pos = currentLatLng;
    if (pos == null) return 0;

    final lat1 = pos.latitude * pi / 180.0;
    final lon1 = pos.longitude * pi / 180.0;
    final lat2 = poi.lat * pi / 180.0;
    final lon2 = poi.lng * pi / 180.0;

    final dLon = lon2 - lon1;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final brng = atan2(y, x) * 180.0 / pi;
    return (brng + 360.0) % 360.0;
  }

  String _turnInstructionToPoi(Poi poi) {
    final heading = simData?.heading ?? 0.0;
    final bearing = _bearingToPoi(poi);

    double diff = (bearing - heading + 540) % 360 - 180;

    if (diff.abs() < 5) {
      return 'On course';
    }

    final dir = diff > 0 ? 'Turn right' : 'Turn left';
    return '$dir ${diff.abs().round()}°';
  }

  void _updateNearbyPoiAlert() {
    if (!_showPoi) {
      if (_nearbyPoiAlert != null) {
        setState(() => _nearbyPoiAlert = null);
      }
      return;
    }

    if (simData == null || simData!.onGround || currentLatLng == null) {
      if (_nearbyPoiAlert != null) {
        setState(() => _nearbyPoiAlert = null);
      }
      return;
    }

    if (_showSideMenu || _selectedMapObject != null) {
      return;
    }

    final visiblePois = visiblePoiForZoom(_currentZoom);
    if (visiblePois.isEmpty) return;

    Poi? bestPoi;
    double bestDist = double.infinity;

    for (final poi in visiblePois) {
      final dist = _distanceNmToPoi(poi);
      if (dist > _poiAlertRangeNm) continue;

      final dismissedAt = _dismissedPoiAlerts[poi.name];
      if (dismissedAt != null &&
          DateTime.now().difference(dismissedAt) < _poiAlertCooldown) {
        continue;
      }

      if (dist < bestDist) {
        bestDist = dist;
        bestPoi = poi;
      }
    }

    if (bestPoi == null) {
      if (_nearbyPoiAlert != null) {
        setState(() => _nearbyPoiAlert = null);
      }
      return;
    }

    if (_nearbyPoiAlert?.name != bestPoi.name) {
      setState(() {
        _nearbyPoiAlert = bestPoi;
        _lastPoiAlertTime = DateTime.now();
      });
    }
  }

  void _dismissNearbyPoiAlert() {
    final poi = _nearbyPoiAlert;
    if (poi == null) return;

    setState(() {
      _dismissedPoiAlerts[poi.name] = DateTime.now();
      _nearbyPoiAlert = null;
    });
  }

  Widget _buildNearbyPoiAlertCard() {
    final poi = _nearbyPoiAlert;
    if (poi == null) return const SizedBox.shrink();

    final distanceNm = _distanceNmToPoi(poi);
    final bearing = _bearingToPoi(poi);
    final turnText = _turnInstructionToPoi(poi);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      offset: Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: 1,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.86),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: poiColorForType(poi.type).withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: poiColorForType(poi.type).withOpacity(0.45),
                        ),
                      ),
                      child: Icon(
                        poiIconForType(poi.type),
                        size: 16,
                        color: poiColorForType(poi.type),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        poi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _dismissNearbyPoiAlert,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _poiInfoRow(
                  icon: Icons.straighten,
                  label: '${distanceNm.toStringAsFixed(1)} NM away',
                ),
                const SizedBox(height: 6),
                _poiInfoRow(
                  icon: Icons.explore_outlined,
                  label: 'Bearing ${bearing.round()}°',
                ),
                const SizedBox(height: 6),
                _poiInfoRow(
                  icon: Icons.turn_right,
                  label: turnText,
                  valueColor: Colors.cyanAccent,
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updatePoiProximityTimer() {
    final poi = _nearbyPoiAlert;
    final pos = currentLatLng;

    if (poi == null || pos == null || simData == null || simData!.onGround) {
      _activePoiTarget = null;
      _poiInsideSince = null;
      return;
    }

    final distanceNm = _distanceNmToPoi(poi);
    final insideZone = distanceNm <= _poiReachRadiusNm;

    if (!insideZone) {
      if (_activePoiTarget?.name == poi.name) {
        _activePoiTarget = null;
        _poiInsideSince = null;
      }
      return;
    }

    if (_confirmedPoiNames.contains(poi.name)) {
      return;
    }

    if (_activePoiTarget?.name != poi.name) {
      _activePoiTarget = poi;
      _poiInsideSince = DateTime.now();
      return;
    }

    if (_poiInsideSince == null) {
      _poiInsideSince = DateTime.now();
      return;
    }

    final heldFor = DateTime.now().difference(_poiInsideSince!);

    if (heldFor >= _requiredPoiHoldTime) {
      _confirmedPoiNames.add(poi.name);
      _activePoiTarget = null;
      _poiInsideSince = null;

      debugPrint('📍 POI confirmed internally: ${poi.name}');
    }
  }

  Widget _poiInfoRow({
    required IconData icon,
    required String label,
    Color valueColor = Colors.white70,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  List<Polyline> _buildGroundPolylines(List<TaxiwaySegment> segments) {
    final zoom = mapController.camera.zoom;

    return segments.map((s) {
      final isParking = s.type == 'PT' || s.type == 'P';
      final isConnector = s.type == 'C';

      double width;
      Color color;

      if (isParking) {
        width = zoom >= 15 ? 2.0 : 1.2;
        color = Colors.blueGrey.withOpacity(0.55);
      } else if (isConnector) {
        width = zoom >= 15 ? 2.8 : 1.8;
        color = Colors.amber.withOpacity(0.75);
      } else {
        width = zoom >= 15 ? 3.5 : 2.2;
        color = Colors.orangeAccent.withOpacity(0.9);
      }

      return Polyline(
        points: [s.start, s.end],
        strokeWidth: width,
        color: color,
        borderStrokeWidth: zoom >= 15 ? 0.7 : 0.3,
        borderColor: Colors.black.withOpacity(0.25),
      );
    }).toList();
  }

  List<Marker> _buildGroundLabelMarkers(List<TaxiwayLabel> labels) {
    final zoom = mapController.camera.zoom;

    if (!_showGroundLabels) return [];
    if (zoom < 13.0) return [];

    final filtered =
        labels
            .where((l) => l.name.trim().isNotEmpty)
            .where((l) => l.segmentCount >= 2)
            .toList();

    return filtered.map((l) {
      return Marker(
        point: l.position,
        width: 56,
        height: 22,
        child: IgnorePointer(
          child: Center(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xCC1A1A1A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.75),
                  width: 0.8,
                ),
              ),
              child: Text(
                l.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _updateGroundOverlayFromMapCenter() async {
    if (!_showGround) return;
    if (_loadingGround) return;
    if (!_mapReady) return;

    final zoom = mapController.camera.zoom;

    // Stricter zoom gate
    if (zoom < 13.8) {
      if (!mounted) return;

      setState(() {
        _groundSegments = [];
        _groundPolylines = [];
        _groundLabels = [];
      });

      _groundLabelMarkersNotifier.value = [];

      return;
    }

    final now = DateTime.now();
    final center = mapController.camera.center;

    const distance = Distance();

    final movedEnough =
        _lastGroundQueryPoint == null ||
        distance.as(LengthUnit.Meter, _lastGroundQueryPoint!, center) > 350;

    final waitedEnough =
        _lastGroundQueryTime == null ||
        now.difference(_lastGroundQueryTime!).inMilliseconds >= 2500;

    if (!movedEnough && !waitedEnough) {
      return;
    }

    _loadingGround = true;
    _lastGroundQueryPoint = center;
    _lastGroundQueryTime = now;

    try {
      final overlay = await GroundService.fetchAroundCenter(
        centerLat: center.latitude,
        centerLon: center.longitude,
        tileRadius: 1, // 3x3 max
      );

      if (!mounted) return;

      setState(() {
        _groundSegments = overlay.lines;
        _groundPolylines = _buildGroundPolylines(overlay.lines);
        _groundLabels = overlay.labels;
      });

      _groundLabelMarkersNotifier.value =
          _showGroundLabels ? _buildGroundLabelMarkers(overlay.labels) : [];
    } catch (e) {
      debugPrint('❌ Ground overlay fetch failed: $e');
    } finally {
      _loadingGround = false;
    }
  }

  Widget _buildSingleVorMarker(Vor v, double zoom) {
    final showLabel = zoom >= 11.5;
    final size = zoom >= 13 ? 24.0 : 20.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMapObject = v;
          _selectedMapObjectType = 'vor';
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: VorMarkerPainter(
                color: Colors.blueAccent,
                strokeColor: Colors.white,
              ),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xCC111111),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.5),
                  width: 0.7,
                ),
              ),
              child: Text(
                v.ident,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVorClusterMarker(List<Vor> group, double zoom) {
    final bool isSingle = group.length == 1;
    final String countLabel = group.length > 9 ? '9+' : '${group.length}';

    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSingle ? 6 : 9,
              height: isSingle ? 6 : 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.95),
                    blurRadius: isSingle ? 8 : 10,
                    spreadRadius: isSingle ? 0.8 : 1.2,
                  ),
                ],
              ),
            ),
            if (!isSingle)
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono',
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedObjectCard() {
    final accent = _selectedObjectAccent();

    String primary = '';
    List<Widget> details = [];

    if (_selectedMapObjectType == 'vor') {
      final v = _selectedMapObject as Vor;
      primary = v.ident;
      details = [
        _infoLine('Frequency', '${_formatVorFrequency(v.frequency)} MHz'),
      ];
    } else if (_selectedMapObjectType == 'ndb') {
      final n = _selectedMapObject as Ndb;
      primary = n.ident;
      details = [
        _infoLine('Frequency', '${_formatVorFrequency(n.frequency)} MHz'),
      ];
    } else if (_selectedMapObjectType == 'parking') {
      final p = _selectedMapObject as ParkingSpot;
      primary = '${p.name} ${p.number}';
      details = [
        _infoLine('ICAO', p.icao),
        _infoLine('Type', p.type),
        _infoLine('Jetway', p.hasJetway ? 'YES' : 'NO'),
      ];
    } else if (_selectedMapObjectType == 'waypoint') {
      final w = _selectedMapObject as Waypoint;
      primary = w.ident;
      details = [
        _infoLine('Type', w.type),
        _infoLine(
          'Coords',
          '${w.lat.toStringAsFixed(4)}, ${w.lon.toStringAsFixed(4)}',
        ),
      ];
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0B0F14).withOpacity(0.96),
              const Color(0xFF121922).withOpacity(0.94),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.35), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withOpacity(0.35)),
                  ),
                  child: Text(
                    _selectedObjectTitle(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _selectedMapObject = null;
                      _selectedMapObjectType = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              primary,
              style: TextStyle(
                color: accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 10),
            ...details,
          ],
        ),
      ),
    );
  }

  Color _selectedObjectAccent() {
    switch (_selectedMapObjectType) {
      case 'vor':
        return Colors.purpleAccent;
      case 'ndb':
        return Colors.deepOrangeAccent;
      case 'parking':
        return Colors.greenAccent;
      case 'waypoint':
        return Colors.lightBlueAccent;
      default:
        return Colors.white;
    }
  }

  String _selectedObjectTitle() {
    switch (_selectedMapObjectType) {
      case 'vor':
        return 'VOR';
      case 'ndb':
        return 'NDB';
      case 'parking':
        return 'PARKING';
      case 'waypoint':
        return 'WAYPOINT';
      default:
        return 'OBJECT';
    }
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSelectedObjectCard(BuildContext context) {
    _ensureInfoCardPosition(context);

    const cardWidth = 280.0;
    const cardHeightEstimate = 170.0;

    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _infoCardLeft += details.delta.dx;
          _infoCardTop += details.delta.dy;

          // clamp inside screen
          _infoCardLeft = _infoCardLeft.clamp(
            8.0,
            screenSize.width - cardWidth - 8.0,
          );

          _infoCardTop = _infoCardTop.clamp(
            70.0,
            screenSize.height - cardHeightEstimate - 8.0,
          );
        });
      },
      child: _buildSelectedObjectCard(),
    );
  }

  void _ensureInfoCardPosition(BuildContext context) {
    if (_infoCardInitialized) return;

    final screenWidth = MediaQuery.of(context).size.width;

    // Start near the top-right
    _infoCardLeft = screenWidth - 296; // card width + margin
    _infoCardTop = 110;
    _infoCardInitialized = true;
  }

  String _formatVorFrequency(dynamic raw) {
    if (raw == null) return '--';

    // Handle int (108600 → 108.600)
    if (raw is int) {
      return (raw / 1000).toStringAsFixed(3);
    }

    // Handle double already (108.6 → 108.600)
    if (raw is double) {
      return raw.toStringAsFixed(3);
    }

    // Handle string just in case
    final parsed = double.tryParse(raw.toString());
    if (parsed != null) {
      return parsed.toStringAsFixed(3);
    }

    return raw.toString();
  }

  Future<void> _resetLiveFlightVisuals() async {
    final prefs = await SharedPreferences.getInstance();

    _trail.clear();
    _backendTrail.clear();
    _turbulenceEvents.clear();
    _startPoint = null;
    _lastBackendTrailUpdate = null;
    _lastTurbTime = null;
    _pendingFlightEnd = false;
    _pendingEndTime = null;
    _currentFlight = null;

    await prefs.remove('flight_trail');
    await prefs.remove('turbulence_events');
    await prefs.remove('start_lat');
    await prefs.remove('start_lng');
    await prefs.remove('last_flight');

    if (mounted) setState(() {});
  }

  Future<void> _resetPlannedRouteOnly() async {
    final prefs = await SharedPreferences.getInstance();
    _currentFlight = null;
    _pendingFlightEnd = false;
    _pendingEndTime = null;
    await prefs.remove('last_flight');

    if (mounted) setState(() {});
  }

  Widget _buildCinematicHud() {
    if (_cinematicHudMessage == null) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _hudFxController,
        builder: (context, _) {
          final t = _hudFxController.value;

          final planeEnter = Curves.easeOutCubic.transform(
            Interval(0.00, 0.28).transform(t.clamp(0.0, 0.28) / 0.28),
          );

          final orbitT = ((t - 0.18) / 0.20).clamp(0.0, 1.0);
          final orbit = Curves.easeInOut.transform(orbitT);

          final circleT = ((t - 0.32) / 0.16).clamp(0.0, 1.0);

          // keep overshoot for visual growth
          final circleGrow = Curves.easeOutBack.transform(circleT);

          // safe opacity value
          final circleOpacity = Curves.easeOut
              .transform(circleT)
              .clamp(0.0, 1.0);

          final unwrapT = ((t - 0.45) / 0.28).clamp(0.0, 1.0);
          final unwrap = Curves.easeOutCubic.transform(unwrapT);

          final textT = ((t - 0.68) / 0.18).clamp(0.0, 1.0);
          final textOpacity = Curves.easeOut.transform(textT).clamp(0.0, 1.0);

          final baseLeft = 18.0;
          final baseTop = 92.0;

          final planeStartX = -56.0;
          final planeEndX = baseLeft + 22.0;
          final planeX = lerpDouble(planeStartX, planeEndX, planeEnter)!;

          final orbitRadius = 14.0 * (1.0 - unwrap);
          final orbitAngle = orbit * pi * 1.65;
          final orbitDx = sin(orbitAngle) * orbitRadius;
          final orbitDy = -cos(orbitAngle) * orbitRadius * 0.55;

          final containerWidth = lerpDouble(48, 320, unwrap)!;
          final containerOpacity =
              (((t - 0.34) / 0.18).clamp(0.0, 1.0)).toDouble();

          final planeScale = 1.0 - (circleGrow * 0.18);
          final planeOpacity = (1.0 - (unwrap * 0.18)).clamp(0.0, 1.0);

          return Stack(
            children: [
              Positioned(
                top: baseTop,
                left: baseLeft,
                child: Opacity(
                  opacity: containerOpacity,
                  child: Container(
                    width: containerWidth,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.86),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _cinematicHudAccent.withOpacity(0.72),
                        width: 1.25,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _cinematicHudAccent.withOpacity(0.16),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final panelWideEnough = constraints.maxWidth >= 170;
                        final showText = constraints.maxWidth >= 190;

                        return Row(
                          children: [
                            const SizedBox(width: 8),
                            Expanded(
                              child: Opacity(
                                opacity: circleOpacity,
                                child: Transform.scale(
                                  scale: circleGrow,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _cinematicHudAccent.withOpacity(
                                        0.14,
                                      ),
                                      border: Border.all(
                                        color: _cinematicHudAccent.withOpacity(
                                          0.95,
                                        ),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            if (panelWideEnough) const SizedBox(width: 12),

                            if (showText)
                              Expanded(
                                child: Opacity(
                                  opacity:
                                      textOpacity.clamp(0.0, 1.0).toDouble(),
                                  child: Transform.translate(
                                    offset: Offset(12 * (1 - textOpacity), 0),
                                    child: Text(
                                      _cinematicHudMessage ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            if (panelWideEnough) const SizedBox(width: 14),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: baseTop + 8 + orbitDy,
                left: planeX + orbitDx,
                child: Opacity(
                  opacity: planeOpacity.toDouble(),
                  child: Transform.scale(
                    scale: planeScale,
                    child: Icon(
                      _cinematicHudIcon ?? Icons.airplanemode_active,
                      color: _cinematicHudAccent,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleTakeoffEvent({
    required SimLinkData data,
    required DateTime now,
  }) async {
    final double pitch = data.pitch;
    final double takeoffScore = _calculateTakeoffScore(pitch);
    final String takeoffRating = takeoffGradeFromPitch(pitch);

    _recordedTakeoffPitch = pitch;
    _takeoffScore = takeoffScore;
    _lastTakeoffRating = takeoffRating;
    _lastTakeoffPitch = pitch;

    _livePhase = GroundPhase.airborne;
    _lastAnnouncedPhase = GroundPhase.airborne;

    await CockpitVibration.onPhaseChange(GroundPhase.airborne);

    showHudMessage(
      "Airborne",
      icon: Icons.flight_takeoff,
      accent: Colors.lightBlueAccent,
    );

    await _pushJobPhase('enroute');
  }

  Future<void> _handleLandingEvent({
    required SimLinkData data,
    required LatLng latlng,
    required DateTime now,
    required bool isHelicopter,
    required bool helicopterHasWheels,
  }) async {
    final bool canDetectRunway = !isHelicopter || helicopterHasWheels;

    final String? detectedRunway =
        canDetectRunway
            ? _detectRunway(
              latlng,
              requireOnRunway: false,
              runwayDistanceMeters: 900,
              headingTolerance: 35,
            )
            : null;

    final String? detectedIcao = _toAirportLocation(latlng)?.icao;

    _updateLandingSnapshot(
      latlng: latlng,
      now: now,
      detectedRunway: detectedRunway,
      detectedIcao: detectedIcao,
    );

    _captureTouchdownReplay(now);

    final double touchdownVs = data.verticalSpeed;
    final double butterScore = _calculateButterScore(touchdownVs);
    final bool hardLanding = touchdownVs.abs() > 500;

    _recordLandingMetrics(
      touchdownVs: touchdownVs,
      butterScore: butterScore,
      hardLanding: hardLanding,
    );

    _lastLandedEventTime = now;
    _livePhase = GroundPhase.landed;
    _lastAnnouncedPhase = GroundPhase.landed;

    await CockpitVibration.onPhaseChange(GroundPhase.landed);

    showHudMessage(
      "Landed",
      icon: Icons.flight_land,
      accent: Colors.lightGreenAccent,
    );

    await _pushJobPhase('arrived');
  }

  void _updateLandingSnapshot({
    required LatLng latlng,
    required DateTime now,
    required String? detectedRunway,
    required String? detectedIcao,
  }) {
    final LandingSnapshot? currentSnapshot = _landingSnapshot;

    if (currentSnapshot == null) {
      _landingSnapshot = LandingSnapshot(
        position: latlng,
        runway: detectedRunway,
        icao: detectedIcao,
        time: now,
      );
      return;
    }

    final bool snapshotMissingRunway =
        currentSnapshot.runway == null || currentSnapshot.runway!.isEmpty;

    final bool newRunwayAvailable =
        detectedRunway != null && detectedRunway.isNotEmpty;

    if (snapshotMissingRunway && newRunwayAvailable) {
      _landingSnapshot = LandingSnapshot(
        position: currentSnapshot.position,
        runway: detectedRunway,
        icao: currentSnapshot.icao ?? detectedIcao,
        time: currentSnapshot.time,
      );
    }
  }

  void _captureTouchdownReplay(DateTime now) {
    _touchdownTime = now;
    _landingReplayFinal
      ..clear()
      ..addAll(_landingReplayBuffer);
    _recordLandingRollout = true;
  }

  void _recordLandingMetrics({
    required double touchdownVs,
    required double butterScore,
    required bool hardLanding,
  }) {
    _lastTouchdownVs = touchdownVs;
    _butterScore = butterScore;
    _hardLanding = hardLanding;
    _lastLandingRating = butterGradeFromVs(touchdownVs);
  }

  String butterGradeFromVs(double touchdownVs) {
    final vs = touchdownVs.abs();

    if (vs < 80) return 'Perfect';
    if (vs < 140) return 'Smooth';
    if (vs < 200) return 'Good';
    if (vs < 300) return 'Firm';
    return 'Hard';
  }

  bool _isStableStopped(SimLinkData data, LatLng currentPos) {
    if (!data.onGround) {
      _endCheckStartPos = null;
      _endCheckSince = null;
      return false;
    }

    final bool lowSpeed = data.airspeed < 5;

    if (!lowSpeed) {
      _endCheckStartPos = null;
      _endCheckSince = null;
      return false;
    }

    _endCheckStartPos ??= currentPos;
    _endCheckSince ??= DateTime.now();

    final movedNm = _calculateDistanceNm(_endCheckStartPos!, currentPos);
    final stableLongEnough =
        DateTime.now().difference(_endCheckSince!).inSeconds >= 12;

    if (movedNm > 0.015) {
      _endCheckStartPos = currentPos;
      _endCheckSince = DateTime.now();
      return false;
    }

    return stableLongEnough;
  }

  Runway? _getRunwayByIdent(String? ident) {
    if (ident == null || ident.isEmpty) return null;

    final needle = ident.trim().toUpperCase();

    for (final r in _runways) {
      if (r.end1Ident.trim().toUpperCase() == needle ||
          r.end2Ident.trim().toUpperCase() == needle) {
        return r;
      }
    }

    return null;
  }
}
