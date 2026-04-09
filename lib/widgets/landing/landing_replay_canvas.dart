import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class LandingReplayPoint {
  final double x;
  final double y;
  final Duration elapsed;

  const LandingReplayPoint({
    required this.x,
    required this.y,
    required this.elapsed,
  });
}

class LandingReplayCanvas extends StatelessWidget {
  final List<LandingReplayPoint> points;
  final LandingReplayPoint currentPosition;
  final double playedProgress;
  final int touchdownIndex;
  final String runway;
  final double planeHeadingRad;

  const LandingReplayCanvas({
    super.key,
    required this.points,
    required this.currentPosition,
    required this.playedProgress,
    required this.touchdownIndex,
    required this.runway,
    required this.planeHeadingRad,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LandingReplayCanvasPainter(
        points: points,
        currentPosition: currentPosition,
        playedProgress: playedProgress,
        touchdownIndex: touchdownIndex,
        runway: runway,
        textDirection: Directionality.of(context),
      ),
      child: const SizedBox.expand(),
      foregroundPainter: _LandingReplayPlanePainter(
        currentPosition: currentPosition,
        planeHeadingRad: planeHeadingRad,
      ),
    );
  }
}

class _LandingReplayCanvasPainter extends CustomPainter {
  final List<LandingReplayPoint> points;
  final LandingReplayPoint currentPosition;
  final double playedProgress;
  final int touchdownIndex;
  final String runway;
  final ui.TextDirection textDirection;

  const _LandingReplayCanvasPainter({
    required this.points,
    required this.currentPosition,
    required this.playedProgress,
    required this.touchdownIndex,
    required this.runway,
    required this.textDirection,
  });

  static const double _baseWidth = 1000.0;
  static const double _baseHeight = 650.0;
  static const Rect _runwayRect = Rect.fromLTWH(700, 425, 220, 12);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _baseWidth;
    final scaleY = size.height / _baseHeight;

    final bgPaint = Paint()..color = const Color(0xFF09111A);
    final framePaint = Paint()
      ..color = const Color(0xFF1A2733)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final runwayFill = Paint()..color = const Color(0xFF303943);
    final runwayStroke = Paint()
      ..color = const Color(0xFF8B95A1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centerlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fullPathPaint = Paint()
      ..color = const Color(0xFF2D4C63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final playedPathPaint = Paint()
      ..color = const Color(0xFF63D7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final touchdownGhostPaint = Paint()
      ..color = const Color(0xFFFFC44D).withValues(alpha: 0.24);

    final touchdownPaint = Paint()..color = const Color(0xFFFFC44D);

    final bgRect = Offset.zero & size;
    final bg = RRect.fromRectAndRadius(bgRect, const Radius.circular(14));
    canvas.drawRRect(bg, bgPaint);
    canvas.drawRRect(bg, framePaint);

    if (points.length < 2) {
      _drawCenteredText(canvas, size, 'Landing replay unavailable');
      return;
    }

    final runwayRect = Rect.fromLTWH(
      _runwayRect.left * scaleX,
      _runwayRect.top * scaleY,
      _runwayRect.width * scaleX,
      _runwayRect.height * scaleY,
    );

    final runwayRRect =
        RRect.fromRectAndRadius(runwayRect, Radius.circular(5 * scaleX));
    canvas.drawRRect(runwayRRect, runwayFill);
    canvas.drawRRect(runwayRRect, runwayStroke);

    final centerY = runwayRect.center.dy;
    canvas.drawLine(
      Offset(runwayRect.left + (8 * scaleX), centerY),
      Offset(runwayRect.right - (8 * scaleX), centerY),
      centerlinePaint,
    );

    _drawRunwayLabels(canvas, runwayRect);

    final scaledPoints = points
        .map((p) => Offset(p.x * scaleX, p.y * scaleY))
        .toList();

    final fullPath = Path()..moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
    for (int i = 1; i < scaledPoints.length; i++) {
      fullPath.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
    }
    canvas.drawPath(fullPath, fullPathPaint);

    final currentIndex =
        ((scaledPoints.length - 1) * playedProgress).floor().clamp(0, scaledPoints.length - 1);

    if (currentIndex > 0) {
      final playedPath = Path()
        ..moveTo(scaledPoints.first.dx, scaledPoints.first.dy);
      for (int i = 1; i <= currentIndex; i++) {
        playedPath.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
      }
      playedPath.lineTo(
        currentPosition.x * scaleX,
        currentPosition.y * scaleY,
      );
      canvas.drawPath(playedPath, playedPathPaint);
    }

    final td = scaledPoints[touchdownIndex];
    canvas.drawCircle(td, 10 * scaleX, touchdownGhostPaint);
    canvas.drawCircle(td, 4.8 * scaleX, touchdownPaint);
  }

  void _drawRunwayLabels(Canvas canvas, Rect runwayRect) {
    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'runway',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    labelPainter.paint(
      canvas,
      Offset(
        runwayRect.center.dx - (labelPainter.width / 2),
        runwayRect.top - 18,
      ),
    );

    _drawSmallText(
      canvas,
      _runwayLeftNumber(runway),
      Offset(runwayRect.left - 16, runwayRect.top - 2),
    );

    _drawSmallText(
      canvas,
      _runwayRightNumber(runway),
      Offset(runwayRect.right + 4, runwayRect.top - 2),
    );
  }

  String _runwayLeftNumber(String runway) {
    final match = RegExp(r'(\d{2})').firstMatch(runway);
    if (match == null) return '—';
    return match.group(1)!;
  }

  String _runwayRightNumber(String runway) {
    final left = _runwayLeftNumber(runway);
    final value = int.tryParse(left);
    if (value == null) return '—';
    final opposite = ((value + 18 - 1) % 36) + 1;
    return opposite.toString().padLeft(2, '0');
  }

  void _drawSmallText(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    tp.paint(canvas, offset);
  }

  void _drawCenteredText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LandingReplayCanvasPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.currentPosition != currentPosition ||
        oldDelegate.playedProgress != playedProgress ||
        oldDelegate.touchdownIndex != touchdownIndex ||
        oldDelegate.runway != runway ||
        oldDelegate.textDirection != textDirection;
  }
}

class _LandingReplayPlanePainter extends CustomPainter {
  final LandingReplayPoint currentPosition;
  final double planeHeadingRad;

  const _LandingReplayPlanePainter({
    required this.currentPosition,
    required this.planeHeadingRad,
  });

  static const double _baseWidth = 1000.0;
  static const double _baseHeight = 650.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _baseWidth;
    final scaleY = size.height / _baseHeight;

    final center = Offset(
      currentPosition.x * scaleX,
      currentPosition.y * scaleY,
    );

    final paint = Paint()..color = Colors.white;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(planeHeadingRad);

    final body = Path()
      ..moveTo(0, -14 * scaleY)
      ..lineTo(7 * scaleX, 8 * scaleY)
      ..lineTo(0, 4 * scaleY)
      ..lineTo(-7 * scaleX, 8 * scaleY)
      ..close();

    canvas.drawPath(body, paint);

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(Offset.zero, 10 * math.max(scaleX, scaleY), glow);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LandingReplayPlanePainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.planeHeadingRad != planeHeadingRad;
  }
}