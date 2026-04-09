import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/models/flight.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/services/dispatch_service.dart';
import 'package:skycase/services/ground_ops/ground_ops_template_resolver.dart';
import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/widgets/battery_status_hud.dart';
import 'package:skycase/widgets/ground_ops/ground_ops_canvas_area.dart';
import 'package:skycase/widgets/ground_ops/ground_ops_fuel_payload_card.dart';
import 'package:skycase/widgets/ground_ops/ground_ops_manifest_card.dart';
import 'package:skycase/widgets/weight_balance_hud.dart';

class GroundOpsScreen extends StatefulWidget {
  final DispatchJob? job;
  final Flight? flight;
  final VoidCallback? onClose;
  final bool minimalView;
  final GroundOpsTemplate? templateOverride;

  const GroundOpsScreen({
    super.key,
    this.job,
    this.flight,
    this.onClose,
    this.minimalView = false,
    this.templateOverride,
  });

  @override
  State<GroundOpsScreen> createState() => _GroundOpsScreenState();
}

class _GroundOpsScreenState extends State<GroundOpsScreen> {
  SimLinkData? _sim;
  DispatchJob? _job;
  StreamSubscription<SimLinkData>? _simSub;
  GroundOpsTemplate? _resolvedTemplate;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _sim = SimLinkSocketService().latestData;
    _simSub = SimLinkSocketService().stream.listen((data) {
      _handleIncomingSim(data);
    });
    if (_sim != null && widget.templateOverride == null) {
      _loadTemplateForTitle(_sim!.title);
    }
    if (_job == null && !widget.minimalView) {
      _loadActiveJobIfNeeded();
    }
  }

  @override
  void dispose() {
    _simSub?.cancel();
    super.dispose();
  }

  bool get _hasSim => _sim != null;
  bool get _hasJob => _job != null;
  bool get _showOverlayWidgets => !widget.minimalView;

  void _handleIncomingSim(SimLinkData data) {
    final currentTitle = _sim?.title.trim();
    final nextTitle = data.title.trim();

    _sim = data;

    if (widget.templateOverride != null) {
      if (mounted) setState(() {});
      return;
    }

    if (currentTitle != nextTitle || _resolvedTemplate == null) {
      _loadTemplateForTitle(data.title, repaintAfterLoad: true);
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadTemplateForTitle(
    String? title, {
    bool repaintAfterLoad = false,
  }) async {
    final template = await GroundOpsTemplateResolver.resolve(title);
    if (!mounted) return;
    setState(() {
      _resolvedTemplate = template;
      if (repaintAfterLoad) {
        _sim = _sim;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 700;
    final title = widget.minimalView
        ? 'Ground Ops'
        : _job == null
            ? 'Ground Ops'
            : 'Ground Ops — ${_job!.fromIcao} ➜ ${_job!.toIcao}';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
          title: Text(title),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: GroundOpsCanvasArea(
                simData: _sim,
                template: widget.templateOverride ?? _resolvedTemplate,
                minimalView: widget.minimalView,
              ),
            ),
            if (_hasSim && _showOverlayWidgets) ...[
              Positioned(top: 10, left: 10, child: BatteryStatusHUD(simData: _sim!)),
              Positioned(top: 10, right: 10, child: WeightBalanceHUD(simData: _sim!)),
            ],
            if (_hasSim && _showOverlayWidgets)
              Positioned(
                left: 16,
                bottom: isMobile ? 16 : 20,
                child: GroundOpsFuelPayloadCard(simData: _sim!, job: _job),
              ),
            if (_hasJob && _showOverlayWidgets)
              Positioned(
                right: isMobile ? null : 16,
                left: isMobile ? 16 : null,
                bottom: isMobile ? 140 : null,
                top: isMobile ? null : 130,
                child: GroundOpsManifestCard(job: _job!),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadActiveJobIfNeeded() async {
    if (_job != null) return;
    final userId = await SessionManager.getUserId();
    if (userId == null) return;
    final job = await DispatchService.getActiveJob(userId);
    if (job == null || !mounted) return;
    setState(() => _job = job);
  }
}
