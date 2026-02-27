import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/screens/aircraft_screen.dart';
import 'package:skycase/screens/job_details_screen.dart';
import 'package:skycase/screens/route_builder_screen.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/screens/dispatch_board_screen.dart';
import 'package:skycase/screens/map_screen.dart';
import 'package:skycase/screens/flight_logs_screen.dart';
import 'package:skycase/screens/settings_screen.dart';
import 'package:skycase/services/flight_log_service.dart';
import 'package:skycase/services/metar_service.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/widgets/flight_generator_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _activeJob;
  bool _loadingJob = true;

  String? _metar;
  String? _icao;

  late final String _heroImage;
  late final String _utcTime;
  late final String _utcDate;

  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    _initStaticData();
    _loadActiveJob();
    _loadMetar();
  }

  void _initStaticData() {
    final now = DateTime.now().toUtc();
    _utcTime = "${DateFormat("HH:mm").format(now)} UTC";
    _utcDate = DateFormat("dd MMM yyyy").format(now);

    const heroImages = [
      "assets/images/home_backgrounds/bg1.png",
      "assets/images/home_backgrounds/bg2.png",
    ];

    _heroImage = heroImages[(DateTime.now().minute ~/ 30) % heroImages.length];
  }

  // ─────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────

  Future<void> _loadActiveJob() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final job = await DispatchService.getActiveJob(user.id);

    if (!mounted) return;
    setState(() {
      _activeJob = job;
      _loadingJob = false;
    });
  }

  Future<void> _loadMetar() async {
    try {
      final icao = await _getLastKnownIcao();
      final line = await MetarService.getAmbientLine(icao);

      if (!mounted) return;
      setState(() {
        _icao = icao;
        _metar = line;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _icao = "LGAV";
        _metar = null;
      });
    }
  }

  Future<String> _getLastKnownIcao() async {
    try {
      final userId = await SessionManager.getUserId();
      if (userId != null) {
        final logs = await FlightLogService.getFlightLogs(userId);
        if (logs.isNotEmpty && logs.first.endLocation?.icao != null) {
          return logs.first.endLocation!.icao!.toUpperCase();
        }
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

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hqIcao = context.select<UserProvider, String?>(
      (p) => p.user?.hq?.icao,
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _HeroHeader(
            heroImage: _heroImage,
            utcTime: _utcTime,
            utcDate: _utcDate,
            hqIcao: hqIcao,
            metar: _metar,
            icao: _icao,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  const SizedBox(height: 24),
                  _DispatchCard(
                    loading: _loadingJob,
                    job: _activeJob,
                    onRefresh: _loadActiveJob,
                  ),
                  const SizedBox(height: 36),
                  Text(
                    "Actions",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ActionButton(
                    icon: Icons.map,
                    label: "Open Map",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapScreen(
                            jobFrom: _activeJob?["fromIcao"],
                            jobTo: _activeJob?["toIcao"],
                            jobId: _activeJob?["_id"],
                          ),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.list_alt,
                    label: "View Flights",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FlightLogsScreen(),
                      ),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.flight_takeoff,
                    label: "Plan Random Direct Flight",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FlightGeneratorScreen(),
                      ),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.route,
                    label: "Plan Route Flight",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteBuilderScreen(),
                      ),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.airplanemode_active,
                    label: "Aircraft",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AircraftScreen(),
                      ),
                    ),
                  ),
                  _ActionButton(
                    icon: Icons.settings,
                    label: "Settings",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ────────────────────────────────
   HERO HEADER (PURE, FAST)
──────────────────────────────── */

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.heroImage,
    required this.utcTime,
    required this.utcDate,
    required this.hqIcao,
    required this.metar,
    required this.icao,
  });

  final String heroImage;
  final String utcTime;
  final String utcDate;
  final String? hqIcao;
  final String? metar;
  final String? icao;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 280,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(heroImage, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.25),
                    colors.background.withOpacity(0.95),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SkyCaseFS",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$utcTime • $utcDate",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onBackground.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hqIcao != null ? "HQ • $hqIcao" : "HQ not set",
                    style: theme.textTheme.bodySmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        _metarIcon(metar),
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        metar ??
                            (icao != null
                                ? "$icao • No METAR"
                                : "Loading…"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _metarIcon(String? metar) {
    if (metar == null) return Icons.help_outline;
    if (metar.contains("TS")) return Icons.flash_on;
    if (metar.contains("RA")) return Icons.umbrella;
    if (metar.contains("SN")) return Icons.ac_unit;
    if (metar.contains("OVC") || metar.contains("BKN")) return Icons.cloud;
    return Icons.wb_sunny;
  }
}

/* ────────────────────────────────
   DISPATCH CARD
──────────────────────────────── */

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({
    required this.loading,
    required this.job,
    required this.onRefresh,
  });

  final bool loading;
  final Map<String, dynamic>? job;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withOpacity(0.2)),
        color: colors.surface.withOpacity(0.25),
      ),
      child: loading
          ? const Text("Loading dispatch…")
          : job == null
              ? _NoJob(onRefresh: onRefresh)
              : _ActiveJob(job: job!),
    );
  }
}

class _NoJob extends StatelessWidget {
  const _NoJob({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Current Dispatch Job"),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () async {
            final accepted = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DispatchBoardScreen(),
              ),
            );
            if (accepted == true) onRefresh();
          },
          icon: const Icon(Icons.assignment),
          label: const Text("Open Job Board"),
        ),
      ],
    );
  }
}

class _ActiveJob extends StatelessWidget {
  const _ActiveJob({required this.job});
  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job["title"] ?? "Active Job",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text("${job["fromIcao"]} → ${job["toIcao"]}"),
        const SizedBox(height: 6),
        Text("${job["distanceNm"]?.toStringAsFixed(0)} NM"),
      ],
    );
  }
}

/* ────────────────────────────────
   ACTION BUTTON
──────────────────────────────── */

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 14),
              Expanded(child: Text(label)),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
