import 'package:flutter/material.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/metar_service.dart';
import 'package:skycase/utils/session_manager.dart';

class JobDetailsScreen extends StatefulWidget {
  final DispatchJob job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  late DispatchJob _job;

  bool _accepting = false;
  bool _cancelling = false;
  bool _loadingWeather = true;

  Map<String, dynamic>? _departureMetar;
  Map<String, dynamic>? _destinationMetar;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loadingWeather = true;
      _departureMetar = null;
      _destinationMetar = null;
    });

    final fromIcao = _job.fromIcao.trim().toUpperCase();
    final toIcao = _job.toIcao.trim().toUpperCase();

    if (fromIcao.isNotEmpty) {
      MetarService.getBriefing(fromIcao).then((data) {
        if (!mounted) return;
        setState(() {
          _departureMetar = data;
        });
      });
    }

    if (toIcao.isNotEmpty) {
      MetarService.getBriefing(toIcao).then((data) {
        if (!mounted) return;
        setState(() {
          _destinationMetar = data;
        });
      });
    }

    Future.wait([
      if (fromIcao.isNotEmpty) MetarService.getBriefing(fromIcao),
      if (toIcao.isNotEmpty) MetarService.getBriefing(toIcao),
    ]).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _loadingWeather = false;
      });
    });
  }

  Future<void> _acceptJob() async {
    if (_accepting) return;

    setState(() => _accepting = true);

    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Missing user session')));
        return;
      }

      final result = await DispatchService.acceptJob(_job.id, userId);

      if (!mounted) return;

      if (result != null) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to accept job')));
      }
    } finally {
      if (mounted) {
        setState(() => _accepting = false);
      }
    }
  }

  Future<void> _cancelJob() async {
    if (_cancelling) return;

    setState(() => _cancelling = true);

    try {
      final userId = await SessionManager.getUserId();
      if (userId == null) return;

      final ok = await DispatchService.cancelJob(_job.id, userId);
      if (!mounted) return;

      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to cancel job')));
      }
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = _job;
    final type = job.type.toLowerCase();
    final typeColor = _typeColor(job.type, theme.brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroCard(context, job, typeColor),
            const SizedBox(height: 16),

            _missionSummarySection(context, job),
            const SizedBox(height: 16),

            if (type == 'cargo') _cargoSection(context, job),
            if (type == 'pax') _paxSection(context, job),
            if (type == 'fuel') _fuelSection(context, job),
            if (type == 'ferry') _ferrySection(context),
            if (!_isKnownType(type)) _genericSection(context, job),

            const SizedBox(height: 16),

            _weatherSection(context),
            const SizedBox(height: 16),

            _operationalNotesSection(context, job),
            const SizedBox(height: 16),

            _pilotNotesSection(context, job),

            const SizedBox(height: 24),

            SizedBox(width: double.infinity, child: _actionButton(theme, job)),

            if (_showCancelButton(job)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cancelling ? null : _cancelJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child:
                      _cancelling
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Cancel Job'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, DispatchJob job, Color typeColor) {
    final theme = Theme.of(context);

    final showPhaseChip =
        job.phase.trim().isNotEmpty &&
        job.phase.toLowerCase() != 'open' &&
        job.phase.toLowerCase() != job.status.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
              Icon(_typeIcon(job.type), color: typeColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  job.title.isNotEmpty ? job.title : 'Dispatch Job',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  job.fromIcao,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.flight_takeoff, color: typeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    job.toIcao,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                context,
                label: _prettyStatus(job.status),
                color: _statusColor(job.status),
              ),
              if (showPhaseChip)
                _statusChip(
                  context,
                  label: _prettyPhase(job.phase),
                  color: _phaseColor(job.phase),
                ),
              if (job.isPriority)
                _statusChip(context, label: 'PRIORITY', color: Colors.red),
              _metaChip(
                context,
                icon: Icons.navigation,
                label: '${job.distanceNm.toStringAsFixed(0)} NM',
              ),
              _metaChip(
                context,
                icon: Icons.payments,
                label: '${job.reward} cr',
              ),
              _metaChip(
                context,
                icon: Icons.category_outlined,
                label: job.type.toUpperCase(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _missionSummarySection(BuildContext context, DispatchJob job) {
    return _sectionCard(
      context,
      title: 'Mission Note',
      children: [
        Text(
          _missionSummary(job),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _weatherSection(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Weather Briefing',
      children: _buildWeatherSection(context),
    );
  }

  Widget _operationalNotesSection(BuildContext context, DispatchJob job) {
    final notes = _operationalNotes(job);

    return _sectionCard(
      context,
      title: 'Operational Notes',
      children:
          notes.map((note) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.chevron_right, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _pilotNotesSection(BuildContext context, DispatchJob job) {
    final notes = _pilotNotes(job);

    return _sectionCard(
      context,
      title: 'Pilot Heads-Up',
      children:
          notes.map((note) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.chevron_right, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  String _missionSummary(DispatchJob job) {
    final from = job.fromIcao;
    final to = job.toIcao;
    final type = job.type.toLowerCase();

    switch (type) {
      case 'cargo':
        final weight =
            job.effectivePayloadLbs > 0
                ? job.effectivePayloadLbs
                : job.payloadLbs;

        return 'Move ${weight.toStringAsFixed(0)} lbs of cargo from $from to $to. '
            'Straight freight run. Check the load, runway condition, and aircraft performance before you launch.';

      case 'pax':
        return 'Carry ${job.paxCount} passenger${job.paxCount == 1 ? '' : 's'} from $from to $to. '
            'Nothing fancy here — just a clean passenger leg where balance, weather, and a smooth arrival matter.';

      case 'fuel':
        return 'Transfer fuel from $from to $to. '
            'Treat this like a support run: check the load properly, handle it carefully, and make sure the destination can receive it.';

      case 'ferry':
        return 'Reposition the aircraft from $from to $to. '
            'No payload, no passengers — just a clean transfer leg and a good chance to keep the aircraft moving where it needs to be.';

      default:
        return 'Fly this job from $from to $to and complete it cleanly. '
            'Check the route, the aircraft, and the field conditions before departure.';
    }
  }

  List<String> _pilotNotes(DispatchJob job) {
    final type = job.type.toLowerCase();

    switch (type) {
      case 'cargo':
        return [
          'Check payload against runway length and aircraft limits.',
          'Watch density altitude if conditions are hot or high.',
          'Don’t ignore runway surface if this ends up being a rough field.',
        ];

      case 'pax':
        return [
          'Confirm passenger load and balance before launch.',
          'Give weather a proper look before departure, not a lazy one.',
          'Plan for a stable arrival — this is not the leg to rush.',
        ];

      case 'fuel':
        return [
          'Verify the transfer load before startup.',
          'Fuel handling is part of the job, not background decoration.',
          'Make sure destination support is actually there before you commit.',
        ];

      case 'ferry':
        return [
          'Use the leg to reposition efficiently and keep it clean.',
          'Good moment to keep an eye on aircraft condition and fuel planning.',
          'No payload does not mean no planning.',
        ];

      default:
        return [
          'Review the route before departure.',
          'Check fuel and aircraft readiness properly.',
          'Keep it simple and fly the leg clean.',
        ];
    }
  }

  List<String> _operationalNotes(DispatchJob job) {
    final notes = <String>[
      'Stay inside aircraft limits for weight and balance.',
      'Make sure onboard fuel covers the leg plus proper reserves.',
      'Do a real walkaround before launch, not a fake one.',
    ];

    switch (job.type.toLowerCase()) {
      case 'cargo':
        notes.add('Secure the load properly before departure.');
        break;
      case 'pax':
        notes.add('Boarding and balance should stay smooth and controlled.');
        break;
      case 'fuel':
        notes.add('Treat fuel transfer like the main job, because it is.');
        break;
      case 'ferry':
        notes.add(
          'Use the leg to reposition cleanly and watch aircraft condition.',
        );
        break;
    }

    if (job.isPriority) {
      notes.add(
        'Priority job: don’t drag your feet, but don’t fly sloppy either.',
      );
    }

    return notes;
  }

  bool _isKnownType(String type) {
    return type == 'cargo' ||
        type == 'pax' ||
        type == 'fuel' ||
        type == 'ferry';
  }

  bool _showCancelButton(DispatchJob job) {
    final status = job.status.toLowerCase();

    if (job.isCompleted || job.isCancelled) return false;
    if (status == 'open') return false;

    return status == 'pending_approval' ||
        status == 'approved' ||
        status == 'accepted';
  }

  String _prettyPhase(String phase) {
    switch (phase.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'preparing':
        return 'Preparing';
      case 'loading':
        return 'Loading';
      case 'ready':
        return 'Ready';
      case 'enroute':
        return 'Enroute';
      case 'arrived':
        return 'Arrived';
      case 'unloading':
        return 'Unloading';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'open':
      default:
        return 'Open';
    }
  }

  String _prettyStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return 'Pending Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'open':
      default:
        return 'Open';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_approval':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.grey;
      case 'open':
      default:
        return Colors.blueGrey;
    }
  }

  Color _phaseColor(String phase) {
    switch (phase.toLowerCase()) {
      case 'accepted':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'loading':
        return Colors.deepOrange;
      case 'ready':
        return Colors.teal;
      case 'enroute':
        return Colors.indigo;
      case 'arrived':
        return Colors.green;
      case 'unloading':
        return Colors.amber.shade700;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'open':
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusChip(
    BuildContext context, {
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metaChip(
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

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _cargoSection(BuildContext context, DispatchJob job) {
    return _sectionCard(
      context,
      title: 'Load Details',
      children: [
        _metricChipRow(
          context,
          items: [
            if (job.payloadLbs > 0) '${job.payloadLbs} lbs cargo',
            if (job.effectivePayloadLbs > 0)
              'Dispatch weight: ${job.effectivePayloadLbs} lbs',
          ],
        ),
      ],
    );
  }

  Widget _paxSection(BuildContext context, DispatchJob job) {
    return _sectionCard(
      context,
      title: 'Passenger Load',
      children: [
        _metricChipRow(
          context,
          items: [
            '${job.paxCount} pax',
            if (job.payloadLbs > 0) '${job.payloadLbs} lbs bags/load',
          ],
        ),
      ],
    );
  }

  Widget _fuelSection(BuildContext context, DispatchJob job) {
    return _sectionCard(
      context,
      title: 'Transfer Load',
      children: [
        _metricChipRow(
          context,
          items: [
            if (job.transferFuelGallons > 0)
              '${job.transferFuelGallons} gallons',
            if (job.transferFuelWeightLbs > 0)
              '${job.transferFuelWeightLbs} lbs transfer weight',
            if (job.requiredFuelGallons > 0)
              '${job.requiredFuelGallons} gallons required onboard',
          ],
        ),
      ],
    );
  }

  Widget _ferrySection(BuildContext context) {
    return _sectionCard(
      context,
      title: 'Flight Setup',
      children: [
        _metricChipRow(
          context,
          items: const ['No cargo', 'No passengers', 'Reposition leg'],
        ),
      ],
    );
  }

  Widget _genericSection(BuildContext context, DispatchJob job) {
    return _sectionCard(
      context,
      title: 'Job Notes',
      children: [
        _metricChipRow(
          context,
          items: [
            job.type.toUpperCase(),
            '${job.distanceNm.toStringAsFixed(0)} NM',
            '${job.reward} cr',
          ],
        ),
      ],
    );
  }

  Widget _metricChipRow(BuildContext context, {required List<String> items}) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          items.map((text) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _actionButton(ThemeData theme, DispatchJob job) {
    final status = job.status.toLowerCase();

    if (status == 'pending_approval') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Waiting for HQ Approval'),
      );
    }

    if (status == 'approved') {
      return ElevatedButton(
        onPressed: () {
          Navigator.pop(context, true);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Approved — Start Flight'),
      );
    }

    if (status == 'rejected') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('HQ Rejected'),
      );
    }

    if (status == 'accepted') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Job Accepted'),
      );
    }

    if (status == 'completed') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Job Completed'),
      );
    }

    if (status == 'cancelled') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Job Cancelled'),
      );
    }

    return ElevatedButton(
      onPressed: _accepting ? null : _acceptJob,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child:
          _accepting
              ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
              : const Text('Accept Job'),
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

  List<Widget> _buildWeatherSection(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingWeather) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    return [
      _airportWeatherBlock(
        context,
        title: 'Departure • ${_job.fromIcao.toUpperCase()}',
        metar: _departureMetar,
        fallback:
            'METAR unavailable for departure airport. Use sim weather and local conditions on the ramp.',
      ),
      const SizedBox(height: 16),
      _airportWeatherBlock(
        context,
        title: 'Arrival • ${_job.toIcao.toUpperCase()}',
        metar: _destinationMetar,
        fallback:
            'METAR unavailable for destination airport. Plan the arrival with extra caution.',
      ),
    ];
  }

  Widget _airportWeatherBlock(
    BuildContext context, {
    required String title,
    required Map<String, dynamic>? metar,
    required String fallback,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (metar == null)
            Text(fallback, style: theme.textTheme.bodyMedium)
          else ...[
            if ((metar['summary'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  metar['summary'].toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _weatherLine(context, 'Raw', (metar['raw'] ?? 'N/A').toString()),
            _weatherLine(context, 'Wind', (metar['wind'] ?? 'N/A').toString()),
            _weatherLine(
              context,
              'Temp',
              '${(metar['temp'] ?? 'N/A').toString()}°C',
            ),
            _weatherLine(
              context,
              'Clouds',
              ((metar['clouds'] as List?) ?? const []).isNotEmpty
                  ? (metar['clouds'] as List).join(', ')
                  : 'Clear',
            ),
          ],
        ],
      ),
    );
  }

  Widget _weatherLine(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
