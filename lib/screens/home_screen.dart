import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/models/user.dart';
import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/screens/aircraft_screen.dart';
import 'package:skycase/screens/dispatch_board_screen.dart';
import 'package:skycase/screens/flight_logs_screen.dart';
import 'package:skycase/screens/flight_planner_screen.dart';
import 'package:skycase/screens/job_details_screen.dart';
import 'package:skycase/screens/map_screen.dart';
import 'package:skycase/screens/settings_screen.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/flight_log_service.dart';
import 'package:skycase/services/metar_service.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/screens/ground_ops/aircraft_layout_builder_screen.dart';
import 'package:skycase/utils/session_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DispatchJob? _activeJob;
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
    _refreshHomeData();
  }

  Future<void> _refreshHomeData() async {
    await Future.wait([
      _loadActiveJob(),
      _loadMetar(),
      context.read<UserProvider>().refreshProfile(),
    ]);
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

  Future<void> _loadActiveJob() async {
    if (!mounted) return;

    setState(() {
      _loadingJob = true;
    });

    try {
      final user = context.read<UserProvider>().user;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _activeJob = null;
          _loadingJob = false;
        });
        return;
      }

      final job = await DispatchService.getActiveJob(user.id);

      if (!mounted) return;
      setState(() {
        _activeJob = job;
        _loadingJob = false;
      });
    } catch (e) {
      debugPrint("Failed to load active job: $e");

      if (!mounted) return;
      setState(() {
        _activeJob = null;
        _loadingJob = false;
      });
    }
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

  String _formatHours(double hours) {
    if (hours == 0) return "0.0h";
    return "${hours.toStringAsFixed(1)}h";
  }

  String _bestAirportLabel(UserStats stats) {
    return stats.favoriteArrivalAirport ??
        stats.favoriteDepartureAirport ??
        "—";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final user = context.watch<UserProvider>().user;
    final stats = user?.stats ?? UserStats.empty();
    final hqIcao = user?.hq?.icao;

    final exploredAirports =
        {...stats.departureAirports, ...stats.arrivalAirports}.length;

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: _refreshHomeData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),

                  _DispatchCard(
                    loading: _loadingJob,
                    job: _activeJob,
                    onRefresh: _loadActiveJob,
                  ),

                  const SizedBox(height: 26),

                  const _SectionHeader(
                    title: "Pilot Stats",
                    subtitle:
                        "Performance, operations and exploration footprint",
                  ),
                  const SizedBox(height: 14),

                  RepaintBoundary(
                    child: _PilotStatsCard(
                      stats: stats,
                      exploredAirports: exploredAirports,
                      totalHoursLabel: _formatHours(stats.totalFlightHours),
                      bestAirportLabel: _bestAirportLabel(stats),
                    ),
                  ),

                  const SizedBox(height: 34),

                  Text(
                    "Actions",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _ActionButton(
                    icon: Icons.map,
                    label: "Open Map",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MapScreen(
                                jobFrom: _activeJob?.fromIcao,
                                jobTo: _activeJob?.toIcao,
                                jobId: _activeJob?.id,
                              ),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.list_alt,
                    label: "View Flights",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FlightLogsScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.alt_route,
                    label: "Flight Planner",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FlightPlannerScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.airplanemode_active,
                    label: "Hangar",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AircraftScreen(),
                        ),
                      );
                    },
                  ),

                  _ActionButton(
                    icon: Icons.design_services,
                    label: "Aircraft Layout Builder",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AircraftLayoutBuilderScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.settings,
                    label: "Settings",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 56),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface.withOpacity(0.68),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PilotStatsCard extends StatelessWidget {
  final UserStats stats;
  final int exploredAirports;
  final String totalHoursLabel;
  final String bestAirportLabel;

  const _PilotStatsCard({
    required this.stats,
    required this.exploredAirports,
    required this.totalHoursLabel,
    required this.bestAirportLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 720;
        final topStatsPerRow = isTablet ? 3 : 2;
        final compactStatsPerRow = isTablet ? 4 : 2;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withOpacity(0.11),
                colors.primary.withOpacity(0.05),
                colors.surface.withOpacity(0.98),
              ],
            ),
            border: Border.all(
              color: colors.primary.withOpacity(0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PilotStatsHeader(),
              const SizedBox(height: 18),

              _ResponsiveStatGrid(
                columns: topStatsPerRow,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PrimaryStatBlock(
                    label: "Total Flights",
                    value: stats.totalFlights.toString(),
                  ),
                  _PrimaryStatBlock(
                    label: "Flight Hours",
                    value: totalHoursLabel,
                  ),
                  _PrimaryStatBlock(
                    label: "Jobs Done",
                    value: stats.jobsCompleted.toString(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surface.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.outline.withOpacity(0.08)),
                ),
                child: _ResponsiveStatGrid(
                  columns: compactStatsPerRow,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InlineStat(
                      icon: Icons.location_searching,
                      label: "Airports",
                      value: exploredAirports.toString(),
                    ),
                    _InlineStat(
                      icon: Icons.assignment_turned_in_outlined,
                      label: "Accepted",
                      value: stats.jobsAccepted.toString(),
                    ),
                    _InlineStat(
                      icon: Icons.cancel_outlined,
                      label: "Cancelled",
                      value: stats.jobsCancelled.toString(),
                    ),
                    _InlineStat(
                      icon: Icons.public,
                      label: "POIs",
                      value: stats.discoveredPoiCount.toString(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              _FeatureLine(
                icon: Icons.airplanemode_active,
                label: "Current favorite aircraft",
                value: stats.favoriteAircraft ?? "—",
              ),
              const SizedBox(height: 10),
              _FeatureLine(
                icon: Icons.place_outlined,
                label: "Favorite airport",
                value: bestAirportLabel,
              ),
              const SizedBox(height: 10),
              _FeatureLine(
                icon: Icons.flight_takeoff,
                label: "Route footprint",
                value:
                    "${stats.departureAirports.length} departures • ${stats.arrivalAirports.length} arrivals",
              ),
              const SizedBox(height: 10),
              _FeatureLine(
                icon: Icons.timelapse,
                label: "POI loiter time",
                value: "${stats.totalPoiLoiterMinutes.toStringAsFixed(0)} min",
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResponsiveStatGrid extends StatelessWidget {
  final int columns;
  final double spacing;
  final double runSpacing;
  final List<Widget> children;

  const _ResponsiveStatGrid({
    required this.columns,
    required this.spacing,
    required this.runSpacing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children:
              children
                  .map(
                    (child) => SizedBox(
                      width: width > 0 ? width : constraints.maxWidth,
                      child: child,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _PilotStatsHeader extends StatelessWidget {
  const _PilotStatsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: colors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.auto_graph, color: colors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "Pilot Performance",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FeatureLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.62),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryStatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _PrimaryStatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 1.0,
              color: colors.onSurface.withOpacity(0.58),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InlineStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.64),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ────────────────────────────────
   HERO HEADER
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
                    Colors.black.withOpacity(0.22),
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
                      Icon(_metarIcon(metar), size: 18, color: colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          metar ??
                              (icao != null ? "$icao • No METAR" : "Loading…"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
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
  final DispatchJob? job;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withOpacity(0.16)),
        color: colors.surface.withOpacity(0.30),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child:
          loading
              ? const Text("Loading dispatch…")
              : job == null
              ? _NoJob(onRefresh: onRefresh)
              : _ActiveJob(
                job: job!,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailsScreen(job: job!),
                    ),
                  );
                  onRefresh();
                },
              ),
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
              MaterialPageRoute(builder: (_) => const DispatchBoardScreen()),
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
  const _ActiveJob({required this.job, required this.onTap});

  final DispatchJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title.isNotEmpty ? job.title : "Active Job",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text("${job.fromIcao} → ${job.toIcao}"),
              const SizedBox(height: 6),
              Text("${job.distanceNm.toStringAsFixed(0)} NM"),
              const SizedBox(height: 6),
              Text("Status: ${job.status}"),
              const SizedBox(height: 4),
              Text("Phase: ${job.phase}"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.open_in_new, size: 18, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    "Open job details",
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
      ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.primary.withOpacity(0.16)),
              color: colors.surface.withOpacity(0.18),
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
      ),
    );
  }
}
