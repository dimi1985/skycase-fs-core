// lib/ui/ground_ops/animated_ground_ops.dart

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'ground_ops_painter.dart';
import 'ground_ops_template.dart';
import 'package:skycase/models/simlink_data.dart';
import 'dart:math' as math;

class AnimatedGroundOps extends StatefulWidget {
  final GroundOpsTemplate template;
  final SimLinkData simData;

  const AnimatedGroundOps({
    super.key,
    required this.template,
    required this.simData,
  });

  @override
  State<AnimatedGroundOps> createState() => _AnimatedGroundOpsState();
}

class _AnimatedGroundOpsState extends State<AnimatedGroundOps>
    with SingleTickerProviderStateMixin {

  late final Ticker _ticker;
  double time = 0;

  // ==========================================================
  //  Animation State
  // ==========================================================
  double propAngle = 0;
  double blurLevel = 0;

  double wobbleX = 0;
  double wobbleY = 0;

  double smoothRpm = 0;
  double shutdownBlend = 0;   // 0 = running, 1 = fully stopped

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ==========================================================
  //  MASTER TICK
  // ==========================================================
  void _tick(Duration d) {
    final dt = d.inMilliseconds / 1000.0;
    final sim = widget.simData;

    // Smooth RPM
    smoothRpm += (sim.rpm - smoothRpm) * 0.1;

    // Engine type logic
    final isProp = sim.engineType == 1 || sim.engineType == 6;

    // ----------------------------------------------------------
    // PROP ROTATION
    // ----------------------------------------------------------
    if (isProp && smoothRpm > 10) {
      double rps = smoothRpm / 60.0;
      propAngle += rps * 2 * math.pi * 0.8; // speed factor
    }

    // Normalize
    propAngle %= (2 * math.pi);

    // ----------------------------------------------------------
    // BLUR LEVEL (0 → 1)
    // ----------------------------------------------------------
    blurLevel = (smoothRpm / 2400).clamp(0.0, 1.0);

    // ----------------------------------------------------------
    // IDLE WOBBLE
    // ----------------------------------------------------------
    if (smoothRpm > 50 && smoothRpm < 900) {
      wobbleX = math.sin(dt * 3.0) * 0.6;
      wobbleY = math.sin(dt * 2.3) * 0.4;
    } else {
      wobbleX = 0;
      wobbleY = 0;
    }

    // ----------------------------------------------------------
    // TAXI VIBRATION
    // ----------------------------------------------------------
    if (sim.airspeed > 3 && sim.airspeed < 40) {
      wobbleY += math.sin(dt * 25) * 0.7;
    }


    // ----------------------------------------------------------
    // SHUTDOWN FADE
    // ----------------------------------------------------------
    if (smoothRpm < 200 && sim.combustion == false) {
      shutdownBlend += 0.02;
    } else {
      shutdownBlend = 0;
    }

    shutdownBlend = shutdownBlend.clamp(0.0, 1.0);

    setState(() {
      time = dt;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GroundOpsPainter(
        template: widget.template,
        simData: widget.simData,
        time: time,

        // NEW values passed into painter
        propAngle: propAngle,
        blurLevel: blurLevel,
        wobbleX: wobbleX,
        wobbleY: wobbleY,
        shutdownBlend: shutdownBlend,
      ),
    );
  }
}
