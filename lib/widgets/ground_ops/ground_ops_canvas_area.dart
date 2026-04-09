import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/painters/ground_ops/ground_ops_painter.dart';

class GroundOpsCanvasArea extends StatefulWidget {
  final SimLinkData? simData;
  final GroundOpsTemplate? template;
  final bool minimalView;

  const GroundOpsCanvasArea({
    super.key,
    required this.simData,
    required this.template,
    this.minimalView = false,
  });

  @override
  State<GroundOpsCanvasArea> createState() => _GroundOpsCanvasAreaState();
}

class _GroundOpsCanvasAreaState extends State<GroundOpsCanvasArea>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  Duration _elapsed = Duration.zero;

  double _propAngle = 0.0;
  double _blurLevel = 0.0;
  double _wobbleX = 0.0;
  double _wobbleY = 0.0;
  double _shutdownBlend = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;

    final seconds = elapsed.inMilliseconds / 1000.0;
    final propSpeedFactor = _estimatePropSpeed(widget.simData);
    final wobbleStrength = _estimateWobbleStrength(widget.simData);

    if (!mounted) return;

    setState(() {
      _propAngle = (_propAngle + propSpeedFactor * 0.18) % (math.pi * 2);

      final baseWobble = widget.minimalView ? 0.0 : wobbleStrength;
      _wobbleX = math.sin(seconds * 1.8) * baseWobble;
      _wobbleY = math.cos(seconds * 1.5) * baseWobble * 0.7;

      _blurLevel = _estimatePropBlur(propSpeedFactor);
      _shutdownBlend = _estimateShutdownBlend(widget.simData);
    });
  }

  bool _hasElectricalPower(SimLinkData? sim) {
    if (sim == null) return false;

    return sim.mission.battery || sim.mainBusVolts > 1.0 || sim.avionicsOn;
  }

  bool _isEngineRunning(SimLinkData? sim) {
    if (sim == null) return false;

    return sim.combustion && sim.rpm > 200;
  }

  bool _isAircraftActive(SimLinkData? sim) {
    if (sim == null) return false;

    return _hasElectricalPower(sim) || _isEngineRunning(sim);
  }

  double _estimatePropSpeed(SimLinkData? sim) {
    if (sim == null) return 0.0;

    final engineRunning = _isEngineRunning(sim);
    if (!engineRunning) return 0.0;

    final rpm = sim.rpm;

    if (rpm <= 0) return 0.35;
    if (rpm >= 2200) return 1.0;

    return (rpm / 2200).clamp(0.15, 1.0);
  }

  double _estimatePropBlur(double propSpeedFactor) {
    if (propSpeedFactor > 0.85) return 1.8;
    if (propSpeedFactor > 0.65) return 1.3;
    if (propSpeedFactor > 0.25) return 0.6;
    if (propSpeedFactor > 0.05) return 0.2;
    return 0.0;
  }

  double _estimateWobbleStrength(SimLinkData? sim) {
    if (sim == null) return 0.0;

    if (_isEngineRunning(sim)) {
      final rpmFactor = (sim.rpm / 2200).clamp(0.0, 1.0);
      return lerpDouble(0.25, 0.9, rpmFactor) ?? 0.5;
    }

    if (_hasElectricalPower(sim)) {
      return 0.18;
    }

    return 0.0;
  }

  double _estimateShutdownBlend(SimLinkData? sim) {
    if (sim == null) return 0.0;

    return _isAircraftActive(sim) ? 0.0 : 0.18;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF030A11),
      child: CustomPaint(
        painter: GroundOpsPainter(
          template: widget.template,
          simData: widget.simData,
          time: _elapsed,
          propAngle: _propAngle,
          blurLevel: _blurLevel,
          wobbleX: _wobbleX,
          wobbleY: _wobbleY,
          shutdownBlend: _shutdownBlend,
          showLabels: !widget.minimalView,
          showDoors: true,
          showLights: true,
          showServicePoints: !widget.minimalView,
          showGrid: false,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
