import 'package:flutter/material.dart';

class NdbMarkerPainter extends CustomPainter {
  final Color color;
  final Color strokeColor;

  const NdbMarkerPainter({
    required this.color,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final fill = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final glow = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final coreR = size.width * 0.15;
    final ring1 = size.width * 0.28;
    final ring2 = size.width * 0.41;

    canvas.drawCircle(center, ring2, glow);

    // beacon core
    canvas.drawCircle(center, coreR, fill);
    canvas.drawCircle(center, coreR, stroke);

    // radio waves
    canvas.drawCircle(center, ring1, stroke);
    canvas.drawCircle(center, ring2, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}