import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:skycase/models/simlink_data.dart';

enum AircraftIconType {
  singleEngineProp,
  twinTurboprop,
  jet,
  airliner,
  helicopter,
  unknown,
}

class AircraftMarkerIcon extends StatelessWidget {
  final SimLinkData data;
  final double size;
  final double rotationAngle;
  final double spinPhase;
  final Color color;

  const AircraftMarkerIcon({
    super.key,
    required this.data,
    required this.rotationAngle,
    required this.spinPhase,
    required this.color,
    this.size = 40,
  });

  static AircraftIconType detectType(SimLinkData data) {
    final title = data.title.toLowerCase().trim();
    final category = data.aircraftCategory.toLowerCase().trim();

    bool hasAny(List<String> values) {
      for (final value in values) {
        if (title.contains(value) || category.contains(value)) return true;
      }
      return false;
    }

    // Helicopters
    if (hasAny([
      'helicopter',
      'heli',
      'h125',
      'h145',
      'h160',
      'cabri',
      'robinson',
      'r22',
      'r44',
      'r66',
      'chinook',
      'ch-47',
      'ch47',
      'black hawk',
      'blackhawk',
      'uh-60',
      'uh60',
      'bell 206',
      'bell 407',
      'ec135',
      'as350',
    ])) {
      return AircraftIconType.helicopter;
    }

    // Big airliners
    if (hasAny([
      'airbus',
      'boeing',
      'a318',
      'a319',
      'a320',
      'a321',
      'a330',
      'a340',
      'a350',
      'a380',
      'b707',
      'b717',
      'b727',
      'b737',
      'b738',
      'b739',
      'b747',
      'b757',
      'b767',
      'b777',
      'b787',
      'md-11',
      'dc-10',
      'crj',
      'embraer 170',
      'embraer 175',
      'embraer 190',
      'embraer 195',
      'e170',
      'e175',
      'e190',
      'e195',
      'airliner',
      'air transport',
      'transport',
    ])) {
      return AircraftIconType.airliner;
    }

    // Twin turboprops
    if (hasAny([
      'king air',
      'beechcraft 1900',
      'c208',
      'caravan',
      'grand caravan',
      'atr',
      'dash 8',
      'dhc-6',
      'dhc6',
      'twin otter',
      'tbm',
      'pc-12',
      'do228',
      'fokker 50',
      'saab 340',
      'metroliner',
      'turboprop',
    ])) {
      return AircraftIconType.twinTurboprop;
    }

    // Jets / bizjets / military jets
    if (hasAny([
      'citation',
      'cj4',
      'longitude',
      'challenger',
      'global',
      'gulfstream',
      'learjet',
      'falcon',
      'bizjet',
      'jet',
      'fighter',
      'f-16',
      'f16',
      'f-18',
      'f18',
    ])) {
      return AircraftIconType.jet;
    }

    // Single engine GA prop
    if (hasAny([
      'cessna',
      'c152',
      'c150',
      'c172',
      'c182',
      'c206',
      'bonanza',
      'baron',
      'pa-28',
      'pa28',
      'piper',
      'cub',
      'xcub',
      'wilga',
      'mooney',
      'diamond',
      'da40',
      'da42',
      'sr22',
      'cirrus',
      'single engine',
      'prop',
      'propeller',
    ])) {
      return AircraftIconType.singleEngineProp;
    }

    return AircraftIconType.unknown;
  }

  bool get _shouldAnimate {
    final type = detectType(data);
    if (!data.combustion && data.rpm < 80) return false;
    return type == AircraftIconType.singleEngineProp ||
        type == AircraftIconType.twinTurboprop ||
        type == AircraftIconType.helicopter;
  }

  @override
  Widget build(BuildContext context) {
    final type = detectType(data);

    return Transform.rotate(
      angle: rotationAngle,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: AircraftMarkerPainter(
            type: type,
            color: color,
            spinPhase: spinPhase,
            animateSpin: _shouldAnimate,
          ),
        ),
      ),
    );
  }
}

class AircraftMarkerPainter extends CustomPainter {
  final AircraftIconType type;
  final Color color;
  final double spinPhase;
  final bool animateSpin;

  AircraftMarkerPainter({
    required this.type,
    required this.color,
    required this.spinPhase,
    required this.animateSpin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case AircraftIconType.singleEngineProp:
        _paintSingleEngineProp(canvas, size);
        break;
      case AircraftIconType.twinTurboprop:
        _paintTwinTurboprop(canvas, size);
        break;
      case AircraftIconType.jet:
        _paintJet(canvas, size);
        break;
      case AircraftIconType.airliner:
        _paintAirliner(canvas, size);
        break;
      case AircraftIconType.helicopter:
        _paintHelicopter(canvas, size);
        break;
      case AircraftIconType.unknown:
        _paintGeneric(canvas, size);
        break;
    }
  }

  Paint get _fill => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;

  Paint get _spinPaint => Paint()
    ..color = color.withOpacity(0.32)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;

