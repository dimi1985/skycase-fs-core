import 'dart:math';

import 'package:flutter/material.dart';

class VorMarkerPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;

  const VorMarkerPainter({
    required this.color,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width * 0.42;
    final innerR = size.width * 0.16;

    final fill = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..isAntiAlias = true;

    final glow = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    // shadow/glow
    canvas.drawCircle(center, outerR, glow);

    // hexagon / compass-style body
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (-pi / 2) + (i * pi / 3);
      final p = Offset(
        center.dx + cos(angle) * outerR,
        center.dy + sin(angle) * outerR,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // center ring
    canvas.drawCircle(center, innerR, stroke);

    // radial cross
    canvas.drawLine(
      Offset(center.dx, center.dy - outerR * 0.72),
      Offset(center.dx, center.dy + outerR * 0.72),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx - outerR * 0.72, center.dy),
      Offset(center.dx + outerR * 0.72, center.dy),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}