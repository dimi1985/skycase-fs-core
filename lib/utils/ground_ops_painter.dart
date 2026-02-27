// lib/ui/ground_ops/ground_ops_painter.dart

import 'package:flutter/material.dart';
import 'package:skycase/models/simlink_data.dart';
import 'ground_ops_template.dart';
import 'dart:math' as math;

class GroundOpsPainter extends CustomPainter {
  final GroundOpsTemplate template;
  final SimLinkData? simData;
  final double time;
  final double propAngle;
final double blurLevel;
final double wobbleX;
final double wobbleY;
final double shutdownBlend;

GroundOpsPainter({
  required this.template,
  required this.simData,
  required this.time,

  required this.propAngle,
  required this.blurLevel,
  required this.wobbleX,
  required this.wobbleY,
  required this.shutdownBlend,
});


@override
void paint(Canvas canvas, Size size) {
  final mission = simData?.mission;
  final scale = 0.5;
  final cx = size.width * 0.5;
  final cy = size.height * 0.5;

  canvas.save();
  canvas.translate(wobbleX, wobbleY);

  final body = Paint()..color = Colors.blueGrey.shade800;

  // ✈ Fuselage
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(cx, cy),
      width: size.width * 0.1 * scale,
      height: size.height * 0.8 * scale,
    ),
    body,
  );

  // ✈ Wings
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(cx, cy),
      width: size.width * 0.9 * scale,
      height: size.height * 0.12 * scale,
    ),
    body,
  );

  // ✈ Tail
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(cx, cy + size.height * 0.36 * scale),
      width: size.width * 0.40 * scale,
      height: size.height * 0.07 * scale,
    ),
    body,
  );

  // ==============================
  // ✈ PROPELLER ANIMATION
  // ==============================
  if (template.propCenter != null) {
    final center = Offset(
      size.width * template.propCenter!.dx,
      size.height * template.propCenter!.dy,
    );

    // PROP BLUR (outer ring)
    if (blurLevel > 0.1) {
      final blurPaint = Paint()
        ..color = Colors.white.withOpacity(blurLevel * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = template.propRadius * 0.6;

      canvas.drawCircle(center, template.propRadius, blurPaint);
    }

    // SOLID BLADES
    if (blurLevel < 0.9) {
      final bladePaint = Paint()
        ..color = Colors.white.withOpacity(1 - shutdownBlend);

      final bladeLength = template.propRadius * 1.4;

      for (int i = 0; i < 2; i++) {
        final angle = propAngle + math.pi * i;
        final dx = math.cos(angle) * bladeLength;
        final dy = math.sin(angle) * bladeLength;

        canvas.drawLine(center, center + Offset(dx, dy), bladePaint);
      }
    }
  }

  // ==================================
  // 💡 REALISTIC LIGHTS
  // ==================================
  for (var light in template.lights) {
    final pos = Offset(
      size.width * (0.5 + (light.position.dx - 0.5) * scale),
      size.height * (0.5 + (light.position.dy - 0.5) * scale),
    );

    final active = mission?.battery == true && _lightOn(light.type);
    double intensity = 0.0;

    if (active) {
      switch (light.type) {
        case "beacon":
          intensity = _beaconIntensity(time);
          break;
        case "strobe_left":
        case "strobe_right":
          intensity = _strobeIntensity(time);
          break;
        case "nav_left":
        case "nav_right":
        default:
          intensity = 1.0;
      }
    }

    _drawLight(canvas, pos, light.color, 6, intensity);
  }

  // ==================================
  // 🚪 DOORS
  // ==================================
  for (var door in template.doors) {
    final rect = Rect.fromLTWH(
      door.area.left * size.width,
      door.area.top * size.height,
      door.area.width * size.width,
      door.area.height * size.height,
    );

    final open = _doorOpen(door.label);

    final paint = Paint()
      ..color = open
          ? Colors.orangeAccent.withOpacity(0.7)
          : Colors.blueAccent
      ..style = open ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(rect, paint);

    final tp = TextPainter(
      text: TextSpan(
        text: door.label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, rect.topLeft + const Offset(2, 2));
  }

  // 👉 restore AFTER everything
  canvas.restore();
}

  // =====================================================
  // 💡 LIGHT LOGIC
  // =====================================================
  bool _lightOn(String type) {
    final m = simData?.mission;
    if (m == null) return false;

    switch (type) {
      case "beacon": return m.beacon;
      case "nav_left":
      case "nav_right": return m.nav;
      case "strobe_left":
      case "strobe_right": return m.strobe;
      case "landing": return m.landing;
      case "taxi": return m.taxi;
      default: return false;
    }
  }

  bool _doorOpen(String label) {
    final m = simData?.mission;
    if (m == null) return false;

    switch (label) {
      case "L": return m.mainLeft;
      case "R": return m.mainRight;
      case "C": return m.cargo || m.passenger;
      default: return false;
    }
  }

  // =====================================================
  // 💡 REAL LIGHT INTENSITY BEHAVIORS
  // =====================================================

  /// Smooth sinus pulse 0→1→0
  double _beaconIntensity(double t) {
    final v = (0.5 + 0.5 * math.sin(t * 2 * math.pi));
    return v.clamp(0.0, 1.0);
  }

  /// Double-flash like real GA strobes
  double _strobeIntensity(double t) {
    double phase = t % 1.2; // 1.2-second pattern

    if (phase < 0.05) return 1.0;
    if (phase < 0.10) return 0.0;
    if (phase < 0.15) return 1.0;

    return 0.0;
  }


  // =====================================================
  // 🌟 REALISTIC LIGHT DRAW (glow + core)
  // =====================================================
  void _drawLight(
      Canvas canvas, Offset pos, Color color, double radius, double intensity) {
    // Glow halo
    final glow = Paint()
      ..color = color.withOpacity(intensity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(pos, radius * 2.5, glow);

    // Core
    final core = Paint()..color = color.withOpacity(intensity);
    canvas.drawCircle(pos, radius, core);
  }

  

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
