import 'package:flutter/material.dart';
import 'package:skycase/models/flight_log.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/screens/flight_details_screen.dart';
import 'package:skycase/services/flight_log_service.dart';
import 'package:skycase/utils/session_manager.dart';

class AircraftDetailsScreen extends StatefulWidget {
  final LearnedAircraft aircraft;

  const AircraftDetailsScreen({super.key, required this.aircraft});

  @override
  State<AircraftDetailsScreen> createState() => _AircraftDetailsScreenState();
}

class _AircraftDetailsScreenState extends State<AircraftDetailsScreen> {
  bool _loadingFlights = true;
  bool _flightError = false;
  List<FlightLog> _aircraftFlights = [];

  LearnedAircraft get aircraft => widget.aircraft;

  @override
  void initState() {
    super.initState();
    _loadAircraftFlights();
  }

  Future<void> _loadAircraftFlights() async {
    try {
      final userId = await SessionManager.getUserId();

      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _flightError = true;
          _loadingFlights = false;
        });
        return;
      }

      final logs = await FlightLogService.getFlightLogs(userId);

      final filtered =
          logs.where((log) => _matchesAircraft(log, aircraft)).toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));

      if (!mounted) return;

      setState(() {
        _aircraftFlights = filtered;
        _loadingFlights = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _flightError = true;
        _loadingFlights = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_displayTitle(aircraft))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroCard(theme, colors),
            const SizedBox(height: 20),
            _sectionTitle(theme, 'Aircraft Overview'),
            const SizedBox(height: 12),
            _infoGrid(colors),
            const SizedBox(height: 20),
            _sectionTitle(theme, 'Maintenance'),
            const SizedBox(height: 12),
            _placeholderCard(
              colors,
              icon: Icons.build_circle_outlined,
              title: 'Maintenance module coming next',
              subtitle:
                  'This aircraft can later hold inspections, service intervals, oil changes, repairs, and airframe notes.',
            ),
            const SizedBox(height: 20),
            _sectionTitle(theme, 'Flight History'),
            const SizedBox(height: 12),
            _flightHistorySection(colors, theme),
          ],
        ),
      ),
    );
  }

  Widget _flightHistorySection(ColorScheme colors, ThemeData theme) {
    if (_loadingFlights) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: colors.surface.withOpacity(0.75),
          border: Border.all(color: colors.primary.withOpacity(0.14)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_flightError) {
      return _placeholderCard(
        colors,
        icon: Icons.error_outline,
        title: 'Could not load flight history',
        subtitle:
            'The aircraft details loaded, but flight logs failed to load.',
      );
    }

    if (_aircraftFlights.isEmpty) {
      return _placeholderCard(
        colors,
        icon: Icons.route_outlined,
        title: 'No flights found for this aircraft yet',
        subtitle:
            'Once this aircraft is used in completed flights, they will appear here.',
      );
    }

    final totalFlights = _aircraftFlights.length;
    final totalMinutes = _aircraftFlights.fold<int>(
      0,
      (sum, log) => sum + log.duration,
    );
    final totalDistance = _aircraftFlights.fold<double>(
      0,
      (sum, log) => sum + log.distanceFlown,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _infoBox(colors, 'Flights', '$totalFlights')),
            const SizedBox(width: 12),
            Expanded(
              child: _infoBox(
                colors,
                'Logged Time',
                _formatMinutes(totalMinutes),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoBox(
                colors,
                'Distance',
                '${totalDistance.toStringAsFixed(1)} nm',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._aircraftFlights
            .take(10)
            .map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _flightCard(context, colors, theme, log),
              ),
            ),
      ],
    );
  }

  Widget _flightCard(
    BuildContext context,
    ColorScheme colors,
    ThemeData theme,
    FlightLog log,
  ) {
    final from = _formatLocation(log.startLocation?.icao);
    final to = _formatLocation(log.endLocation?.icao);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surface.withOpacity(0.78),
        border: Border.all(color: colors.primary.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$from → $to',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _chip(colors, _formatDateTime(log.startTime)),
        ],
      ),
    );
  }

  Widget _heroCard(ThemeData theme, ColorScheme colors) {
    final displayTitle = _displayTitle(aircraft);
    final tail = _extractTailNumber(aircraft);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withOpacity(0.96),
            colors.surfaceContainerHighest.withOpacity(0.35),
          ],
        ),
        border: Border.all(color: colors.primary.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: colors.primary.withOpacity(0.12),
              border: Border.all(color: colors.primary.withOpacity(0.22)),
            ),
            child: Icon(Icons.flight, size: 34, color: colors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (tail != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    tail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(
                      colors,
                      'Total Time ${_formatMinutes(aircraft.totalMinutes)}',
                    ),
                    if (aircraft.wheels == true) _chip(colors, 'Wheels'),
                    if (aircraft.retractable == true)
                      _chip(colors, 'Retractable'),
                    if (aircraft.floats == true) _chip(colors, 'Floats'),
                    if (aircraft.skids == true) _chip(colors, 'Skids'),
                    if (aircraft.skis == true) _chip(colors, 'Skis'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _infoGrid(ColorScheme colors) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _infoBox(
              colors,
              'Fuel Capacity',
              _formatNumber(aircraft.fuelCapacityGallons, ' gal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _infoBox(
              colors,
              'Empty Weight',
              _formatNumber(aircraft.emptyWeight, ' lbs'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _infoBox(
              colors,
              'MTOW',
              _formatNumber(aircraft.mtow, ' lbs'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _infoBox(
              colors,
              'MZFW',
              _formatNumber(aircraft.mzfw, ' lbs'),
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _infoBox(
              colors,
              'Max Payload',
              _formatNumber(aircraft.payloadCapacityLbs, ' lbs'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _infoBox(
              colors,
              'Updated',
              aircraft.updatedAt != null
                  ? _formatDateTime(aircraft.updatedAt!)
                  : '--',
            ),
          ),
        ],
      ),
    ],
  );
}

  Widget _sectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _infoBox(ColorScheme colors, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surface.withOpacity(0.80),
        border: Border.all(color: colors.primary.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCard(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surface.withOpacity(0.75),
        border: Border.all(color: colors.primary.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(ColorScheme colors, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: colors.primary.withOpacity(0.10),
        border: Border.all(color: colors.primary.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  bool _matchesAircraft(FlightLog log, LearnedAircraft ac) {
    final logAircraft = _normalizeAircraftText(log.aircraft);
    final acTitle = _normalizeAircraftText(ac.title);
    final acDisplay = _normalizeAircraftText(_displayTitle(ac));
    final tail = _normalizeAircraftText(_extractTailNumber(ac) ?? '');

    if (logAircraft.isEmpty) return false;

    if (logAircraft == acTitle) return true;
    if (logAircraft == acDisplay) return true;

    if (tail.isNotEmpty && logAircraft.contains(tail)) return true;
    if (tail.isNotEmpty && acTitle.contains(tail) && logAircraft == acDisplay) {
      return true;
    }

    return false;
  }

  String _normalizeAircraftText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\- ]'), '');
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

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatLocation(String? icao) {
    if (icao == null || icao.trim().isEmpty) return 'UNK';
    return icao.trim().toUpperCase();
  }

  String? _extractTailNumber(LearnedAircraft ac) {
    final text = ac.title.trim();
    final parts = text.split(RegExp(r'\s+'));

    if (parts.isEmpty) return null;

    final last = parts.last.trim();
    final looksLikeTail = RegExp(r'^[A-Z0-9-]{4,}$').hasMatch(last);

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
}
