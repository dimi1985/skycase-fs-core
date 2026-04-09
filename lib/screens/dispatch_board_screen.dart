import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skycase/models/aircraft_planning_spec.dart';
import 'package:skycase/models/aircraft_planning_spec_resolver.dart';
import 'package:skycase/models/aircraft_template.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/models/dispatch_job_fit_result.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/screens/job_details_screen.dart';
import 'package:skycase/services/aircraft_service.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/utils/dispatch_job_evaluator.dart';
import 'package:skycase/utils/session_manager.dart';

class DispatchBoardScreen extends StatefulWidget {
  const DispatchBoardScreen({super.key});

  @override
  State<DispatchBoardScreen> createState() => _DispatchBoardScreenState();
}

class _DispatchBoardScreenState extends State<DispatchBoardScreen> {
  final SimLinkSocketService _sim = SimLinkSocketService();
  StreamSubscription<SimLinkData>? _simSub;

  List<DispatchJob> _jobs = [];
  LearnedAircraft? _aircraft;

  List<AircraftTemplate> _templates = [];
  AircraftTemplate? _matchedTemplate;

  bool _loading = true;
  bool _loadingTemplates = true;
  bool _generating = false;

  String? _boardAirport;
  String? _requestedAirport;
  bool _showingFallbackBoard = false;

  String? _lastAircraftId;
  DateTime? _lastAircraftSwitchAt;

  SimLinkData? get _simData => _sim.latestData;

  AircraftPlanningSpec? get _planningSpec =>
      AircraftPlanningSpecResolver.resolve(
        sim: _simData,
        hangarAircraft: _aircraft,
        matchedTemplate: _matchedTemplate,
        title: _aircraft?.title ?? _simData?.title ?? '',
      );

  @override
  void initState() {
    super.initState();
    _boot();
    _listenToSim();
  }

