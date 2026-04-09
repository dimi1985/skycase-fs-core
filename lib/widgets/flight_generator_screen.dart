import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skycase/models/aircraft_planning_spec.dart';
import 'package:skycase/models/aircraft_planning_spec_resolver.dart';
import 'package:skycase/models/generated_route_option.dart';
import 'package:skycase/utils/airport_details_repository.dart';
import 'package:skycase/utils/airport_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:skycase/models/airport.dart';
import 'package:skycase/models/aircraft_template.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/models/flight.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/providers/unit_system_provider.dart';
import 'package:skycase/services/aircraft_service.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/flight_plan_service.dart';
import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/utils/session_manager.dart';

enum AircraftSource { live, hangar }

class _AirportRunwayInfo {
  final double longestRunwayFt;
  final int runwayCount;
  final bool hasHardSurface;
  final bool hasAnyRunway;

  const _AirportRunwayInfo({
    required this.longestRunwayFt,
    required this.runwayCount,
    required this.hasHardSurface,
    required this.hasAnyRunway,
  });

  factory _AirportRunwayInfo.fromMap(Map<String, dynamic> map) {
    return _AirportRunwayInfo(
      longestRunwayFt: (map['longestRunwayFt'] ?? 0).toDouble(),
      runwayCount: (map['runwayCount'] ?? 0) as int,
      hasHardSurface: (map['hasHardSurface'] ?? false) as bool,
      hasAnyRunway: (map['hasAnyRunway'] ?? false) as bool,
    );
  }
}

String _gridKey(double lat, double lon, {double cellSizeDeg = 0.5}) {
  final latIdx = (lat / cellSizeDeg).floor();
  final lonIdx = (lon / cellSizeDeg).floor();
  return '$latIdx:$lonIdx';
}

double _degToRad(double deg) => deg * pi / 180.0;

double _haversineDistanceNm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusMeters = 6371000.0;

  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * pow(sin(dLon / 2), 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return (earthRadiusMeters * c) / 1852.0;
}

bool _isHardSurfaceStatic(String surface) {
  final s = surface.trim().toLowerCase();
  if (s.isEmpty) return false;

  const hard = {
    'asphalt',
    'concrete',
    'bituminous',
    'tarmac',
    'paved',
    'cement',
  };

  return hard.any(s.contains);
}

Map<String, dynamic> _buildAirportRunwayIndexPayload(
  Map<String, dynamic> payload,
) {
  final airports =
      (payload['airports'] as List).cast<Map>().map((e) {
        return {
          'icao': (e['icao'] ?? '').toString().toUpperCase(),
          'lat': (e['lat'] ?? 0).toDouble(),
          'lon': (e['lon'] ?? 0).toDouble(),
        };
      }).toList();

  final runways =
      (payload['runways'] as List).cast<Map>().map((e) {
        final end1Lat = (e['end1_lat'] ?? 0).toDouble();
        final end1Lon = (e['end1_lon'] ?? 0).toDouble();
        final end2Lat = (e['end2_lat'] ?? 0).toDouble();
        final end2Lon = (e['end2_lon'] ?? 0).toDouble();

        return {
          'midLat': (end1Lat + end2Lat) / 2.0,
          'midLon': (end1Lon + end2Lon) / 2.0,
          'length': (e['length'] ?? 0).toDouble(),
          'surface': (e['surface'] ?? '').toString(),
        };
      }).toList();

  const cellSize = 0.5;
  final Map<String, List<Map<String, dynamic>>> runwayBuckets = {};

  for (final runway in runways) {
    final key = _gridKey(
      (runway['midLat'] as double),
      (runway['midLon'] as double),
      cellSizeDeg: cellSize,
    );
    runwayBuckets.putIfAbsent(key, () => []);
    runwayBuckets[key]!.add(runway);
  }

  final Map<String, Map<String, dynamic>> result = {};

  for (final airport in airports) {
    final icao = airport['icao'] as String;
    final lat = airport['lat'] as double;
    final lon = airport['lon'] as double;

    double longestRunwayFt = 0;
    int runwayCount = 0;
    bool hasHardSurface = false;

    final baseLatIdx = (lat / cellSize).floor();
    final baseLonIdx = (lon / cellSize).floor();

    for (int dLat = -1; dLat <= 1; dLat++) {
      for (int dLon = -1; dLon <= 1; dLon++) {
        final neighborKey = '${baseLatIdx + dLat}:${baseLonIdx + dLon}';
        final bucket = runwayBuckets[neighborKey];
        if (bucket == null || bucket.isEmpty) continue;

        for (final runway in bucket) {
          final runwayLat = runway['midLat'] as double;
          final runwayLon = runway['midLon'] as double;
          final distNm = _haversineDistanceNm(lat, lon, runwayLat, runwayLon);

          if (distNm > 6.0) continue;

          runwayCount += 1;
          final length = runway['length'] as double;
          if (length > longestRunwayFt) longestRunwayFt = length;

          if (_isHardSurfaceStatic(runway['surface'] as String)) {
            hasHardSurface = true;
          }
        }
      }
    }

    result[icao] = {
      'longestRunwayFt': longestRunwayFt,
      'runwayCount': runwayCount,
      'hasHardSurface': hasHardSurface,
      'hasAnyRunway': runwayCount > 0,
    };
  }

  return result;
}

class FlightGeneratorScreen extends StatefulWidget {
  const FlightGeneratorScreen({
    super.key,
    this.showAppBar = true,
    this.activeJob,
  });

  final bool showAppBar;
  final DispatchJob? activeJob;

  @override
  State<FlightGeneratorScreen> createState() => _FlightGeneratorScreenState();
}

class _FlightGeneratorScreenState extends State<FlightGeneratorScreen> {
  bool get isMetric => context.read<UnitSystemProvider>().isMetric;

  final Random _rng = Random();

  List<Airport> _airports = [];
  final Map<String, Airport> _airportByCode = {};
  Map<String, LatLng> _coords = {};
  Map<String, _AirportRunwayInfo> _runwayInfoByAirportIcao = {};

  List<AircraftTemplate> _templates = [];
  AircraftTemplate? _matchedTemplate;

  List<LearnedAircraft> _hangarAircraft = [];
  LearnedAircraft? _selectedHangar;

  SimLinkData? get sim => SimLinkSocketService().latestData;

  DispatchJob? activeJob;

  AircraftSource _aircraftSource = AircraftSource.live;
  int _originMode = 0; // 0=HQ, 1=Last, 2=Live, 3=Manual, 4=Job
  double _maxDistance = 100;

  String? _hqIcao;
  String? _lastIcao;

  String? _customOrigin;
  String? _customDest;

