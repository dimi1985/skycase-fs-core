import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skycase/models/airport_location.dart';
import 'package:skycase/models/flight_log.dart';
import 'package:skycase/screens/flight_details_screen.dart';
import 'package:skycase/services/flight_log_service.dart';
import 'package:skycase/utils/session_manager.dart';

class FlightLogsScreen extends StatefulWidget {
  const FlightLogsScreen({super.key});

  @override
  State<FlightLogsScreen> createState() => _FlightLogsScreenState();
}

class _FlightLogsScreenState extends State<FlightLogsScreen> {
  List<FlightLog> _logs = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final userId = await SessionManager.getUserId();

      if (userId == null) {
        setState(() {
          _error = true;
          _loading = false;
        });
        return;
      }

      final logs = await FlightLogService.getFlightLogs(userId);

      if (!mounted) return;

      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text("Flight History"),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
      ),

      // BODY
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
              ? Center(
                child: Text(
                  "Failed to load logs.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.error,
                  ),
                ),
              )
              : _logs.isEmpty
              ? Center(
                child: Text(
                  "No flight logs found.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return _buildTicketCard(context, _logs[index]);
                },
              ),
    );
  }

  // ------------------------------------------------------------
  // TICKET CARD
  // ------------------------------------------------------------
  Widget _buildTicketCard(BuildContext context, FlightLog log) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final from = _formatLoc(log.startLocation);
    final to = _formatLoc(log.endLocation);
    final timeStr = DateFormat('dd MMM yyyy, HH:mm').format(log.startTime);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.surfaceVariant, colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FlightDetailsScreen(log: log)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _airportCode(context, from),
                    const Spacer(),
                    Icon(Icons.flight_takeoff, color: colors.primary),
                    const Spacer(),
                    _airportCode(context, to),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 12),

                Row(
                  children: [
                    _ticketStat(
                      context,
                      Icons.timer,
                      "Duration",
                      "${log.duration} min",
                    ),
                    _ticketStat(
                      context,
                      Icons.vertical_align_top,
                      "Max Alt",
                      "${log.maxAltitude} ft",
                    ),
                    _ticketStat(
                      context,
                      Icons.speed,
                      "Cruise",
                      "${log.cruiseTime} min",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(
                      Icons.airplanemode_active,
                      color: colors.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.aircraft,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------
  Widget _airportCode(BuildContext context, String code) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Text(
      code,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        color: colors.primary,
      ),
    );
  }

  Widget _ticketStat(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLoc(AirportLocation? loc) {
    if (loc == null) return "UNK";
    return loc.icao.isNotEmpty
        ? loc.icao
        : "${loc.lat.toStringAsFixed(2)},${loc.lng.toStringAsFixed(2)}";
  }
}