  @override
  void dispose() {
    _simSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BOOT
  // ─────────────────────────────────────────────

  Future<void> _boot() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      await _loadTemplates();
      await _loadAircraft();
      _refreshMatchedTemplate();
      await _fetchJobs(showLoader: false);
    } catch (e, st) {
      debugPrint('❌ DispatchBoard _boot error: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/aircraft_templates.json',
      );
      final list = jsonDecode(raw) as List;

      final parsed = list
          .map((e) => AircraftTemplate.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _templates = parsed;
        _loadingTemplates = false;
      });
    } catch (e, st) {
      debugPrint('⚠️ Template load failed: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;
      setState(() => _loadingTemplates = false);
    }
  }

  Future<void> _loadAircraft() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final main = await AircraftService.getMain();
      if (main != null) {
        await prefs.setString('current_aircraft_id', main.id);
        _lastAircraftId = main.id;

        if (!mounted) return;
        setState(() {
          _aircraft = main;
          _refreshMatchedTemplate();
        });
        return;
      }
    } catch (e) {
      debugPrint('⚠️ getMain aircraft failed: $e');
    }

    final storedId = prefs.getString('current_aircraft_id');
    if (storedId != null && storedId.trim().isNotEmpty) {
      try {
        final storedAircraft = await AircraftService.getOne(storedId);
        if (storedAircraft != null) {
          _lastAircraftId = storedAircraft.id;

          if (!mounted) return;
          setState(() {
            _aircraft = storedAircraft;
            _refreshMatchedTemplate();
          });
          return;
        }
      } catch (e) {
        debugPrint('⚠️ get stored aircraft failed: $e');
      }
    }

    try {
      final all = await AircraftService.getAll();
      if (all.isNotEmpty) {
        final fallback = all.first;
        await prefs.setString('current_aircraft_id', fallback.id);
        _lastAircraftId = fallback.id;

        if (!mounted) return;
        setState(() {
          _aircraft = fallback;
          _refreshMatchedTemplate();
        });
      }
    } catch (e) {
      debugPrint('⚠️ getAll aircraft failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  // TEMPLATE MATCHING
  // ─────────────────────────────────────────────

  void _refreshMatchedTemplate() {
    _matchedTemplate = _resolveTemplate();
  }

  AircraftTemplate? _resolveTemplate() {
    if (_templates.isEmpty) return null;

    final candidate = (_aircraft?.title ?? _simData?.title ?? '').trim();
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
      'cessna 208': 'C208',
      'caravan': 'C208',
      'bonanza': 'BONANZA_G36',
      'g36': 'BONANZA_G36',
      '414': 'C414A',
      'chancellor': 'C414A',
      'sr22': 'SR22',
      'warrior': 'PA28_WARRIOR',
      'pa28': 'PA28_WARRIOR',
      'dv20': 'DV20',
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
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeAircraftId(String rawTitle) {
    return rawTitle.trim().toLowerCase().replaceAll(' ', '_');
  }

  // ─────────────────────────────────────────────
  // SIM AUTO AIRCRAFT REFRESH
  // ─────────────────────────────────────────────

  void _listenToSim() {
    _simSub = _sim.stream.listen((SimLinkData data) async {
      final simTitle = data.title.trim();
      if (simTitle.isEmpty || simTitle == '—') return;

      final normalizedId = _normalizeAircraftId(simTitle);
      if (normalizedId.isEmpty) return;

      final now = DateTime.now();

      if (_lastAircraftSwitchAt != null &&
          now.difference(_lastAircraftSwitchAt!).inSeconds < 10) {
        return;
      }

      if (normalizedId == _lastAircraftId) return;

      _lastAircraftId = normalizedId;
      _lastAircraftSwitchAt = now;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_aircraft_id', normalizedId);

      try {
        final fresh = await AircraftService.getOne(normalizedId);
        if (!mounted || fresh == null) return;

        setState(() {
          _aircraft = fresh;
          _refreshMatchedTemplate();
        });

        await _fetchJobs();
      } catch (e) {
        debugPrint('⚠️ Sim aircraft refresh failed: $e');
      }
    });
  }

  // ─────────────────────────────────────────────
  // DISPATCH BOARD LOGIC
  // ─────────────────────────────────────────────

  Future<void> _fetchJobs({bool showLoader = true}) async {
    if (_aircraft == null) {
      if (mounted && showLoader) {
        setState(() {
          _loading = false;
          _jobs = [];
          _boardAirport = null;
          _requestedAirport = null;
          _showingFallbackBoard = false;
        });
      }
      return;
    }

    if (mounted && showLoader) {
      setState(() => _loading = true);
    }

    try {
      final requestedAirport = await _getRequestedAirport();
      _requestedAirport = requestedAirport;

      // 1) Try exact airport board first
      if (requestedAirport != null) {
        final directJobs = await DispatchService.getOpenJobs(
          airport: requestedAirport,
        );

        if (directJobs.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _jobs = directJobs;
            _boardAirport = requestedAirport;
            _showingFallbackBoard = false;
          });
          return;
        }
      }

      // 2) Try global open jobs before generating
      final openGlobalJobs = await DispatchService.getOpenJobs();
      final resolvedGlobal = _resolveBoardAirportFromJobs(openGlobalJobs);

      if (openGlobalJobs.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _jobs = openGlobalJobs;
          _boardAirport = resolvedGlobal;
          _showingFallbackBoard = true;
        });
        return;
      }

      // 3) Still empty -> generate
      final userId = await SessionManager.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _jobs = [];
          _boardAirport = null;
          _showingFallbackBoard = false;
        });
        return;
      }

      final generationResult = await DispatchService.generateJobs(
        userId,
        airport: requestedAirport,
        planningSpec: _planningSpec,
      );

      final generatedOrigin = generationResult?['origin']
          ?.toString()
          .trim()
          .toUpperCase();

      // 4) First try fetching the actual generated origin
      if (generatedOrigin != null && generatedOrigin.isNotEmpty) {
        final generatedJobs = await DispatchService.getOpenJobs(
          airport: generatedOrigin,
        );

        if (generatedJobs.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _jobs = generatedJobs;
            _boardAirport = generatedOrigin;
            _showingFallbackBoard = requestedAirport != generatedOrigin;
          });
          return;
        }
      }

      // 5) If backend gave nothing usable, retry requested airport
      if (requestedAirport != null) {
        final retryRequested = await DispatchService.getOpenJobs(
          airport: requestedAirport,
        );

        if (retryRequested.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _jobs = retryRequested;
            _boardAirport = requestedAirport;
            _showingFallbackBoard = false;
          });
          return;
        }
      }

      // 6) Final fallback: any open jobs
      final finalGlobalJobs = await DispatchService.getOpenJobs();
      final finalResolvedGlobal = _resolveBoardAirportFromJobs(finalGlobalJobs);

      if (!mounted) return;
      setState(() {
        _jobs = finalGlobalJobs;
        _boardAirport = finalResolvedGlobal;
        _showingFallbackBoard = finalGlobalJobs.isNotEmpty;
      });
    } catch (e, st) {
      debugPrint('❌ _fetchJobs error: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _generateJobs() async {
    final userId = await SessionManager.getUserId();
    if (userId == null) return;

    if (mounted) {
      setState(() {
        _generating = true;
        _jobs = [];
      });
    }

    try {
      final requestedAirport = await _getRequestedAirport();
      _requestedAirport = requestedAirport;

      final generationResult = await DispatchService.generateJobs(
        userId,
        airport: requestedAirport,
        planningSpec: _planningSpec,
      );

      final generatedOrigin = generationResult?['origin']
          ?.toString()
          .trim()
          .toUpperCase();

      if (generatedOrigin != null && generatedOrigin.isNotEmpty) {
        final exactJobs = await DispatchService.getOpenJobs(
          airport: generatedOrigin,
        );

        if (exactJobs.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _jobs = exactJobs;
            _boardAirport = generatedOrigin;
            _showingFallbackBoard = requestedAirport != generatedOrigin;
          });
          return;
        }
      }

      await _fetchJobs(showLoader: false);
    } catch (e, st) {
      debugPrint('❌ _generateJobs error: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<String?> _getRequestedAirport() async {
    final raw = await DispatchService.getLastDestination();
    if (raw == null) return null;

    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;

    return value;
  }

  String? _resolveBoardAirportFromJobs(List<DispatchJob> jobs) {
    if (jobs.isEmpty) return null;

    final unique = jobs
        .map((j) => j.fromIcao.trim().toUpperCase())
        .where((v) => v.isNotEmpty)
        .toSet();

    if (unique.length == 1) {
      return unique.first;
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // JOB FIT
  // ─────────────────────────────────────────────

  DispatchJobFitResult _jobFit(DispatchJob job) {
    return DispatchJobEvaluator.evaluate(
      job: job,
      spec: _planningSpec,
      departureFuelLbs: _plannedDepartureFuelLbs(job, _planningSpec),
    );
  }

  double? _plannedDepartureFuelLbs(
    DispatchJob job,
    AircraftPlanningSpec? spec,
  ) {
    if (spec == null) return null;
    if (spec.cruiseSpeedKts <= 0) return null;
    if (spec.fuelBurnGph <= 0) return null;
    if (spec.fuelDensity <= 0) return null;

    final tripHours = job.distanceNm / spec.cruiseSpeedKts;
    if (tripHours <= 0) return null;

    const taxiGallons = 3.0;
    const climbGallons = 5.0;
    const reserveGallons = 30.0;

    final tripGallons = tripHours * spec.fuelBurnGph;
    final departureGallons =
        taxiGallons + climbGallons + reserveGallons + tripGallons;

    return departureGallons * spec.fuelDensity;
  }

  // ─────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────

  Future<void> _openDetails(DispatchJob job) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailsScreen(job: job)),
    );

    if (changed == true) {
      await _fetchJobs();
    }
  }

  // ─────────────────────────────────────────────
  // BUILD HELPERS
  // ─────────────────────────────────────────────

  String _buildAircraftSubtitle() {
    final spec = _planningSpec;

    if (_aircraft == null) {
      return _loading ? 'Detecting Aircraft...' : 'No Aircraft Selected';
    }

    if (spec == null) {
      return 'Aircraft: ${_aircraft!.title}';
    }

    return 'Aircraft: ${_aircraft!.title} • '
        '${spec.cruiseSpeedKts.toStringAsFixed(0)} kts • '
        '${spec.usableRangeNm?.toStringAsFixed(0) ?? '--'} NM usable';
  }

  Color _buildAircraftSubtitleColor() {
    return _aircraft == null ? Colors.orangeAccent : Colors.grey;
  }

  String _buildBoardTitle() {
    if (_boardAirport == null || _boardAirport!.isEmpty) {
      return 'Dispatch Board';
    }
    return 'Jobs at ${_boardAirport!}';
  }

  String? _buildBoardBannerText() {
    if (!_showingFallbackBoard) return null;

    final requested = _requestedAirport;
    final actual = _boardAirport;

    if (requested != null &&
        requested.isNotEmpty &&
        actual != null &&
        actual.isNotEmpty &&
        requested != actual) {
      return 'No jobs were available at $requested. Showing jobs from $actual instead.';
    }

    if (requested != null && requested.isNotEmpty && actual == null) {
      return 'No jobs were available at $requested. Showing the global dispatch board instead.';
    }

    if (requested != null &&
        requested.isNotEmpty &&
        actual != null &&
        actual == requested) {
      return null;
    }

    return 'Showing available jobs from the wider dispatch board.';
  }

  @override
  Widget build(BuildContext context) {
    final busyLoading = _loading || _loadingTemplates;
    final bannerText = _buildBoardBannerText();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_buildBoardTitle()),
            Text(
              _buildAircraftSubtitle(),
              style: TextStyle(
                fontSize: 12,
                color: _buildAircraftSubtitleColor(),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _generating ? null : _generateJobs,
          ),
        ],
      ),
      body: busyLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking Aircraft & Jobs...'),
                ],
              ),
            )
          : _aircraft == null
              ? _NoAircraftState(onRetry: _boot)
              : _jobs.isEmpty
                  ? _EmptyState(
                      onGenerate: _generateJobs,
                      currentAirport: _requestedAirport,
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchJobs,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (bannerText != null) ...[
                            _DispatchBoardBanner(text: bannerText),
                            const SizedBox(height: 12),
                          ],
                          ..._jobs.map((job) {
                            final fit = _jobFit(job);

                            return DispatchJobCard(
                              job: job,
                              fits: fit.fits,
                              fitReason: fit.reason,
                              onTap: () => _openDetails(job),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}

/* ─────────────────────────────────────────────
   BOARD BANNER
───────────────────────────────────────────── */

class _DispatchBoardBanner extends StatelessWidget {
  const _DispatchBoardBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────────────────────────
   JOB CARD
───────────────────────────────────────────── */

class DispatchJobCard extends StatelessWidget {
  const DispatchJobCard({
    super.key,
    required this.job,
    required this.fits,
    required this.onTap,
    this.fitReason,
  });

  final DispatchJob job;
  final bool fits;
  final String? fitReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typeColor = _typeColor(job.type, theme.brightness);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _borderColor(typeColor, theme.brightness),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcon(job.type), color: typeColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (job.isPriority)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PRIORITY',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                job.fromIcao,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.flight_takeoff),
              const Spacer(),
              Text(
                job.toIcao,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.navigation, size: 16),
              const SizedBox(width: 6),
              Text('${job.distanceNm.toStringAsFixed(0)} NM'),
              const Spacer(),
              const Icon(Icons.payments, size: 16),
              const SizedBox(width: 6),
              Text('${job.reward} cr'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(
                context,
                icon: Icons.category_outlined,
                label: job.type.toUpperCase(),
              ),
              if (job.paxCount > 0)
                _metaChip(
                  context,
                  icon: Icons.airline_seat_recline_normal,
                  label: '${job.paxCount} pax',
                ),
              if (job.effectivePayloadLbs > 0)
                _metaChip(
                  context,
                  icon: Icons.scale_outlined,
                  label: '${job.effectivePayloadLbs} lbs',
                ),
            ],
          ),
          if (!fits) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fitReason ?? 'Not suitable for your aircraft',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              child: const Text('Details'),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  static Color _borderColor(Color base, Brightness brightness) {
    return brightness == Brightness.dark
        ? base.withOpacity(0.45)
        : base.withOpacity(0.35);
  }

  static Color _typeColor(String type, Brightness brightness) {
    switch (type.toLowerCase()) {
      case 'cargo':
        return Colors.orange;
      case 'pax':
        return Colors.blue;
      case 'fuel':
        return Colors.amber;
      case 'priority':
        return Colors.red;
      case 'ferry':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'cargo':
        return Icons.inventory_2_rounded;
      case 'pax':
        return Icons.airline_seat_recline_normal;
      case 'fuel':
        return Icons.local_gas_station;
      case 'priority':
        return Icons.priority_high;
      case 'ferry':
        return Icons.airplanemode_active;
      default:
        return Icons.workspaces;
    }
  }
}

/* ───────────────────────────────────────────── */

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onGenerate,
    this.currentAirport,
  });

  final VoidCallback onGenerate;
  final String? currentAirport;

  @override
  Widget build(BuildContext context) {
    final isNewUser = currentAirport == null || currentAirport!.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNewUser ? Icons.explore_off_outlined : Icons.airplane_ticket,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 18),
            Text(
              isNewUser ? 'Welcome to SkyCase!' : 'No dispatch jobs available',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isNewUser
                  ? "We couldn't find a Home Base (HQ) or a previous flight location for you. Please generate jobs to start your career from a random airport, or set your HQ in profile."
                  : 'There are no jobs currently at ${currentAirport!.toUpperCase()}. You can try to generate new ones below.',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                isNewUser ? 'Start My First Flight' : 'Generate Jobs',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAircraftState extends StatelessWidget {
  const _NoAircraftState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.airplanemode_inactive,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Aircraft Detected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please start your Simulator and SimLink, or select an aircraft from your hangar to see compatible jobs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Detection'),
            ),
          ],
        ),
      ),
    );
  }
}