  final TextEditingController _customOriginCtrl = TextEditingController();
  final TextEditingController _customDestCtrl = TextEditingController();

  bool _fuelDetail = false;

  bool _loadingAirports = true;
  bool _loadingRunways = true;
  bool _loadingTemplates = true;
  bool _loadingPrefs = true;
  bool _loadingJob = true;
  bool _loadingHangar = true;
  bool _savingPrefs = false;
  bool _findingRoutes = false;
  bool _creatingFlight = false;

  List<GeneratedRouteOption> _routeOptions = [];
  GeneratedRouteOption? _selectedRoute;

  static const String _tempRoutesKey = 'temp_generated_route_options';
  static const String _tempSelectedRouteKey = 'temp_generated_selected_route';

  @override
  void initState() {
    super.initState();
    activeJob = widget.activeJob;
    _bootstrap();
  }

  @override
  void dispose() {
    _customOriginCtrl.dispose();
    _customDestCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadPrefs(),
      _loadAirportDB(),
      _loadTemplates(),
      _loadHangar(),
      _loadActiveJob(),
    ]);

    await _loadRunwayInfo();
    await _loadTempRoutes();
    _refreshMatchedTemplate();
  }

  Future<void> _saveTempRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _tempRoutesKey,
        jsonEncode(_routeOptions.map((e) => e.toJson()).toList()),
      );

      if (_selectedRoute != null) {
        await prefs.setString(
          _tempSelectedRouteKey,
          jsonEncode(_selectedRoute!.toJson()),
        );
      } else {
        await prefs.remove(_tempSelectedRouteKey);
      }
    } catch (_) {}
  }

  Future<void> _loadTempRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rawRoutes = prefs.getString(_tempRoutesKey);
      final rawSelected = prefs.getString(_tempSelectedRouteKey);

      if (rawRoutes == null || rawRoutes.isEmpty) return;

      final decoded = jsonDecode(rawRoutes) as List;
      final routes =
          decoded
              .map(
                (e) =>
                    GeneratedRouteOption.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList();

      GeneratedRouteOption? selected;
      if (rawSelected != null && rawSelected.isNotEmpty) {
        selected = GeneratedRouteOption.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawSelected)),
        );
      }

      if (!mounted) return;
      setState(() {
        _routeOptions = routes;
        _selectedRoute = selected ?? (routes.isNotEmpty ? routes.first : null);
      });
    } catch (_) {}
  }

  Future<void> _deleteTempRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tempRoutesKey);
      await prefs.remove(_tempSelectedRouteKey);
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        _hqIcao = prefs.getString('homebase_icao');
        _lastIcao = prefs.getString('last_destination_icao');
        _maxDistance = prefs.getDouble('flight_max_distance_nm') ?? 100;
        _loadingPrefs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPrefs = false);
    }
  }

  Future<void> _persistDistancePref() async {
    if (_savingPrefs) return;
    _savingPrefs = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('flight_max_distance_nm', _maxDistance);
    } catch (_) {
      // silent on purpose
    } finally {
      _savingPrefs = false;
    }
  }

  Future<void> _loadAirportDB() async {
    try {
      final repo = AirportRepository();
      await repo.load();

      final airports = List<Airport>.from(repo.airports);
      final byCode = <String, Airport>{};

      for (final airport in airports) {
        byCode[airport.icao.toUpperCase()] = airport;
      }

      if (!mounted) return;
      setState(() {
        _airports = airports;
        _coords = Map<String, LatLng>.from(repo.coordsByIcao);
        _airportByCode
          ..clear()
          ..addAll(byCode);
        _loadingAirports = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAirports = false);
    }
  }

  Future<void> _loadRunwayInfo() async {
    try {
      final repo = AirportDetailsRepository();
      await repo.loadRunways();

      final payload = {
        'airports':
            _airports
                .map((a) => {'icao': a.icao, 'lat': a.lat, 'lon': a.lon})
                .toList(),
        'runways':
            repo.runways
                .map(
                  (r) => {
                    'length': r.length,
                    'surface': r.surface,
                    'end1_lat': r.end1Lat,
                    'end1_lon': r.end1Lon,
                    'end2_lat': r.end2Lat,
                    'end2_lon': r.end2Lon,
                  },
                )
                .toList(),
      };

      final rawResult = await compute(_buildAirportRunwayIndexPayload, payload);

      final mapped = <String, _AirportRunwayInfo>{};
      for (final entry in rawResult.entries) {
        mapped[entry.key] = _AirportRunwayInfo.fromMap(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }

      if (!mounted) return;
      setState(() {
        _runwayInfoByAirportIcao = mapped;
        _loadingRunways = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRunways = false);
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/aircraft_templates.json',
      );
      final list = jsonDecode(raw) as List;

      if (!mounted) return;
      setState(() {
        _templates = list.map((e) => AircraftTemplate.fromJson(e)).toList();
        _loadingTemplates = false;
        _refreshMatchedTemplate();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTemplates = false);
    }
  }

  Future<void> _loadHangar() async {
    try {
      final list = await AircraftService.getAll();
      if (!mounted) return;

      setState(() {
        _hangarAircraft = list;
        if (list.isNotEmpty) {
          _selectedHangar = list.first;
        }
        _loadingHangar = false;
        _refreshMatchedTemplate();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHangar = false);
    }
  }

  Future<void> _loadActiveJob() async {
    if (widget.activeJob != null) {
      if (!mounted) return;
      setState(() {
        activeJob = widget.activeJob;
        _loadingJob = false;
      });
      return;
    }

    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() => _loadingJob = false);
        return;
      }

      final res = await DispatchService.getActiveJob(userId);

      if (!mounted) return;
      setState(() {
        activeJob = res;
        _loadingJob = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingJob = false);
    }
  }

  AircraftPlanningSpec? get _planningSpec =>
      AircraftPlanningSpecResolver.resolve(
        sim: sim,
        hangarAircraft: _selectedHangar,
        matchedTemplate: _matchedTemplate,
        title: _currentAircraftTitle,
      );

  double? get _usableRangeNm => _planningSpec?.usableRangeNm;

  bool get _isBusy =>
      _loadingAirports ||
      _loadingRunways ||
      _loadingTemplates ||
      _loadingPrefs ||
      _loadingHangar ||
      _findingRoutes ||
      _creatingFlight;

  double get _transferFuelCargoDensityLbsPerGal {
    return 6.7;
  }

  double get _transferFuelCargoWeightLbs {
    if (activeJob == null) return 0;
    return activeJob!.transferFuelGallons * _transferFuelCargoDensityLbsPerGal;
  }

  String? _rangeWarningForDistance(double distanceNm) {
    final usableRange = _usableRangeNm;
    if (usableRange == null || usableRange <= 0) return null;

    if (distanceNm > usableRange) {
      return 'Slow down kid — not enough range. '
          'Trip ${distanceNm.toStringAsFixed(0)} NM, '
          'usable range ${usableRange.toStringAsFixed(0)} NM.';
    }

    return null;
  }

  void _refreshMatchedTemplate() {
    _matchedTemplate = _resolveTemplate();
  }

  AircraftTemplate? _resolveTemplate() {
    if (_templates.isEmpty) return null;

    String candidate = '';

    if (_aircraftSource == AircraftSource.live && sim != null) {
      candidate = sim!.title.trim();
    } else if (_aircraftSource == AircraftSource.hangar &&
        _selectedHangar != null) {
      candidate = _selectedHangar!.title.trim();
    }

    if (candidate.isEmpty) return null;

    final normalized = _normalizeAircraftName(candidate);

    for (final t in _templates) {
      if (_normalizeAircraftName(t.id) == normalized) return t;
    }

    for (final t in _templates) {
      if (_normalizeAircraftName(t.name) == normalized) return t;
    }

    for (final t in _templates) {
      final tId = _normalizeAircraftName(t.id);
      final tName = _normalizeAircraftName(t.name);
      if (normalized.contains(tId) ||
          normalized.contains(tName) ||
          tName.contains(normalized)) {
        return t;
      }
    }

    final aliasMap = <String, String>{
      'cessna 152': 'C152',
      'c152': 'C152',
      'cessna 172': 'C172',
      'c172': 'C172',
      'cessna 182': 'C182',
      'c182': 'C182',
      'cessna 185': 'C185',
      'c185': 'C185',
      'skywagon': 'C185',
      'cessna 208': 'C208',
      'caravan': 'C208',
      'bonanza': 'BONANZA_G36',
      'g36': 'BONANZA_G36',
      '414': 'C414A',
      'chancellor': 'C414A',
      'sr22': 'SR22',
      'warrior': 'PA28_WARRIOR',
      'pa28': 'PA28_WARRIOR',
      'pa-28': 'PA28_WARRIOR',
      'dv20': 'DV20',
      'da20': 'DV20',
      'da40': 'DA40',
      'kodiak': 'KODIAK100',
      'pc12': 'PC12',
      'pc-12': 'PC12',
      'tbm': 'TBM930',
      'king air': 'KINGAIR350',
      'cj4': 'CJ4',
      'hondajet': 'HONDJET',
      'vision jet': 'VISIONJET',
      'sf50': 'VISIONJET',
      'a320': 'A320',
      '737-800': 'B738',
      'b738': 'B738',
      'a310': 'A310',
      'r44': 'R44',
      'h125': 'H125',
      'h135': 'H135',
      'icon a5': 'ICONA5',
      'xcub': 'XCUB',
    };

    for (final entry in aliasMap.entries) {
      if (normalized.contains(_normalizeAircraftName(entry.key))) {
        for (final t in _templates) {
          if (t.id == entry.value) return t;
        }
      }
    }

    return null;
  }

  String _normalizeAircraftName(String input) {
    return input
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('  ', ' ')
        .trim();
  }

  String get _currentAircraftTitle {
    if (_aircraftSource == AircraftSource.live && sim != null) {
      final title = sim!.title.trim();
      if (title.isNotEmpty) return title;
      return 'Live Aircraft';
    }

    if (_selectedHangar != null) {
      return _selectedHangar!.title;
    }

    return _aircraftSource == AircraftSource.live
        ? 'Awaiting Live Aircraft'
        : 'No Hangar Aircraft Selected';
  }

  String get _currentAircraftSubtitle {
    final spec = _planningSpec;
    final rangeText =
        spec?.usableRangeNm != null
            ? ' • usable ${spec!.usableRangeNm!.toStringAsFixed(0)} NM'
            : (_matchedTemplate != null
                ? ' • book ${_matchedTemplate!.maxRangeNm.toStringAsFixed(0)} NM'
                : '');

    final templateText =
        spec != null
            ? ' • ${spec.cruiseSpeedKts.toStringAsFixed(0)} kts$rangeText'
            : '';

    if (_aircraftSource == AircraftSource.live && sim != null) {
      final engineLabel = switch (sim!.engineType) {
        0 => 'Piston',
        1 => 'Jet',
        3 => 'Helicopter',
        5 => 'Turboprop',
        _ => 'Unknown Engine',
      };

      return 'Live source • $engineLabel$templateText';
    }

    if (_selectedHangar != null) {
      final type = _hangarTypeLabel(_selectedHangar!);
      final mtow = _selectedHangar!.mtow ?? 0;
      final mtowText = mtow > 0 ? ' • MTOW ${mtow.toStringAsFixed(0)} lbs' : '';
      return 'Hangar source • $type$mtowText$templateText';
    }

    return 'Select an aircraft from your hangar';
  }

  String _hangarTypeLabel(LearnedAircraft aircraft) {
    final t = aircraft.title.toLowerCase();
    if (aircraft.skids == true ||
        t.contains('heli') ||
        t.contains('helicopter')) {
      return 'Helicopter';
    }
    if (t.contains('jet')) return 'Jet';
    if (t.contains('tbm') ||
        t.contains('king air') ||
        t.contains('caravan') ||
        t.contains('turbo')) {
      return 'Turboprop';
    }
    if (aircraft.floats == true) return 'Floatplane';
    return 'General Aviation';
  }

  bool get _isHelicopterAircraft => _planningSpec?.isHelicopter ?? false;

  Airport? _airportByIcao(String? icao) {
    if (icao == null || icao.trim().isEmpty) return null;
    return _airportByCode[icao.trim().toUpperCase()];
  }

  LatLng? get _originLatLng {
    switch (_originMode) {
      case 0:
        return _coords[_hqIcao];
      case 1:
        return _coords[_lastIcao];
      case 2:
        return sim != null ? LatLng(sim!.latitude, sim!.longitude) : null;
      case 3:
        return _coords[_customOrigin?.toUpperCase()];
      case 4:
        return _coords[activeJob?.fromIcao.toUpperCase()];
    }
    return null;
  }

  String get _originIcao {
    switch (_originMode) {
      case 0:
        return _hqIcao ?? '';
      case 1:
        return _lastIcao ?? '';
      case 2:
        return 'LIVEPOS';
      case 3:
        return _customOrigin?.toUpperCase() ?? '';
      case 4:
        return activeJob?.fromIcao.toUpperCase() ?? '';
    }
    return '';
  }

  LatLng? get _manualDestLatLng {
    if (_originMode != 3) return null;
    if (_customDest == null || _customDest!.trim().isEmpty) return null;
    return _coords[_customDest!.toUpperCase()];
  }

  double get _effectiveMaxDistance {
    final usableRange = _usableRangeNm;
    if (usableRange == null || usableRange <= 0) return _maxDistance;
    return _maxDistance.clamp(25.0, usableRange);
  }

  double _distNmFast(LatLng a, LatLng b) {
    return _haversineDistanceNm(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  double _distNmPrecise(LatLng a, LatLng b) {
    return vincentyDistanceNm(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  double _rad(double x) => x * pi / 180;

  double _cruiseSpeedKts() {
    return _planningSpec?.cruiseSpeedKts ?? 135.0;
  }

  double _fuelDensity() {
    return _planningSpec?.fuelDensity ?? 6.0;
  }

  double _estimatedBurnGph() {
    return _planningSpec?.fuelBurnGph ?? 12.0;
  }

  Map<String, double> computeFuel(double distanceNm) {
    final cruiseSpeedKts = _cruiseSpeedKts();
    final flightHours = distanceNm / cruiseSpeedKts;

    final burnGph = _estimatedBurnGph();
    final enrouteFuel = burnGph * flightHours;

    const taxiFuel = 3.0;
    const climbFuel = 5.0;
    const reserveFuel = 30.0;

    final requiredJobFuel = activeJob?.requiredFuelGallons.toDouble() ?? 0.0;
    final payloadPenaltyFuel = _payloadPenaltyFuel(distanceNm);

    final totalGallons =
        enrouteFuel +
        taxiFuel +
        climbFuel +
        reserveFuel +
        requiredJobFuel +
        payloadPenaltyFuel;

    final density = _fuelDensity();
    final fuelLbs = totalGallons * density;
    final fuelKg = fuelLbs * 0.453592;

    return {
      'gal': totalGallons,
      'lbs': fuelLbs,
      'kg': fuelKg,
      'enroute': enrouteFuel,
      'required': requiredJobFuel,
      'payloadPenalty': payloadPenaltyFuel,
    };
  }

  num jobPayloadWeightLbs() {
    if (activeJob == null) return 0;

    final cargo = activeJob!.payloadLbs.toDouble();
    final pax = (activeJob!.paxCount * 170).toDouble();
    final fuelCargo = _transferFuelCargoWeightLbs;

    return cargo + pax + fuelCargo;
  }

  String? mtowWarning({required double plannedFuelLbs}) {
    final jobPayload = jobPayloadWeightLbs();

    if (_aircraftSource == AircraftSource.live && sim != null) {
      final simW = sim!.weights;
      final gross = simW.emptyWeight + jobPayload + plannedFuelLbs;
      final limit = simW.maxTakeoffWeight;

      if (limit > 0 && gross > limit) {
        final exceed = gross - limit;
        return '⚠ MTOW exceeded by ${exceed.toStringAsFixed(0)} lbs';
      }
      return null;
    }

    if (_aircraftSource == AircraftSource.hangar && _selectedHangar != null) {
      final emptyWeight = _selectedHangar!.emptyWeight ?? 0;
      final limit = _selectedHangar!.mtow ?? 0;
      final gross = emptyWeight + jobPayload + plannedFuelLbs;

      if (limit > 0 && gross > limit) {
        final exceed = gross - limit;
        return '⚠ MTOW exceeded by ${exceed.toStringAsFixed(0)} lbs';
      }
    }

    return null;
  }

  _AirportRunwayInfo _runwayInfoFor(String icao) {
    return _runwayInfoByAirportIcao[icao.toUpperCase()] ??
        const _AirportRunwayInfo(
          longestRunwayFt: 0,
          runwayCount: 0,
          hasHardSurface: false,
          hasAnyRunway: false,
        );
  }

  bool _isLikelyHeliport(Airport airport) {
    final name = airport.name.toLowerCase();
    final info = _runwayInfoFor(airport.icao);

    if (name.contains('heliport') ||
        name.contains('helipad') ||
        name.contains('hospital heliport') ||
        name.contains('helistop')) {
      return true;
    }

    if (name.contains('seaplane') || name.contains('water aerodrome')) {
      return false;
    }

    if (!info.hasAnyRunway) {
      return name.contains('heli');
    }

    if (info.longestRunwayFt > 0 && info.longestRunwayFt < 500) {
      return true;
    }

    return false;
  }

  bool _airportHasUsableRunway(Airport airport) {
    final info = _runwayInfoFor(airport.icao);
    if (!info.hasAnyRunway) return false;

    final minLength = _minimumRunwayLengthFt();
    return info.longestRunwayFt >= minLength;
  }

  double _minimumRunwayLengthFt() {
    if (_isHelicopterAircraft) return 0;

    final template = _matchedTemplate;
    if (template == null) return 1200;

    final id = template.id.toLowerCase();
    if (id == 'a320' ||
        id == 'b738' ||
        id == 'a310' ||
        id == 'cj4' ||
        id == 'hondjet' ||
        id == 'visionjet') {
      return 4000;
    }
    if (id == 'pc12' ||
        id == 'tbm930' ||
        id == 'kingair350' ||
        id == 'c414a' ||
        id == 'c208' ||
        id == 'kodiak100') {
      return 2500;
    }
    return 1200;
  }

  bool _isDestinationAllowed(Airport airport) {
    final heliport = _isLikelyHeliport(airport);

    if (!_isHelicopterAircraft) {
      if (heliport) return false;
      return _airportHasUsableRunway(airport);
    }

    if (heliport) return true;
    return true;
  }

  void _info(String msg) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Flight Created'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Back'),
              ),
            ],
          ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _clearRouteResults() {
    _routeOptions = [];
    _selectedRoute = null;
  }

  GeneratedRouteOption _buildRouteOption({
    required String originIcao,
    required String destIcao,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) {
    final distanceNm = _distNmPrecise(
      LatLng(originLat, originLng),
      LatLng(destLat, destLng),
    );

    final speed = _cruiseSpeedKts();
    final etaMin = (distanceNm / speed * 60).round();
    final fuel = computeFuel(distanceNm);

    return GeneratedRouteOption(
      originIcao: originIcao,
      destinationIcao: destIcao,
      originLat: originLat,
      originLng: originLng,
      destinationLat: destLat,
      destinationLng: destLng,
      distanceNm: distanceNm,
      etaMinutes: etaMin,
      cruiseAltitude: _recommendedAltitude(distanceNm),
      plannedFuelGallons: fuel['gal']!,
      plannedFuelLbs: fuel['lbs']!,
      plannedFuelKg: fuel['kg']!,
    );
  }

  GeneratedRouteOption? _buildManualRouteOption({bool showErrors = true}) {
    final customOrigin = _customOrigin?.trim().toUpperCase();
    final customDest = _customDest?.trim().toUpperCase();
    final origin = _originLatLng;
    final dest = _manualDestLatLng;

    if (customOrigin == null || customOrigin.isEmpty || origin == null) {
      if (showErrors) _snack('Invalid origin ICAO.');
      return null;
    }
    if (customDest == null || customDest.isEmpty || dest == null) {
      if (showErrors) _snack('Invalid destination ICAO.');
      return null;
    }

    final destAirport = _airportByIcao(customDest);
    if (destAirport != null && !_isDestinationAllowed(destAirport)) {
      if (showErrors) {
        _snack('That destination is not suitable for the selected aircraft.');
      }
      return null;
    }

    final distanceNm = _distNmPrecise(origin, dest);
    final rangeWarning = _rangeWarningForDistance(distanceNm);
    if (rangeWarning != null) {
      if (showErrors) _snack(rangeWarning);
      return null;
    }

    return _buildRouteOption(
      originIcao: customOrigin,
      destIcao: customDest,
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: dest.latitude,
      destLng: dest.longitude,
    );
  }

  GeneratedRouteOption? _buildJobRouteOption({bool showErrors = true}) {
    if (activeJob == null) {
      if (showErrors) _snack('No active job found.');
      return null;
    }

    final originCode = activeJob!.fromIcao.trim().toUpperCase();
    final destCode = activeJob!.toIcao.trim().toUpperCase();

    if (originCode.isEmpty || destCode.isEmpty) {
      if (showErrors) _snack('Job ICAO data is incomplete.');
      return null;
    }

    final origin = _coords[originCode];
    final dest = _coords[destCode];

    if (origin == null || dest == null) {
      if (showErrors) _snack('Active job airports could not be resolved.');
      return null;
    }

    final destAirport = _airportByIcao(destCode);
    if (destAirport != null && !_isDestinationAllowed(destAirport)) {
      if (showErrors) {
        _snack(
          'That job destination is not suitable for the selected aircraft.',
        );
      }
      return null;
    }

    final distanceNm = _distNmPrecise(origin, dest);
    final rangeWarning = _rangeWarningForDistance(distanceNm);
    if (rangeWarning != null) {
      if (showErrors) _snack(rangeWarning);
      return null;
    }

    return _buildRouteOption(
      originIcao: originCode,
      destIcao: destCode,
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: dest.latitude,
      destLng: dest.longitude,
    );
  }

  Future<void> _findRoutes() async {
    if (_findingRoutes) return;

    if (_originMode == 3) {
      _snack('Manual mode creates the flight directly. No search is needed.');
      return;
    }

    if (_originMode == 4) {
      final jobRoute = _buildJobRouteOption();
      if (jobRoute == null) return;

      setState(() {
        _routeOptions = [jobRoute];
        _selectedRoute = jobRoute;
      });
      await _saveTempRoutes();
      return;
    }

    final origin = _originLatLng;
    if (origin == null) {
      _snack('Invalid origin ICAO.');
      return;
    }

    setState(() {
      _findingRoutes = true;
      _clearRouteResults();
    });

    try {
      final effectiveMax = _effectiveMaxDistance;
      final minDistance = (effectiveMax * 0.45).clamp(15.0, effectiveMax);

      final candidates = <MapEntry<Airport, double>>[];

      for (final airport in _airports) {
        final coord = _coords[airport.icao];
        if (coord == null) continue;
        if (airport.icao == _originIcao) continue;
        if (!_isDestinationAllowed(airport)) continue;

        final distance = _distNmFast(origin, coord);
        if (distance < minDistance || distance > effectiveMax) continue;

        final usableRange = _usableRangeNm;
        if (usableRange != null && usableRange > 0 && distance > usableRange) {
          continue;
        }

        candidates.add(MapEntry(airport, distance));
      }

      List<MapEntry<Airport, double>> working = candidates;

      if (working.length < 5) {
        final relaxedMin = (effectiveMax * 0.25).clamp(10.0, effectiveMax);

        working = [];
        for (final airport in _airports) {
          final coord = _coords[airport.icao];
          if (coord == null) continue;
          if (airport.icao == _originIcao) continue;
          if (!_isDestinationAllowed(airport)) continue;

          final distance = _distNmFast(origin, coord);
          if (distance < relaxedMin || distance > effectiveMax) continue;

          final usableRange = _usableRangeNm;
          if (usableRange != null &&
              usableRange > 0 &&
              distance > usableRange) {
            continue;
          }

          working.add(MapEntry(airport, distance));
        }
      }

      if (working.isEmpty) {
        final usableRange = _usableRangeNm;
        if (usableRange != null && usableRange > 0) {
          _snack(
            'No destinations found inside usable range '
            '(${usableRange.toStringAsFixed(0)} NM).',
          );
        } else {
          _snack('No destinations found.');
        }
        return;
      }

      working.shuffle(_rng);

      working.sort((a, b) {
        final aDelta = (effectiveMax - a.value).abs();
        final bDelta = (effectiveMax - b.value).abs();
        return aDelta.compareTo(bDelta);
      });

      final topPool =
          working.take(min(20, working.length)).toList()..shuffle(_rng);
      final picked = topPool.take(min(5, topPool.length)).toList();

      final routes =
          picked.map((entry) {
              final airport = entry.key;
              final dest = _coords[airport.icao]!;
              return _buildRouteOption(
                originIcao: _originIcao,
                destIcao: airport.icao,
                originLat: origin.latitude,
                originLng: origin.longitude,
                destLat: dest.latitude,
                destLng: dest.longitude,
              );
            }).toList()
            ..sort((a, b) => b.distanceNm.compareTo(a.distanceNm));

      if (!mounted) return;
      setState(() {
        _routeOptions = routes;
        _selectedRoute = routes.isNotEmpty ? routes.first : null;
      });
      await _saveTempRoutes();
    } finally {
      if (mounted) {
        setState(() => _findingRoutes = false);
      }
    }
  }

  Future<void> _createSelectedFlightPlan() async {
    if (_creatingFlight) return;

    GeneratedRouteOption? route = _selectedRoute;

    if (_originMode == 3) {
      route = _buildManualRouteOption();
    } else if (_originMode == 4 && route == null) {
      route = _buildJobRouteOption();
    }

    if (route == null) {
      _snack(
        _originMode == 3
            ? 'Check the manual ICAO fields first.'
            : 'Select a route first.',
      );
      return;
    }

    setState(() => _creatingFlight = true);

    try {
      final warning = mtowWarning(plannedFuelLbs: route.plannedFuelLbs);
      if (warning != null) {
        _snack(warning);
      }

      final aircraftName = _currentAircraftTitle;

      final flight = Flight(
        id: const Uuid().v4(),
        originIcao: route.originIcao,
        destinationIcao: route.destinationIcao,
        generatedAt: DateTime.now(),
        aircraftType: aircraftName,
        estimatedDistanceNm: route.distanceNm,
        estimatedTime: Duration(minutes: route.etaMinutes),
        originLat: route.originLat,
        originLng: route.originLng,
        destinationLat: route.destinationLat,
        destinationLng: route.destinationLng,
        missionId: null,
        cruiseAltitude: route.cruiseAltitude,
        plannedFuel: route.plannedFuelGallons,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_flight', jsonEncode(flight.toJson()));

      final userId = await SessionManager.getUserId();
      if (userId != null) {
        await FlightPlanService.saveFlightPlan(flight, userId);
      }

      await _deleteTempRoutes();

      if (mounted) {
        setState(() {
          _routeOptions = [];
          _selectedRoute = null;
        });
      }

      final unitFuel =
          isMetric
              ? '${route.plannedFuelKg.toStringAsFixed(1)} kg'
              : '${route.plannedFuelGallons.toStringAsFixed(1)} gal';

      final totalPayload = jobPayloadWeightLbs();

      _info("""
From: ${route.originIcao}
To:   ${route.destinationIcao}

Distance: ${route.distanceNm.toStringAsFixed(1)} NM
Time:     ${route.etaMinutes} min
Fuel:     $unitFuel

Payload (job included): ${totalPayload.toStringAsFixed(0)} lbs
Aircraft: $aircraftName
""");
    } finally {
      if (mounted) {
        setState(() => _creatingFlight = false);
      }
    }
  }

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
    if (_originMode == 3) {
      final route = _buildManualRouteOption(showErrors: false);
      if (route == null) return null;
      final fuel = computeFuel(route.distanceNm);
      return {
        'gal': route.plannedFuelGallons,
        'lbs': route.plannedFuelLbs,
        'kg': route.plannedFuelKg,
        'enroute': fuel['enroute']!,
        'required': fuel['required']!,
        'payloadPenalty': fuel['payloadPenalty']!,
      };
    }

    if (_originMode == 4) {
      final route = _buildJobRouteOption(showErrors: false);
      if (route == null) return null;
      final fuel = computeFuel(route.distanceNm);
      return {
        'gal': route.plannedFuelGallons,
        'lbs': route.plannedFuelLbs,
        'kg': route.plannedFuelKg,
        'enroute': fuel['enroute']!,
        'required': fuel['required']!,
        'payloadPenalty': fuel['payloadPenalty']!,
      };
    }

    if (_originLatLng == null) return null;
    return computeFuel(_currentDistanceNm);
  }

  double get _currentDistanceNm {
    if (_selectedRoute != null) {
      return _selectedRoute!.distanceNm;
    }

    if (_originMode == 3) {
      if (_originLatLng != null && _manualDestLatLng != null) {
        return _distNmPrecise(_originLatLng!, _manualDestLatLng!);
      }
      return _effectiveMaxDistance;
    }

    if (_originMode == 4) {
      final route = _buildJobRouteOption(showErrors: false);
      if (route != null) return route.distanceNm;
      return _effectiveMaxDistance;
    }

    if (_originLatLng == null) return _effectiveMaxDistance;
    return _effectiveMaxDistance;
  }

  String _formatFuel(double gal, double kg) {
    return isMetric
        ? '${kg.toStringAsFixed(1)} kg'
        : '${gal.toStringAsFixed(1)} gal';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final simConnected = sim != null;
    final fuel = _fuelSnapshot;
    final manualMode = _originMode == 3;
    final jobMode = _originMode == 4;
    final jobRoutePreview =
        jobMode ? _buildJobRouteOption(showErrors: false) : null;
    final selectedOrJobRoute = _selectedRoute ?? jobRoutePreview;
    final canCreateFlight =
        !_isBusy &&
        (manualMode || selectedOrJobRoute != null) &&
        (selectedOrJobRoute == null ||
            _rangeWarningForDistance(selectedOrJobRoute.distanceNm) == null);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AircraftHeaderCard(
            title: _currentAircraftTitle,
            subtitle: _currentAircraftSubtitle,
            isLive: _aircraftSource == AircraftSource.live,
            hasLiveSignal: simConnected,
          ),
          const SizedBox(height: 18),
          SegmentedButton<AircraftSource>(
            segments: const [
              ButtonSegment(
                value: AircraftSource.live,
                label: Text('Live'),
                icon: Icon(Icons.sensors),
              ),
              ButtonSegment(
                value: AircraftSource.hangar,
                label: Text('Hangar'),
                icon: Icon(Icons.airplanemode_active),
              ),
            ],
            selected: {_aircraftSource},
            onSelectionChanged: (v) {
              setState(() {
                _aircraftSource = v.first;
                _refreshMatchedTemplate();
                _clearRouteResults();
              });
            },
          ),
          const SizedBox(height: 16),
          if (_aircraftSource == AircraftSource.hangar)
            DropdownButtonFormField<LearnedAircraft>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Hangar Aircraft',
                border: OutlineInputBorder(),
              ),
              value: _selectedHangar,
              items:
                  _hangarAircraft
                      .map(
                        (e) => DropdownMenuItem<LearnedAircraft>(
                          value: e,
                          child: Text(e.title),
                        ),
                      )
                      .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedHangar = v;
                  _refreshMatchedTemplate();
                  _clearRouteResults();
                });
              },
            ),
          const SizedBox(height: 24),
          Text(
            'Origin',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _originBtn(
                'HQ',
                Icons.home_filled,
                0,
                _hqIcao ?? '—',
                enabled: _hqIcao != null,
              ),
              _originBtn(
                'Last',
                Icons.history,
                1,
                _lastIcao ?? '—',
                enabled: _lastIcao != null,
              ),
              _originBtn(
                'Live',
                Icons.gps_fixed,
                2,
                'GPS',
                enabled: simConnected,
              ),
              if (activeJob != null)
                _originBtn(
                  'Job',
                  Icons.assignment_turned_in_rounded,
                  4,
                  '${activeJob!.fromIcao} → ${activeJob!.toIcao}',
                  enabled: activeJob!.fromIcao.isNotEmpty,
                ),
              _originBtn('Manual', Icons.edit_location, 3, ''),
            ],
          ),
          const SizedBox(height: 22),
          if (manualMode) ...[
            TextField(
              controller: _customOriginCtrl,
              maxLength: 4,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Origin ICAO',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() {
                  _customOrigin = v.toUpperCase();
                  _clearRouteResults();
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _customDestCtrl,
              maxLength: 4,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Destination ICAO',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() {
                  _customDest = v.toUpperCase();
                  _clearRouteResults();
                });
              },
            ),
            const SizedBox(height: 20),
          ],
          if (!manualMode) ...[
            Text(
              'Max Distance: ${_effectiveMaxDistance.toInt()} NM',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: _maxDistance,
              min: 25,
              max: 1000,
              onChanged: (v) {
                setState(() {
                  _maxDistance = v;
                  _clearRouteResults();
                });
              },
              onChangeEnd: (_) => _persistDistancePref(),
            ),
            const SizedBox(height: 20),
          ],
          if (fuel != null) _fuelPanel(fuel),
          const SizedBox(height: 24),
          if (_loadingJob) const LinearProgressIndicator(minHeight: 2),
          if (_loadingRunways) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Text(
              'Building airport/runway index...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withOpacity(0.72),
              ),
            ),
          ],
          if (activeJob != null && fuel != null) ...[
            const SizedBox(height: 12),
            _JobImpactCard(
              payloadLbs: jobPayloadWeightLbs().toDouble(),
              payloadPenaltyFuelGal: fuel['payloadPenalty']!,
              requiredFuelGal: fuel['required']!,
              mtowText: mtowWarning(plannedFuelLbs: fuel['lbs']!) ?? 'MTOW: OK',
              showMissionFuel: activeJob!.needsFuel,
              transferFuelGallons: activeJob!.transferFuelGallons.toDouble(),
              transferFuelWeightLbs: _transferFuelCargoWeightLbs,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            manualMode
                ? 'Manual Flight'
                : jobMode
                ? 'Active Job Route'
                : 'Route Suggestions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            manualMode
                ? 'Manual mode creates the exact origin → destination flight directly.'
                : jobMode
                ? 'Job mode uses your accepted dispatch route exactly.'
                : 'Find up to 5 random realistic destinations inside your selected range.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 14),
          if (manualMode)
            Card(
              color: colors.surfaceContainerHighest.withOpacity(0.18),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No route search in manual mode. Enter both ICAOs and tap “Create Flight Plan”.',
                ),
              ),
            )
          else if (jobMode && _routeOptions.isEmpty)
            Card(
              color: colors.surfaceContainerHighest.withOpacity(0.18),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tap “Find Routes” to load the exact accepted job route.',
                ),
              ),
            )
          else if (_routeOptions.isEmpty)
            Card(
              color: colors.surfaceContainerHighest.withOpacity(0.18),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No routes yet. Tap “Find Routes” to generate options.',
                ),
              ),
            )
          else
            Column(
              children:
                  _routeOptions.map((route) => _routeTile(route)).toList(),
            ),
          if (!manualMode && _selectedRoute != null) ...[
            const SizedBox(height: 18),
            _SelectedRouteSummaryCard(
              route: _selectedRoute!,
              fuelText: _formatFuel(
                _selectedRoute!.plannedFuelGallons,
                _selectedRoute!.plannedFuelKg,
              ),
              mtowWarning: mtowWarning(
                plannedFuelLbs: _selectedRoute!.plannedFuelLbs,
              ),
              rangeWarning: _rangeWarningForDistance(
                _selectedRoute!.distanceNm,
              ),
            ),
          ],
          const SizedBox(height: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!manualMode)
                ElevatedButton.icon(
                  icon:
                      _findingRoutes
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.alt_route),
                  label: Text(_findingRoutes ? 'Finding...' : 'Find Routes'),
                  onPressed: _isBusy ? null : _findRoutes,
                ),
              if (!manualMode) const SizedBox(height: 12),
              ElevatedButton.icon(
                icon:
                    _creatingFlight
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.flight_takeoff),
                label: Text(
                  _creatingFlight
                      ? 'Creating...'
                      : manualMode
                      ? 'Create Manual Flight'
                      : 'Create Flight Plan',
                ),
                onPressed: canCreateFlight ? _createSelectedFlightPlan : null,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return ColoredBox(color: colors.background, child: content);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Flight Generator • $_currentAircraftTitle')),
      body: content,
    );
  }

  Widget _routeTile(GeneratedRouteOption route) {
    final selected = identical(_selectedRoute, route);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fuelText = _formatFuel(route.plannedFuelGallons, route.plannedFuelKg);
    final rangeWarning = _rangeWarningForDistance(route.distanceNm);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() => _selectedRoute = route);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withOpacity(
              selected ? 0.24 : 0.16,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? colors.primary : colors.outline.withOpacity(0.18),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${route.originIcao} → ${route.destinationIcao}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: colors.primary),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text('${route.distanceNm.toStringAsFixed(1)} NM'),
                    Text('${route.etaMinutes} min'),
                    Text(fuelText),
                    Text('Cruise ${route.cruiseAltitude} ft'),
                  ],
                ),
                if (rangeWarning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    rangeWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
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

  Widget _originBtn(
    String title,
    IconData icon,
    int mode,
    String sub, {
    bool enabled = true,
  }) {
    final selected = _originMode == mode;
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap:
          enabled
              ? () {
                setState(() {
                  _originMode = mode;
                  _clearRouteResults();
                });
              }
              : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        width: 130,
        decoration: BoxDecoration(
          color:
              enabled
                  ? colors.surfaceContainerHighest.withOpacity(0.30)
                  : colors.surfaceContainerHighest.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  enabled
                      ? colors.onSurface
                      : colors.onSurface.withOpacity(0.35),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    enabled
                        ? colors.onSurface
                        : colors.onSurface.withOpacity(0.35),
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(
                  color:
                      enabled
                          ? colors.onSurface.withOpacity(0.70)
                          : colors.onSurface.withOpacity(0.30),
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fuelPanel(Map<String, double> f) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final distance = _currentDistanceNm;

    final gal = f['gal']!;
    final lbs = f['lbs']!;
    final kg = f['kg']!;
    final unitFuel =
        isMetric
            ? '${kg.toStringAsFixed(1)} kg'
            : '${gal.toStringAsFixed(1)} gal';

    return Card(
      color: colors.surfaceContainerHighest.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flight Fuel Estimate',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_matchedTemplate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Template: ${_matchedTemplate!.name}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withOpacity(0.72),
                ),
              ),
            ],
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _fuelDetail = !_fuelDetail),
                  child: Text(_fuelDetail ? 'Simple' : 'Details'),
                ),
              ],
            ),
            Text('Distance: ${distance.toStringAsFixed(1)} NM'),
            Text('Flight fuel needed: $unitFuel'),
            const SizedBox(height: 10),
            if (_fuelDetail) ...[
              Text('Enroute:  ${f['enroute']!.toStringAsFixed(1)} gal'),
              const Text('Taxi:     3 gal'),
              const Text('Climb:    5 gal'),
              const Text('Reserve:  30 gal'),
              if ((f['required'] ?? 0) > 0)
                Text(
                  'Mission operating fuel:  ${f['required']!.toStringAsFixed(1)} gal',
                ),
              if ((f['payloadPenalty'] ?? 0) > 0)
                Text(
                  'Payload penalty fuel:  ${f['payloadPenalty']!.toStringAsFixed(1)} gal',
                ),
              const SizedBox(height: 6),
              Text('Total flight fuel: ${gal.toStringAsFixed(1)} gal'),
              Text('Flight fuel weight: ${lbs.toStringAsFixed(1)} lbs'),
            ],
          ],
        ),
      ),
    );
  }

  double vincentyDistanceNm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double a = 6378137.0;
    const double f = 1 / 298.257223563;
    final double b = (1 - f) * a;

    final double l = _rad(lon2 - lon1);
    final double u1 = atan((1 - f) * tan(_rad(lat1)));
    final double u2 = atan((1 - f) * tan(_rad(lat2)));

    final double sinU1 = sin(u1);
    final double cosU1 = cos(u1);
    final double sinU2 = sin(u2);
    final double cosU2 = cos(u2);

    double lambda = l;
    double lambdaPrev = l;

    const int maxIter = 100;
    int iter = 0;

    double sinLambda = 0;
    double cosLambda = 0;
    double sinSigma = 0;
    double cosSigma = 0;
    double sigma = 0;
    double cos2SigmaM = 0;
    double c = 0;

    do {
      sinLambda = sin(lambda);
      cosLambda = cos(lambda);

      sinSigma = sqrt(
        pow(cosU2 * sinLambda, 2) +
            pow(cosU1 * sinU2 - sinU1 * cosU2 * cosLambda, 2),
      );

      if (sinSigma == 0) return 0;

      cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      sigma = atan2(sinSigma, cosSigma);

      final denom = cosU1 * cosU2;
      if (denom == 0) {
        cos2SigmaM = 0;
      } else {
        cos2SigmaM = cosSigma - (2 * sinU1 * sinU2) / denom;
      }

      c =
          (f / 16) *
          pow(cosU1 * cosU2, 2) *
          (4 + f * (4 - 3 * pow(cosU1 * cosU2, 2)));

      lambdaPrev = lambda;
      lambda =
          l +
          (1 - c) *
              f *
              sinLambda *
              (sigma +
                  c *
                      sinSigma *
                      (cos2SigmaM +
                          c * cosSigma * (-1 + 2 * pow(cos2SigmaM, 2))));
    } while ((lambda - lambdaPrev).abs() > 1e-12 && ++iter < maxIter);

    if (iter >= maxIter) {
      return _haversineDistanceNm(lat1, lon1, lat2, lon2);
    }

    final double uSq = (pow(cosU1 * cosU2, 2) * (a * a - b * b)) / (b * b);

    final double bigA =
        1 + (uSq / 16384) * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));

    final double bigB =
        (uSq / 1024) * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));

    final double deltaSigma =
        bigB *
        sinSigma *
        (cos2SigmaM +
            (bigB / 4) *
                (cosSigma * (-1 + 2 * pow(cos2SigmaM, 2)) -
                    (bigB / 6) *
                        cos2SigmaM *
                        (-3 + 4 * pow(sinSigma, 2)) *
                        (-3 + 4 * pow(cos2SigmaM, 2))));

    final double s = b * bigA * (sigma - deltaSigma);

    return s / 1852.0;
  }

  double _payloadPenaltyFuel(double distanceNm) {
    if (activeJob == null) return 0;
    if (activeJob!.isFuelJob) return 0;

    final payload = jobPayloadWeightLbs();
    if (payload <= 0) return 0;

    final hours = distanceNm / _cruiseSpeedKts();
    return (payload / 200.0) * hours;
  }
}

