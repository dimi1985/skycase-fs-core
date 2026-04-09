import 'package:flutter/material.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/screens/aircraft_details_screen.dart';
import 'package:skycase/services/aircraft_service.dart';

class AircraftScreen extends StatefulWidget {
  const AircraftScreen({super.key});

  @override
  State<AircraftScreen> createState() => _AircraftScreenState();
}

class _AircraftScreenState extends State<AircraftScreen> {
  List<LearnedAircraft> aircraft = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAircraft();
  }

  Future<void> _loadAircraft() async {
    try {
      final list = await AircraftService.getAll();
      if (!mounted) return;

      setState(() {
        aircraft = list;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        aircraft = [];
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aircraft Hangar'),
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : aircraft.isEmpty
                ? _AircraftEmptyState(theme: theme)
                : _AircraftGrid(
                    aircraft: aircraft,
                    onOpenAircraft: (ac) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AircraftDetailsScreen(aircraft: ac),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _AircraftGrid extends StatelessWidget {
  final List<LearnedAircraft> aircraft;
  final ValueChanged<LearnedAircraft> onOpenAircraft;

  const _AircraftGrid({
    required this.aircraft,
    required this.onOpenAircraft,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int columns = 1;
        if (width >= 650) columns = 2;
        if (width >= 1050) columns = 3;
        if (width >= 1450) columns = 4;

        final padding = width < 700 ? 12.0 : 20.0;
        final spacing = width < 700 ? 12.0 : 16.0;
        final cardHeight = width < 700 ? 285.0 : 300.0;

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          itemCount: aircraft.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final ac = aircraft[index];
            return _AircraftCard(
              aircraft: ac,
              onTap: () => onOpenAircraft(ac),
            );
          },
        );
      },
    );
  }
}

class _AircraftCard extends StatefulWidget {
  final LearnedAircraft aircraft;
  final VoidCallback onTap;

  const _AircraftCard({
    required this.aircraft,
    required this.onTap,
  });

  @override
  State<_AircraftCard> createState() => _AircraftCardState();
}

class _AircraftCardState extends State<_AircraftCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ac = widget.aircraft;

    final title = _displayTitle(ac);
    final tail = _extractTailNumber(ac);
    final category = _aircraftCategory(ac);
    final flightTime = _formatMinutes(ac.totalMinutes);

    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, hovering ? -4.0 : 0.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: colors.surface,
                border: Border.all(
                  color: hovering
                      ? colors.primary.withOpacity(0.28)
                      : colors.outline.withOpacity(0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withOpacity(hovering ? 0.14 : 0.08),
                    blurRadius: hovering ? 22 : 14,
                    offset: Offset(0, hovering ? 10 : 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AircraftCardHeader(
                      aircraft: ac,
                      title: title,
                      tail: tail,
                      category: category,
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _AircraftHero(
                        aircraft: ac,
                        hovering: hovering,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AircraftStatsRow(
                      label: 'Flight Time',
                      value: flightTime,
                      emphasize: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatBox(
                            label: 'Fuel',
                            value: _formatNumber(ac.fuelCapacityGallons, ' gal'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStatBox(
                            label: 'MTOW',
                            value: _formatNumber(ac.mtow, ' lbs'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatBox(
                            label: 'Gear',
                            value: _gearSummary(ac),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStatBox(
                            label: 'Updated',
                            value: ac.updatedAt != null
                                ? _shortDate(ac.updatedAt!)
                                : '--',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AircraftCardHeader extends StatelessWidget {
  final LearnedAircraft aircraft;
  final String title;
  final String? tail;
  final String category;

  const _AircraftCardHeader({
    required this.aircraft,
    required this.title,
    required this.tail,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colors.primary.withOpacity(0.10),
          ),
          child: Icon(
            _planeIconFor(aircraft),
            color: colors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tail ?? category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _ChipLabel(label: category),
      ],
    );
  }
}

class _AircraftHero extends StatelessWidget {
  final LearnedAircraft aircraft;
  final bool hovering;

  const _AircraftHero({
    required this.aircraft,
    required this.hovering,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colors.surfaceContainerHighest.withOpacity(0.22),
        border: Border.all(
          color: colors.outline.withOpacity(0.10),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.9,
                  colors: [
                    colors.primary.withOpacity(0.12),
                    colors.primary.withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: hovering ? 1.04 : 1.0,
            child: Transform.rotate(
              angle: -0.14,
              child: Icon(
                _planeIconFor(aircraft),
                size: 72,
                color: colors.primary.withOpacity(0.92),
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            child: Container(
              width: 88,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.black.withOpacity(0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AircraftStatsRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _AircraftStatsRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.schedule, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasize ? colors.primary : colors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colors.surfaceContainerHighest.withOpacity(0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;

  const _ChipLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.primary.withOpacity(0.10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AircraftEmptyState extends StatelessWidget {
  final ThemeData theme;

  const _AircraftEmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: colors.surface,
          border: Border.all(color: colors.outline.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight, size: 44, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              'No aircraft recorded yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your hangar is empty for now. Once SkyCase learns aircraft data, each aircraft will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  if (minutes <= 0) return '0h 0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h}h ${m}m';
}

String _formatNumber(num? value, String suffix) {
  if (value == null || value <= 0) return '--';
  return '${value.toStringAsFixed(0)}$suffix';
}

String _shortDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  return '$day/$month/$year';
}

String? _extractTailNumber(LearnedAircraft ac) {
  final text = ac.title.trim();
  final parts = text.split(RegExp(r'\s+'));

  if (parts.isEmpty) return null;

  final last = parts.last.trim();
  final looksLikeTail =
      RegExp(r'^[A-Z0-9-]{4,}$').hasMatch(last) &&
      last != ac.id.toUpperCase();

  return looksLikeTail ? last : null;
}

String _displayTitle(LearnedAircraft ac) {
  final tail = _extractTailNumber(ac);
  if (tail == null) return ac.title.trim();

  final cleaned = ac.title.trim();
  if (cleaned.endsWith(tail)) {
    return cleaned.substring(0, cleaned.length - tail.length).trim();
  }

  return cleaned;
}

String _aircraftCategory(LearnedAircraft ac) {
  final text = '${ac.id} ${ac.title}'.toLowerCase();

  if (text.contains('md11') || text.contains('cargo')) return 'Cargo Jet';
  if (text.contains('baron') || text.contains('twin')) return 'Twin Prop';
  if (text.contains('f28') || text.contains('jet')) return 'Regional Jet';
  if (text.contains('arrow') ||
      text.contains('c172') ||
      text.contains('pa28')) {
    return 'GA Aircraft';
  }
  if (text.contains('kodiak') || text.contains('tundra')) {
    return 'Utility STOL';
  }
  if (text.contains('heli')) return 'Helicopter';
  return 'Aircraft';
}

String _gearSummary(LearnedAircraft ac) {
  final active = <String>[];

  if (ac.wheels == true) active.add('Wheels');
  if (ac.retractable == true) active.add('Retractable');
  if (ac.floats == true) active.add('Floats');
  if (ac.skids == true) active.add('Skids');
  if (ac.skis == true) active.add('Skis');

  if (active.isEmpty) return 'Unknown';
  if (active.length == 1) return active.first;
  if (active.length == 2) return '${active[0]} • ${active[1]}';
  return '${active[0]} • +${active.length - 1}';
}

IconData _planeIconFor(LearnedAircraft ac) {
  final text = '${ac.id} ${ac.title}'.toLowerCase();

  if (text.contains('heli')) return Icons.airplanemode_active_rounded;
  if (text.contains('md11') ||
      text.contains('f28') ||
      text.contains('a320') ||
      text.contains('737') ||
      text.contains('jet')) {
    return Icons.flight;
  }
  return Icons.airplanemode_active;
}