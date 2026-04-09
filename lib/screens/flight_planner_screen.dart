import 'package:flutter/material.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/screens/route_builder_screen.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/widgets/flight_generator_screen.dart';

class FlightPlannerScreen extends StatefulWidget {
  const FlightPlannerScreen({super.key});

  @override
  State<FlightPlannerScreen> createState() => _FlightPlannerScreenState();
}

class _FlightPlannerScreenState extends State<FlightPlannerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _currentIndex = 0;

  /// lazy build flags so we do not mount heavy screens too early
  bool _directBuilt = true;
  bool _routeBuilt = false;

  DispatchJob? _activeJob;
  bool _loadingJob = true;

  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    _loadActiveJob();
  }

  Future<void> _loadActiveJob() async {
    try {
      final userId = await SessionManager.getUserId();

      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _activeJob = null;
          _loadingJob = false;
        });
        return;
      }

      final job = await DispatchService.getActiveJob(userId);

      if (!mounted) return;
      setState(() {
        _activeJob = job;
        _loadingJob = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeJob = null;
        _loadingJob = false;
      });
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;

    final nextIndex = _tabController.index;
    if (nextIndex == _currentIndex) return;

    setState(() {
      _currentIndex = nextIndex;

      if (_currentIndex == 0) {
        _directBuilt = true;
      } else if (_currentIndex == 1) {
        _routeBuilt = true;
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPlannerBody() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _directBuilt
    ? FlightGeneratorScreen(
        showAppBar: false,
        activeJob: _activeJob,
      )
    : const SizedBox.expand(),
        _routeBuilt
            ? const RouteBuilderScreen(showAppBar: false)
            : const _PlannerLoadingPlaceholder(
              icon: Icons.route_rounded,
              title: 'Route Builder',
              subtitle: 'Preparing map and route tools...',
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Flight Planner'),
        centerTitle: false,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurface.withOpacity(0.65),
          dividerColor: colors.outline.withOpacity(0.14),
          tabs: const [
            Tab(icon: Icon(Icons.flight_takeoff_rounded), text: 'Direct'),
            Tab(icon: Icon(Icons.route_rounded), text: 'Route Builder'),
          ],
        ),
      ),
      body: Column(
        children: [
         _PlannerIntroCard(
  isDark: isDark,
  activeJob: _activeJob,
  loadingJob: _loadingJob,
  currentIndex: _currentIndex,
),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _buildPlannerBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerIntroCard extends StatelessWidget {
  const _PlannerIntroCard({
    required this.isDark,
    required this.activeJob,
    required this.loadingJob,
    required this.currentIndex,
  });

  final bool isDark;
  final DispatchJob? activeJob;
  final bool loadingJob;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final bool isDirectTab = currentIndex == 0;

    String text;
    IconData icon;

    if (isDirectTab) {
      if (loadingJob) {
        text = 'Checking active dispatch job...';
        icon = Icons.hourglass_top_rounded;
      } else if (activeJob != null) {
        text =
            'Active dispatch job loaded: ${activeJob!.fromIcao} → ${activeJob!.toIcao}. '
            'Use Direct to generate a plan around your current accepted mission.';
        icon = Icons.assignment_turned_in_rounded;
      } else {
        text =
            'No active dispatch job found. Use Direct for a quick generated flight plan.';
        icon = Icons.flight_takeoff_rounded;
      }
    } else {
      text =
          'Route Builder is for SimBrief imports and manual route planning. It does not use dispatch job data.';
      icon = Icons.route_rounded;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(isDark ? 0.75 : 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primary.withOpacity(0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withOpacity(0.12),
              border: Border.all(
                color: colors.primary.withOpacity(0.22),
              ),
            ),
            child: Icon(
              icon,
              color: colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: colors.onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
class _PlannerLoadingPlaceholder extends StatelessWidget {
  const _PlannerLoadingPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(isDark ? 0.85 : 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primary.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withOpacity(0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