class _AircraftHeaderCard extends StatelessWidget {
  const _AircraftHeaderCard({
    required this.title,
    required this.subtitle,
    required this.isLive,
    required this.hasLiveSignal,
  });

  final String title;
  final String subtitle;
  final bool isLive;
  final bool hasLiveSignal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      color: colors.surfaceContainerHighest.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withOpacity(0.12),
              ),
              child: Icon(
                isLive ? Icons.sensors : Icons.airplanemode_active,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (hasLiveSignal ? Colors.green : colors.outline)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isLive ? (hasLiveSignal ? 'LIVE' : 'NO SIGNAL') : 'HANGAR',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: hasLiveSignal ? Colors.green : colors.onSurface,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobImpactCard extends StatelessWidget {
  const _JobImpactCard({
    required this.payloadLbs,
    required this.payloadPenaltyFuelGal,
    required this.requiredFuelGal,
    required this.showMissionFuel,
    required this.transferFuelGallons,
    required this.transferFuelWeightLbs,
    this.mtowText,
  });

  final double payloadLbs;
  final double payloadPenaltyFuelGal;
  final double requiredFuelGal;
  final bool showMissionFuel;
  final double transferFuelGallons;
  final double transferFuelWeightLbs;
  final String? mtowText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.surfaceContainerHighest.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job Impact',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text('Payload weight: ${payloadLbs.toStringAsFixed(0)} lbs'),
            if (transferFuelGallons > 0)
              Text(
                'Transfer fuel cargo: ${transferFuelGallons.toStringAsFixed(1)} gal'
                ' • ${transferFuelWeightLbs.toStringAsFixed(0)} lbs',
              ),
            if (payloadPenaltyFuelGal > 0)
              Text(
                'Payload penalty fuel: +${payloadPenaltyFuelGal.toStringAsFixed(1)} gal',
              ),
            if (showMissionFuel && requiredFuelGal > 0)
              Text(
                'Mission operating fuel: +${requiredFuelGal.toStringAsFixed(1)} gal',
              ),
            if (mtowText != null) ...[
              const SizedBox(height: 6),
              Text(mtowText!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectedRouteSummaryCard extends StatelessWidget {
  const _SelectedRouteSummaryCard({
    required this.route,
    required this.fuelText,
    this.mtowWarning,
    this.rangeWarning,
  });

  final GeneratedRouteOption route;
  final String fuelText;
  final String? mtowWarning;
  final String? rangeWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      color: colors.primary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Route',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text('${route.originIcao} → ${route.destinationIcao}'),
            Text('Distance: ${route.distanceNm.toStringAsFixed(1)} NM'),
            Text('ETA: ${route.etaMinutes} min'),
            Text('Fuel: $fuelText'),
            Text('Cruise altitude: ${route.cruiseAltitude} ft'),
            if (mtowWarning != null) ...[
              const SizedBox(height: 8),
              Text(mtowWarning!),
            ],
            if (rangeWarning != null) ...[
              const SizedBox(height: 8),
              Text(
                rangeWarning!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
