import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skycase/screens/job_details_screen.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/aircraft_service.dart';
import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/utils/session_manager.dart';

import '../models/dispatch_job.dart';
import '../models/learned_aircraft.dart';
import '../models/simlink_data.dart';

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

  bool _loading = true;
  bool _generating = false;

  String? _currentAirport;

  String? _lastAircraftId;
  DateTime? _lastAircraftSwitch;

  @override
  void initState() {
    super.initState();
    _init();
    _listenToSim();
  }

  @override
  void dispose() {
    _simSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────

  Future<void> _init() async {
    await _loadAircraft();
    await _fetchJobs();
  }

  Future<void> _loadAircraft() async {
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ Server main aircraft
    final main = await AircraftService.getMain();
    if (main != null) {
      prefs.setString("current_aircraft_id", main.id);
      _lastAircraftId = main.id;
      if (mounted) setState(() => _aircraft = main);
      return;
    }

    // 2️⃣ Stored
    final stored = prefs.getString("current_aircraft_id");
    if (stored != null) {
      final ac = await AircraftService.getOne(stored);
      if (ac != null) {
        _lastAircraftId = ac.id;
        if (mounted) setState(() => _aircraft = ac);
        return;
      }
    }

    // 3️⃣ Fallback → latest
    final all = await AircraftService.getAll();
    if (all.isNotEmpty) {
      prefs.setString("current_aircraft_id", all.first.id);
      _lastAircraftId = all.first.id;
      if (mounted) setState(() => _aircraft = all.first);
    }
  }

  // ─────────────────────────────────────────────
  // SIMLINK AUTO AIRCRAFT
  // ─────────────────────────────────────────────

  void _listenToSim() {
    _simSub = _sim.stream.listen((SimLinkData d) async {
      final id =
          d.title.trim().toLowerCase().replaceAll(" ", "_");

      if (id.isEmpty || id == "—") return;

      final now = DateTime.now();
      if (_lastAircraftSwitch != null &&
          now.difference(_lastAircraftSwitch!).inSeconds < 10) return;

      if (id == _lastAircraftId) return;

      _lastAircraftId = id;
      _lastAircraftSwitch = now;

      final prefs = await SharedPreferences.getInstance();
      prefs.setString("current_aircraft_id", id);

      final fresh = await AircraftService.getOne(id);
      if (!mounted || fresh == null) return;

      setState(() => _aircraft = fresh);
      _fetchJobs();
    });
  }

  // ─────────────────────────────────────────────
  // JOBS
  // ─────────────────────────────────────────────

  Future<void> _fetchJobs() async {
    if (_aircraft == null) return;

    setState(() => _loading = true);

    try {
      final lastDest = await DispatchService.getLastDestination();
      final list = lastDest != null && lastDest.isNotEmpty
          ? await DispatchService.getOpenJobs(airport: lastDest)
          : await DispatchService.getOpenJobs();

      if (!mounted) return;
      setState(() {
        _jobs = list;
        _currentAirport = lastDest;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateJobs() async {
    final userId = await SessionManager.getUserId();
    if (userId == null) return;

    setState(() {
      _generating = true;
      _jobs = [];
    });

    final lastDest = await DispatchService.getLastDestination();
    await DispatchService.generateJobs(userId, airport: lastDest);

    if (!mounted) return;
    setState(() => _generating = false);

    _fetchJobs();
  }

  // ─────────────────────────────────────────────
  // JOB FIT (CACHED, FAST)
  // ─────────────────────────────────────────────

  bool _fitsAircraft(DispatchJob job) {
    final ac = _aircraft;
    if (ac == null) return true;

    if (job.payloadLbs > 0 &&
        ac.mtow != null &&
        ac.emptyWeight != null &&
        job.payloadLbs > (ac.mtow! - ac.emptyWeight!)) return false;

    if (job.paxCount > 0) {
      if ((ac.mtow ?? 0) < 3000 && job.paxCount > 3) return false;
      if ((ac.mtow ?? 0) < 5000 && job.paxCount > 6) return false;
    }

    if (job.type == "fuel") {
      final cap = ac.fuelCapacityGallons ?? 0;
      if (cap <= 0 || job.transferFuelGallons > cap) return false;
    }

    return true;
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentAirport == null
                  ? "Dispatch Board"
                  : "Jobs at ${_currentAirport!.toUpperCase()}",
            ),
            Text(
              "Aircraft: ${_aircraft?.title ?? "Detecting…"}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? _EmptyState(onGenerate: _generateJobs)
              : RefreshIndicator(
                  onRefresh: _fetchJobs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _jobs.length,
                    itemBuilder: (_, i) {
                      final job = _jobs[i];
                      return DispatchJobCard(
                        job: job,
                        fits: _fitsAircraft(job),
                        onTap: () async {
                          final changed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  JobDetailsScreen(job: job.toJson()),
                            ),
                          );
                          if (changed == true) _fetchJobs();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

/* ─────────────────────────────────────────────
   JOB CARD (PURE WIDGET)
───────────────────────────────────────────── */

class DispatchJobCard extends StatelessWidget {
  const DispatchJobCard({
    super.key,
    required this.job,
    required this.fits,
    required this.onTap,
  });

  final DispatchJob job;
  final bool fits;
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
        border: Border.all(color: typeColor.withOpacity(0.4), width: 1.4),
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (job.isPriority)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "PRIORITY",
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(job.fromIcao,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.flight_takeoff),
              const Spacer(),
              Text(job.toIcao,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.navigation, size: 16),
              const SizedBox(width: 6),
              Text("${job.distanceNm.toStringAsFixed(0)} NM"),
              const Spacer(),
              const Icon(Icons.payments, size: 16),
              const SizedBox(width: 6),
              Text("${job.reward} cr"),
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
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Not suitable for your aircraft",
                      style: TextStyle(
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
              child: const Text("Details"),
            ),
          ),
        ],
      ),
    );
  }

  static Color _typeColor(String type, Brightness b) {
    final base = {
          "cargo": Colors.orange,
          "pax": Colors.blue,
          "fuel": Colors.amber,
          "priority": Colors.red,
          "ferry": Colors.green,
        }[type] ??
        Colors.grey;
    return b == Brightness.dark ? base.withOpacity(0.25) : base;
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case "cargo":
        return Icons.inventory_2_rounded;
      case "pax":
        return Icons.airline_seat_recline_normal;
      case "fuel":
        return Icons.local_gas_station;
      case "priority":
        return Icons.priority_high;
      case "ferry":
        return Icons.airplanemode_active;
      default:
        return Icons.workspaces;
    }
  }
}

/* ───────────────────────────────────────────── */

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.airplane_ticket, size: 80),
          const SizedBox(height: 18),
          const Text("No dispatch jobs available"),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onGenerate,
            child: const Text("Generate Jobs"),
          ),
        ],
      ),
    );
  }
}
