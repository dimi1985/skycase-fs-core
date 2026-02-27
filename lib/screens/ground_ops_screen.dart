import 'dart:async';
import 'package:flutter/material.dart';

import 'package:skycase/models/flight.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/models/dispatch_job.dart';

import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/simlink_socket_service.dart';

import 'package:skycase/utils/animated_ground_ops.dart';
import 'package:skycase/utils/ground_ops_template.dart';
import 'package:skycase/utils/manifest_generator.dart';
import 'package:skycase/utils/session_manager.dart';

import 'package:skycase/widgets/battery_status_hud.dart';
import 'package:skycase/widgets/sim_off_panel.dart';
import 'package:skycase/widgets/weight_balance_hud.dart';

class GroundOpsScreen extends StatefulWidget {
  final DispatchJob? job;
  final Flight? flight;

  const GroundOpsScreen({super.key, this.job, this.flight});

  @override
  State<GroundOpsScreen> createState() => _GroundOpsScreenState();
}

class _GroundOpsScreenState extends State<GroundOpsScreen> {
  SimLinkData? _sim;
  DispatchJob? _job;


  StreamSubscription<SimLinkData>? _simSub;

  // --------------------------------------------------
  // LIFECYCLE
  // --------------------------------------------------
  @override
  void initState() {
    super.initState();

    _job = widget.job;


    // hydrate immediately
    _sim = SimLinkSocketService().latestData;

    _simSub = SimLinkSocketService().stream.listen((data) {
      if (!mounted) return;
      setState(() => _sim = data);
    });

    _loadActiveJobIfNeeded();
  }

  @override
  void dispose() {
    _simSub?.cancel();
    super.dispose();
  }

  // --------------------------------------------------
  // DERIVED STATE
  // --------------------------------------------------
  bool get _hasSim => _sim != null;
  bool get _hasJob => _job != null;

  /// Fuel to inject into aircraft (if any)
  int get _fuelToInject {
    if (_job == null) return 0;

    if (_job!.isFuelJob) {
      return _job!.transferFuelGallons;
    }

    return _job!.requiredFuelGallons;
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            _job == null
                ? "Ground Ops"
                : "Ground Ops — ${_job!.fromIcao} ➜ ${_job!.toIcao}",
          ),
        ),
        body: Stack(
          children: [
            // background
            Positioned.fill(
              child: Container(color: colors.background),
            ),

            // sim offline
            if (!_hasSim) const SimOffPanel(),

            // aircraft visualization
            if (_hasSim)
              Positioned.fill(
                child: Container(
                  color: colors.surfaceVariant.withOpacity(0.08),
                  child: AnimatedGroundOps(
                    simData: _sim!,
                    template: getTemplateForAircraft(_sim!.title),
                  ),
                ),
              ),

            // HUDs
            if (_hasSim) ...[
              Positioned(
                top: 10,
                left: 10,
                child: BatteryStatusHUD(simData: _sim!),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: WeightBalanceHUD(simData: _sim!),
              ),
            ],

            // manifest
            if (_hasJob)
              Positioned(
                top: isMobile ? null : 150,
                right: isMobile ? null : 10,
                bottom: isMobile ? 10 : null,
                left: isMobile ? 10 : null,
                child: _manifestCard(_job!),
              ),

          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // MANIFEST
  // --------------------------------------------------
  Widget _manifestCard(DispatchJob job) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 0.6),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          height: 1.25,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📋 Manifest",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            Text("• Type: ${job.type.toUpperCase()}"),

            if (job.payloadLbs > 0) ...[
              const SizedBox(height: 6),
              const Text("• Cargo:"),
              for (final e in ManifestGenerator.cargo(job.payloadLbs))
                Text("   - $e"),
            ],

            if (job.paxCount > 0) ...[
              const SizedBox(height: 6),
              const Text("• Pax:"),
              for (final p in ManifestGenerator.pax(job.paxCount))
                Text("   - $p"),
            ],

            if (job.isFuelJob) ...[
              const SizedBox(height: 6),
              const Text("• Fuel Delivery:"),
              for (final f in ManifestGenerator.fuel(job.transferFuelGallons))
                Text("   - $f"),
            ],
          ],
        ),
      ),
    );
  }


  // --------------------------------------------------
  // DATA
  // --------------------------------------------------
  Future<void> _loadActiveJobIfNeeded() async {
    if (_job != null) return;

    final userId = await SessionManager.getUserId();
    if (userId == null) return;

    final json = await DispatchService.getActiveJob(userId);
    if (json == null) return;

    if (!mounted) return;
    setState(() {
      _job = DispatchJob.fromJson(json);
    });
  }
}
