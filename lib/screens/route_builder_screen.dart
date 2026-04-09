import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:skycase/providers/simbrief_provider.dart';
import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/services/flight_plan_service.dart';
import 'package:skycase/services/simbrief_service.dart';
import '../providers/route_builder_provider.dart';

class RouteBuilderScreen extends StatefulWidget {
  const RouteBuilderScreen({
    super.key,
    this.showAppBar = true,
  });

  final bool showAppBar;

  @override
  State<RouteBuilderScreen> createState() => _RouteBuilderScreenState();
}

class _RouteBuilderScreenState extends State<RouteBuilderScreen> {
  final MapController _mapController = MapController();
  final SimBriefService _simBriefService = SimBriefService();

  bool _importing = false;
  bool _saving = false;

  SimBriefImportResult? _ofp;
  int? _importedCruiseAltitudeFt;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RouteBuilderProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RouteBuilderProvider>();
    final simBrief = context.watch<SimBriefProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final points = vm.route.map<LatLng>((e) => LatLng(e.lat, e.lon)).toList();

    final content = Column(
      children: [
        _buildMap(context: context, points: points),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                child: Row(
                  children: [
                    _RoundAccentIcon(
                      icon: Icons.cloud_sync,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SimBrief Source",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            simBrief.hasCredentials
                                ? [
                                    if (simBrief.username.trim().isNotEmpty)
                                      "User: ${simBrief.username.trim()}",
                                    if (simBrief.pilotId.trim().isNotEmpty)
                                      "Pilot ID: ${simBrief.pilotId.trim()}",
                                  ].join(" • ")
                                : "No SimBrief credentials found in Settings",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _importing
                          ? null
                          : simBrief.hasCredentials
                              ? () => _importFromStoredSimBrief(vm)
                              : null,
                      icon: _importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_importing ? "Loading..." : "Import OFP"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_ofp != null) _buildMiniOfpCard(context),
              if (_ofp != null) const SizedBox(height: 16),
              if (_ofp != null) _buildRoutePreviewCard(context, vm),
              if (_ofp == null) _buildEmptyState(context, isDark),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: (_ofp == null || vm.route.isEmpty || _saving)
                    ? null
                    : () => _saveRoute(vm),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? "Saving..." : "Save Flight Plan"),
              ),
              const SizedBox(height: 14),
              if (_ofp != null)
                OutlinedButton.icon(
                  onPressed: () {
                    vm.clear();
                    setState(() {
                      _ofp = null;
                      _importedCruiseAltitudeFt = null;
                    });
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text("Clear Imported OFP"),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return ColoredBox(
        color: colors.background,
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text("SimBrief Import"),
        centerTitle: false,
      ),
      body: content,
    );
  }

  Widget _buildMap({
    required BuildContext context,
    required List<LatLng> points,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 260,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              points.isNotEmpty ? points.first : const LatLng(37.98, 23.72),
          initialZoom: points.length >= 2 ? 8.5 : 6.5,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.drag |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          TileLayer(
            retinaMode: true,
            urlTemplate: isDark
                ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.skycase.app',
            maxZoom: 20,
          ),
          if (points.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 5,
                  color: Colors.cyanAccent,
                ),
              ],
            ),
          if (points.isNotEmpty)
            MarkerLayer(
              markers: List.generate(points.length, (i) {
                final point = points[i];
                final isFirst = i == 0;
                final isLast = i == points.length - 1;

                return Marker(
                  point: point,
                  width: 38,
                  height: 38,
                  child: Icon(
                    isFirst
                        ? Icons.flight_takeoff
                        : isLast
                            ? Icons.flight_land
                            : Icons.radio_button_checked,
                    color: isFirst || isLast
                        ? Colors.orangeAccent
                        : Colors.cyanAccent,
                    size: isFirst || isLast ? 24 : 14,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniOfpCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _RoundAccentIcon(
                icon: Icons.description_outlined,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Imported OFP",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "SIMBRIEF",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniStat(label: "FROM", value: _ofp?.source ?? "--"),
              _MiniStat(label: "TO", value: _ofp?.destination ?? "--"),
              _MiniStat(
                label: "ALT",
                value: _importedCruiseAltitudeFt != null
                    ? "${_importedCruiseAltitudeFt!} ft"
                    : "--",
              ),
              _MiniStat(
                label: "AIRCRAFT",
                value: _ofp?.aircraftIcao?.isNotEmpty == true
                    ? _ofp!.aircraftIcao!
                    : "Generic",
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RouteStrip(
            text: _ofp?.route.isNotEmpty == true
                ? _ofp!.route
                : "${_ofp?.source ?? ""} ${_ofp?.destination ?? ""}",
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePreviewCard(BuildContext context, RouteBuilderProvider vm) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Route Preview",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${vm.route.length} points • ${vm.totalDistanceNm.toStringAsFixed(1)} NM",
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: ListView.separated(
              itemCount: vm.route.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final leg = vm.route[i];
                final isFirst = i == 0;
                final isLast = i == vm.route.length - 1;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFirst || isLast
                          ? colors.primary.withOpacity(0.18)
                          : colors.outline.withOpacity(0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFirst || isLast
                              ? colors.primary.withOpacity(0.12)
                              : colors.surfaceContainerHighest,
                        ),
                        child: Icon(
                          isFirst
                              ? Icons.flight_takeoff
                              : isLast
                                  ? Icons.flight_land
                                  : Icons.more_horiz,
                          size: 16,
                          color: isFirst || isLast
                              ? colors.primary
                              : colors.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          leg.id,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        "${leg.lat.toStringAsFixed(2)}, ${leg.lon.toStringAsFixed(2)}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withOpacity(0.62),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _SectionCard(
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withOpacity(isDark ? 0.14 : 0.10),
            ),
            child: Icon(Icons.flight_rounded, size: 32, color: colors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            "No OFP imported yet",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Load your latest SimBrief OFP and SkyCase will build a compact flight preview automatically.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withOpacity(0.70),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromStoredSimBrief(RouteBuilderProvider vm) async {
    final simBrief = context.read<SimBriefProvider>();
    final username = simBrief.username.trim();
    final pilotId = simBrief.pilotId.trim();

    if (username.isEmpty && pilotId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Set SimBrief username or Pilot ID in Settings first."),
        ),
      );
      return;
    }

    setState(() => _importing = true);

    try {
      final ofp = await _simBriefService.fetchLatestOfp(
        username: username.isNotEmpty ? username : null,
        pilotId: pilotId.isNotEmpty ? pilotId : null,
      );

      final importedAltitude = _parseCruiseAltitudeFt(ofp.cruiseAltitude);

      final routeParts = <String>[
        ofp.source,
        if (ofp.route.isNotEmpty) ofp.route,
        ofp.destination,
      ];

      final routeString = routeParts.join(' ').trim();

      _parseAndImportRoute(vm, routeString);

      setState(() {
        _ofp = ofp;
        _importedCruiseAltitudeFt = importedAltitude;
      });

      _fitMapToRoute(vm);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Loaded OFP: ${ofp.source} → ${ofp.destination}"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SimBrief import failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _saveRoute(RouteBuilderProvider vm) async {
    final userId = context.read<UserProvider>().user!.id;

    setState(() => _saving = true);

    try {
      final cruiseAlt = _importedCruiseAltitudeFt ?? 8000;
      final aircraft = (_ofp?.aircraftIcao?.isNotEmpty == true)
          ? _ofp!.aircraftIcao!
          : "Generic";

      final f = vm.buildFlight(aircraft, cruiseAlt, 0.0);
      await FlightPlanService.saveFlightPlan(f, userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Flight plan saved!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Save failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _parseAndImportRoute(RouteBuilderProvider vm, String text) {
    if (text.isEmpty) return;

    final tokens = text
        .toUpperCase()
        .replaceAll("\n", " ")
        .split(" ")
        .where((t) => t.trim().isNotEmpty)
        .toList();

    vm.clear();

    LatLng? firstPoint;

    for (final token in tokens) {
      if (RegExp(r"^[A-Z]+\d+$").hasMatch(token)) continue;

      final match = vm.findExact(token);
      if (match == null) continue;

      vm.add(match);
      firstPoint ??= LatLng(match.lat, match.lon);
    }

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (firstPoint != null) {
        _mapController.move(firstPoint!, 8.8);
      }
    });
  }

  void _fitMapToRoute(RouteBuilderProvider vm) {
    final points = vm.route.map<LatLng>((e) => LatLng(e.lat, e.lon)).toList();
    if (points.length < 2) return;

    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
      );
    });
  }

  int _parseCruiseAltitudeFt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 8000;

    final text = raw.trim().toUpperCase();

    final flMatch = RegExp(r'^FL(\d{2,3})$').firstMatch(text);
    if (flMatch != null) {
      final fl = int.tryParse(flMatch.group(1)!);
      if (fl != null) return fl * 100;
    }

    final digits = RegExp(r'(\d{3,5})').firstMatch(text);
    if (digits != null) {
      return int.tryParse(digits.group(1)!) ?? 8000;
    }

    return 8000;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(isDark ? 0.68 : 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RoundAccentIcon extends StatelessWidget {
  const _RoundAccentIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(0.26)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withOpacity(0.62),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _RouteStrip extends StatelessWidget {
  const _RouteStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
      ),
    );
  }
}