  void _paintSingleEngineProp(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // fuselage
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.14,
          height: size.height * 0.58,
        ),
        Radius.circular(size.width * 0.05),
      ),
      _fill,
    );

    // wings
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.02),
          width: size.width * 0.62,
          height: size.height * 0.08,
        ),
        Radius.circular(size.width * 0.025),
      ),
      _fill,
    );

    // horizontal stabilizer
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.21),
          width: size.width * 0.24,
          height: size.height * 0.05,
        ),
        Radius.circular(size.width * 0.02),
      ),
      _fill,
    );

    // nose cone
    canvas.drawCircle(
      Offset(cx, cy - size.height * 0.30),
      size.width * 0.045,
      _fill,
    );

    if (animateSpin) {
      canvas.save();
      canvas.translate(cx, cy - size.height * 0.31);
      canvas.rotate(spinPhase * math.pi * 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.22,
          height: size.height * 0.07,
        ),
        _spinPaint,
      );
      canvas.restore();
    } else {
      canvas.drawLine(
        Offset(cx, cy - size.height * 0.36),
        Offset(cx, cy - size.height * 0.26),
        _stroke,
      );
      canvas.drawLine(
        Offset(cx - size.width * 0.06, cy - size.height * 0.31),
        Offset(cx + size.width * 0.06, cy - size.height * 0.31),
        _stroke,
      );
    }
  }

  void _paintTwinTurboprop(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.16,
          height: size.height * 0.62,
        ),
        Radius.circular(size.width * 0.05),
      ),
      _fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.72,
          height: size.height * 0.10,
        ),
        Radius.circular(size.width * 0.025),
      ),
      _fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.22),
          width: size.width * 0.28,
          height: size.height * 0.05,
        ),
        Radius.circular(size.width * 0.02),
      ),
      _fill,
    );

    final leftProp = Offset(cx - size.width * 0.24, cy);
    final rightProp = Offset(cx + size.width * 0.24, cy);

    if (animateSpin) {
      for (final p in [leftProp, rightProp]) {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(spinPhase * math.pi * 2);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width * 0.14,
            height: size.height * 0.14,
          ),
          _spinPaint,
        );
        canvas.restore();
      }
    } else {
      for (final p in [leftProp, rightProp]) {
        canvas.drawLine(
          Offset(p.dx, p.dy - size.height * 0.06),
          Offset(p.dx, p.dy + size.height * 0.06),
          _stroke,
        );
        canvas.drawLine(
          Offset(p.dx - size.width * 0.06, p.dy),
          Offset(p.dx + size.width * 0.06, p.dy),
          _stroke,
        );
      }
    }
  }

  void _paintJet(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.15,
          height: size.height * 0.66,
        ),
        Radius.circular(size.width * 0.05),
      ),
      _fill,
    );

    final wingPath = Path()
      ..moveTo(cx - size.width * 0.28, cy + size.height * 0.02)
      ..lineTo(cx, cy - size.height * 0.05)
      ..lineTo(cx + size.width * 0.28, cy + size.height * 0.02)
      ..lineTo(cx, cy + size.height * 0.08)
      ..close();

    canvas.drawPath(wingPath, _fill);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.22),
          width: size.width * 0.20,
          height: size.height * 0.05,
        ),
        Radius.circular(size.width * 0.02),
      ),
      _fill,
    );
  }

  void _paintAirliner(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.17,
          height: size.height * 0.76,
        ),
        Radius.circular(size.width * 0.05),
      ),
      _fill,
    );

    final wingPath = Path()
      ..moveTo(cx - size.width * 0.38, cy)
      ..lineTo(cx, cy - size.height * 0.06)
      ..lineTo(cx + size.width * 0.38, cy)
      ..lineTo(cx, cy + size.height * 0.07)
      ..close();

    canvas.drawPath(wingPath, _fill);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.25),
          width: size.width * 0.24,
          height: size.height * 0.05,
        ),
        Radius.circular(size.width * 0.02),
      ),
      _fill,
    );
  }

  void _paintHelicopter(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - size.height * 0.02),
          width: size.width * 0.24,
          height: size.height * 0.30,
        ),
        Radius.circular(size.width * 0.08),
      ),
      _fill,
    );

    // tail boom
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.20),
          width: size.width * 0.06,
          height: size.height * 0.28,
        ),
        Radius.circular(size.width * 0.02),
      ),
      _fill,
    );

    // skids
    canvas.drawLine(
      Offset(cx - size.width * 0.14, cy + size.height * 0.12),
      Offset(cx - size.width * 0.03, cy + size.height * 0.12),
      _stroke,
    );
    canvas.drawLine(
      Offset(cx + size.width * 0.03, cy + size.height * 0.12),
      Offset(cx + size.width * 0.14, cy + size.height * 0.12),
      _stroke,
    );

    final rotorCenter = Offset(cx, cy - size.height * 0.06);

    if (animateSpin) {
      canvas.save();
      canvas.translate(rotorCenter.dx, rotorCenter.dy);
      canvas.rotate(spinPhase * math.pi * 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.72,
          height: size.height * 0.10,
        ),
        _spinPaint,
      );
      canvas.restore();
    } else {
      canvas.drawLine(
        Offset(cx - size.width * 0.30, rotorCenter.dy),
        Offset(cx + size.width * 0.30, rotorCenter.dy),
        _stroke,
      );
      canvas.drawLine(
        Offset(cx, rotorCenter.dy - size.height * 0.10),
        Offset(cx, rotorCenter.dy + size.height * 0.10),
        _stroke,
      );
    }

    // tail rotor
    canvas.drawLine(
      Offset(cx - size.width * 0.05, cy + size.height * 0.33),
      Offset(cx + size.width * 0.05, cy + size.height * 0.33),
      _stroke,
    );
  }

  void _paintGeneric(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.15,
          height: size.height * 0.58,
        ),
        Radius.circular(size.width * 0.05),
      ),
      _fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.52,
          height: size.height * 0.07,
        ),
        Radius.circular(size.width * 0.02),
      ),
      _fill,
    );
  }

  @override
  bool shouldRepaint(covariant AircraftMarkerPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.spinPhase != spinPhase ||
        oldDelegate.animateSpin != animateSpin;
  }
}