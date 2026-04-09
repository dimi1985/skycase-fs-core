import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/simlink_data.dart';

class GroundOpsPainter extends CustomPainter {
  final GroundOpsTemplate? template;

  final String? selectedPartId;
  final String? selectedDoorId;
  final String? selectedLightId;
  final String? selectedServicePointId;

  final bool showLabels;
  final bool showDoors;
  final bool showLights;
  final bool showServicePoints;
  final bool showGrid;

  final SimLinkData? simData;
  final Object? time;
  final double propAngle;
  final double blurLevel;
  final double wobbleX;
  final double wobbleY;
  final double shutdownBlend;

  const GroundOpsPainter({
    required this.template,
    this.selectedPartId,
    this.selectedDoorId,
    this.selectedLightId,
    this.selectedServicePointId,
    this.showLabels = true,
    this.showDoors = true,
    this.showLights = true,
    this.showServicePoints = true,
    this.showGrid = false,
    this.simData,
    this.time,
    this.propAngle = 0.0,
    this.blurLevel = 0.0,
    this.wobbleX = 0.0,
    this.wobbleY = 0.0,
    this.shutdownBlend = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    if (template == null) {
      _drawEmptyState(canvas, size);
      return;
    }

    final rect = _contentRect(size);

    canvas.save();
    if (wobbleX != 0 || wobbleY != 0) {
      canvas.translate(wobbleX, wobbleY);
    }

    if (blurLevel > 0) {
      final layerPaint = Paint()
        ..imageFilter = ImageFilter.blur(sigmaX: blurLevel, sigmaY: blurLevel);
      canvas.saveLayer(Offset.zero & size, layerPaint);
    }

    if (showGrid) {
      _drawGrid(canvas, rect);
    }

    _drawParts(canvas, size, rect);
    if (showDoors) _drawDoors(canvas, size, rect);
    if (showLights) _drawLights(canvas, size, rect);
    if (showServicePoints) _drawServicePoints(canvas, size, rect);
    _drawPropHints(canvas, size, rect);

    if (blurLevel > 0) canvas.restore();
    canvas.restore();

    if (shutdownBlend > 0) {
      _drawShutdownOverlay(canvas, size, shutdownBlend);
    }
  }

  Rect _contentRect(Size size) {
    final horizontalPad = size.width * 0.06;
    final verticalPad = size.height * 0.06;
    final usable = Rect.fromLTWH(
      horizontalPad,
      verticalPad,
      size.width - (horizontalPad * 2),
      size.height - (verticalPad * 2),
    );
    final side = math.min(usable.width, usable.height);
    return Rect.fromCenter(
      center: usable.center,
      width: side,
      height: side,
    );
  }

  Offset _toCanvas(NormalizedPoint point, Rect rect) {
    return Offset(rect.left + point.x * rect.width, rect.top + point.y * rect.height);
  }

  List<Offset> _toCanvasOffsets(List<NormalizedPoint> points, Rect rect) {
    return points.map((p) => _toCanvas(p, rect)).toList();
  }

  double _seconds() {
    if (time is Duration) {
      return (time as Duration).inMilliseconds / 1000.0;
    }
    return 0.0;
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF08111B), Color(0xFF02070D)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'No Ground Ops Template',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2),
    );
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = rect.left; x <= rect.right; x += step) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    for (double y = rect.top; y <= rect.bottom; y += step) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void _drawParts(Canvas canvas, Size size, Rect rect) {
    for (final part in template!.parts) {
      if (!part.isValidPolygon) continue;
      final offsets = _toCanvasOffsets(part.points, rect);
      final path = _polygonPath(offsets);
      final isSelected = part.id == selectedPartId;
      final fillColor = _fillColorForPart(part.type, isSelected, part.colorHint);

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          colors: [fillColor.withOpacity(0.96), _shade(fillColor, 0.66)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(path.getBounds());

      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(isSelected ? 0.28 : 0.12);

      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.6 : 1.4
        ..color = isSelected ? const Color(0xFF36A3FF) : Colors.white.withOpacity(0.10);

      final shadowPath = Path.from(path).shift(const Offset(2, 6));
      canvas.drawPath(shadowPath, Paint()..color = Colors.black.withOpacity(0.22));
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, highlightPaint);
      canvas.drawPath(path, strokePaint);

      if (showLabels) {
        _drawCenteredLabel(canvas, _centroid(offsets), part.name, color: Colors.white70);
      }
    }
  }

  void _drawDoors(Canvas canvas, Size size, Rect rect) {
    for (final door in template!.doors) {
      if (!door.enabled || !door.isValidPolygon) continue;

      final base = _toCanvasOffsets(door.points, rect);
      final animated = _doorOffsets(base, door, rect);
      final path = _polygonPath(animated);
      final isSelected = door.id == selectedDoorId;
      final open = _doorOpenRatio(door);
      final baseColor = Color.lerp(const Color(0xFFB58B52), const Color(0xFFD6A45F), open * 0.6) ?? const Color(0xFFB58B52);

      canvas.drawPath(Path.from(path).shift(const Offset(2, 3)), Paint()..color = Colors.black.withOpacity(0.18));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            colors: [baseColor.withOpacity(0.90), _shade(baseColor, 0.62)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(path.getBounds()),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.4 : 1.3
          ..color = isSelected ? const Color(0xFF36A3FF) : Colors.white.withOpacity(0.12),
      );

      if (showLabels) {
        _drawCenteredLabel(canvas, _centroid(animated), door.code ?? door.name, color: Colors.white70, fontSize: 10.5);
      }
    }
  }

  List<Offset> _doorOffsets(List<Offset> base, GroundDoor door, Rect rect) {
    final amount = _doorOpenRatio(door);
    if (amount <= 0.001) return base;
    final center = _centroid(base);
    final onLeft = center.dx < rect.center.dx;
    final seconds = _seconds();
    final idPhase = (door.id.hashCode.abs() % 1000) / 1000.0;
    final jitter = (math.sin((seconds * 2.2) + idPhase * math.pi * 2) * 0.03 + 0.97);
    final open = amount * jitter;

    switch (door.animationStyle) {
      case DoorAnimationStyle.swingOut:
        final hinge = onLeft ? base.reduce((a, b) => a.dx < b.dx ? a : b) : base.reduce((a, b) => a.dx > b.dx ? a : b);
        final angle = (onLeft ? -1.0 : 1.0) * open * 1.05;
        return base.map((p) => _rotate(p, hinge, angle)).toList();
      case DoorAnimationStyle.slideUp:
        final dy = -rect.height * 0.05 * open;
        return base.map((p) => p.translate(0, dy)).toList();
      case DoorAnimationStyle.slideSide:
        final dx = (onLeft ? -1 : 1) * rect.width * 0.045 * open;
        return base.map((p) => p.translate(dx, 0)).toList();
      case DoorAnimationStyle.foldOut:
        final angle = (onLeft ? -1.0 : 1.0) * open * 0.72;
        return base.map((p) => _rotate(p, center, angle)).toList();
    }
  }

  double _doorOpenRatio(GroundDoor door) {
    final sim = simData;
    if (sim == null) return 0.0;
    final center = _centroid(_toCanvasOffsets(door.points, _contentRect(const Size(1000, 1000))));
    final leftSide = center.dx < 500;
    final mission = sim.mission;
    final open = switch (door.type) {
      DoorType.cargo => mission.cargo,
      DoorType.baggage => mission.cargo,
      DoorType.mainEntry => mission.passenger || (leftSide ? mission.mainLeft : mission.mainRight),
      DoorType.service => leftSide ? mission.mainLeft : mission.mainRight,
      DoorType.cockpitAccess => mission.passenger,
      DoorType.emergencyExit => mission.passenger,
      DoorType.overwingExit => mission.passenger,
      DoorType.custom => leftSide ? mission.mainLeft : mission.mainRight,
    };
    return open ? 1.0 : 0.0;
  }

  void _drawLights(Canvas canvas, Size size, Rect rect) {
    for (final light in template!.lights) {
      if (!light.enabled) continue;
      final pos = _toCanvas(light.position, rect);
      final isSelected = light.id == selectedLightId;
      final active = _isLightActive(light);
      final pulse = _lightPulse(light, active);
      final glowRadius = _glowRadiusForLight(light, rect) * pulse;
      final coreRadius = (isSelected ? 6.0 : 4.0) * (active ? 1.0 : 0.72);
      final glowAlpha = active ? (0.18 + (pulse * 0.28)) : 0.06;

      if (glowRadius > 0.2) {
        canvas.drawCircle(
          pos,
          glowRadius,
          Paint()
            ..style = PaintingStyle.fill
            ..color = light.color.withOpacity(glowAlpha.clamp(0.0, 1.0)),
        );
      }

      if (light.type == LightType.landing || light.type == LightType.taxi) {
        final conePath = Path();
        final coneWidth = rect.width * (light.type == LightType.landing ? 0.045 : 0.030) * pulse;
        final coneLength = rect.height * (light.type == LightType.landing ? 0.15 : 0.10) * pulse;
        conePath.moveTo(pos.dx - coneWidth, pos.dy + 2);
        conePath.lineTo(pos.dx + coneWidth, pos.dy + 2);
        conePath.lineTo(pos.dx + coneWidth * 0.40, pos.dy - coneLength);
        conePath.lineTo(pos.dx - coneWidth * 0.40, pos.dy - coneLength);
        conePath.close();
        canvas.drawPath(
          conePath,
          Paint()
            ..shader = LinearGradient(
              colors: [light.color.withOpacity(active ? 0.22 : 0.03), Colors.transparent],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ).createShader(conePath.getBounds()),
        );
      }

      canvas.drawCircle(pos, coreRadius, Paint()..color = light.color.withOpacity(active ? 1.0 : 0.35));
      canvas.drawCircle(
        pos,
        isSelected ? 9 : 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.0 : 1.2
          ..color = isSelected ? const Color(0xFF36A3FF) : Colors.white.withOpacity(0.28),
      );

      if (showLabels) {
        _drawLabel(canvas, pos + const Offset(8, -14), light.name, color: Colors.white70);
      }
    }
  }

  bool _isLightActive(GroundLight light) {
    final sim = simData;
    if (sim == null) return false;
    final mission = sim.mission;
    return switch (light.type) {
      LightType.beacon => mission.beacon,
      LightType.navLeft || LightType.navRight => mission.nav,
      LightType.strobeLeft || LightType.strobeRight => mission.strobe,
      LightType.landing => mission.landing,
      LightType.taxi => mission.taxi,
      LightType.logo => mission.nav,
      LightType.cabin => mission.battery,
      LightType.generic => mission.battery,
    };
  }

  double _lightPulse(GroundLight light, bool active) {
    if (!active) return 0.35;
    final t = _seconds();
    switch (light.type) {
      case LightType.beacon:
        return 0.65 + ((math.sin(t * 4.8) + 1) / 2) * 0.75;
      case LightType.strobeLeft:
      case LightType.strobeRight:
        final phase = ((t * 1.9) + ((light.id.hashCode.abs() % 7) * 0.04)) % 1.0;
        return phase < 0.10 ? 1.9 : 0.10;
      case LightType.landing:
        return 1.25;
      case LightType.taxi:
        return 1.05;
      case LightType.navLeft:
      case LightType.navRight:
      case LightType.logo:
      case LightType.cabin:
      case LightType.generic:
        return 0.90;
    }
  }

  double _glowRadiusForLight(GroundLight light, Rect rect) {
    final base = rect.shortestSide * 0.012 * light.intensity;
    switch (light.type) {
      case LightType.beacon:
        return base * 2.8;
      case LightType.strobeLeft:
      case LightType.strobeRight:
        return base * 2.4;
      case LightType.landing:
        return base * 4.6;
      case LightType.taxi:
        return base * 3.2;
      case LightType.navLeft:
      case LightType.navRight:
      case LightType.logo:
      case LightType.cabin:
      case LightType.generic:
        return base * 1.8;
    }
  }

  void _drawServicePoints(Canvas canvas, Size size, Rect rect) {
    for (final point in template!.servicePoints) {
      if (!point.enabled) continue;
      final pos = _toCanvas(point.position, rect);
      final isSelected = point.id == selectedServicePointId;
      final box = Rect.fromCenter(center: pos, width: isSelected ? 20 : 16, height: isSelected ? 20 : 16);
      final rrect = RRect.fromRectAndRadius(box, const Radius.circular(4));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFF2BB88A).withOpacity(0.12));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.0 : 1.4
          ..color = isSelected ? const Color(0xFF36A3FF) : const Color(0xFF53D1A8),
      );
      if (showLabels) {
        _drawLabel(canvas, pos + const Offset(8, -14), point.name, color: Colors.white70);
      }
    }
  }

  void _drawPropHints(Canvas canvas, Size size, Rect rect) {
    if (template!.propCenter == null) return;
    final center = _toCanvas(template!.propCenter!, rect);
    final radius = template!.propRadius * rect.shortestSide;
    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = Colors.white.withOpacity(0.22));
    final bladeLength = radius;
    final dx = bladeLength * math.cos(propAngle);
    final dy = bladeLength * math.sin(propAngle);
    canvas.drawLine(
      Offset(center.dx - dx, center.dy - dy),
      Offset(center.dx + dx, center.dy + dy),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = Colors.white.withOpacity(0.48),
    );
  }

  void _drawShutdownOverlay(Canvas canvas, Size size, double blend) {
    final alpha = (blend.clamp(0.0, 1.0) * 110).toInt();
    canvas.drawRect(Offset.zero & size, Paint()..color = Color.fromARGB(alpha, 0, 0, 0));
  }

  Path _polygonPath(List<Offset> offsets) {
    final path = Path();
    if (offsets.isEmpty) return path;
    path.moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
    }
    path.close();
    return path;
  }

  Color _fillColorForPart(AircraftPartType type, bool isSelected, Color? colorHint) {
    if (isSelected) return const Color(0xFF1D6BC0);
    if (colorHint != null) return colorHint;
    switch (type) {
      case AircraftPartType.fuselage:
        return const Color(0xFF8499A8);
      case AircraftPartType.wingLeft:
      case AircraftPartType.wingRight:
        return const Color(0xFF708896);
      case AircraftPartType.flapLeft:
      case AircraftPartType.flapRight:
        return const Color(0xFFDA9A2A);
      case AircraftPartType.aileronLeft:
      case AircraftPartType.aileronRight:
        return const Color(0xFF219D98);
      case AircraftPartType.elevatorLeft:
      case AircraftPartType.elevatorRight:
      case AircraftPartType.rudder:
        return const Color(0xFF6678D8);
      case AircraftPartType.engineSingle:
      case AircraftPartType.engineLeft:
      case AircraftPartType.engineRight:
      case AircraftPartType.engineCenter:
        return const Color(0xFFD86666);
      case AircraftPartType.propeller:
      case AircraftPartType.rotorMain:
        return const Color(0xFF7F5E43);
      case AircraftPartType.noseGear:
      case AircraftPartType.mainGearLeft:
      case AircraftPartType.mainGearRight:
      case AircraftPartType.mainGearCenter:
        return const Color(0xFF8C7661);
    }
  }

  Offset _rotate(Offset point, Offset pivot, double radians) {
    final dx = point.dx - pivot.dx;
    final dy = point.dy - pivot.dy;
    final s = math.sin(radians);
    final c = math.cos(radians);
    return Offset(pivot.dx + (dx * c) - (dy * s), pivot.dy + (dx * s) + (dy * c));
  }

  Color _shade(Color color, double factor) {
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).round().clamp(0, 255),
      (color.green * factor).round().clamp(0, 255),
      (color.blue * factor).round().clamp(0, 255),
    );
  }

  Offset _centroid(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    double x = 0;
    double y = 0;
    for (final p in points) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  void _drawCenteredLabel(Canvas canvas, Offset center, String text, {Color color = Colors.white70, double fontSize = 12}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  void _drawLabel(Canvas canvas, Offset offset, String text, {Color color = Colors.white70}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant GroundOpsPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.selectedPartId != selectedPartId ||
        oldDelegate.selectedDoorId != selectedDoorId ||
        oldDelegate.selectedLightId != selectedLightId ||
        oldDelegate.selectedServicePointId != selectedServicePointId ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showDoors != showDoors ||
        oldDelegate.showLights != showLights ||
        oldDelegate.showServicePoints != showServicePoints ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.simData != simData ||
        oldDelegate.time != time ||
        oldDelegate.propAngle != propAngle ||
        oldDelegate.blurLevel != blurLevel ||
        oldDelegate.wobbleX != wobbleX ||
        oldDelegate.wobbleY != wobbleY ||
        oldDelegate.shutdownBlend != shutdownBlend;
  }
}
