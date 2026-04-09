import 'dart:math' as math;
import 'package:flutter/material.dart';

class DeepZoomGridLayer extends StatelessWidget {
  final double zoom;
  final Color gridColor;
  final Color crossColor;
  final double startZoom;

  const DeepZoomGridLayer({
    super.key,
    required this.zoom,
    required this.gridColor,
    required this.crossColor,
    this.startZoom = 11,
  });

  @override
  Widget build(BuildContext context) {
    if (zoom < startZoom) {
      return const SizedBox.shrink();
    }

    final t = ((zoom - startZoom) / 9.0).clamp(0.0, 1.0);

    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _DeepZoomGridPainter(
            gridColor: gridColor,
            crossColor: crossColor,
            zoomT: t,
          ),
        ),
      ),
    );
  }
}

class _DeepZoomGridPainter extends CustomPainter {
  final Color gridColor;
  final Color crossColor;
  final double zoomT;

  const _DeepZoomGridPainter({
    required this.gridColor,
    required this.crossColor,
    required this.zoomT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const targetColumns = 4.0;
    final spacing = math.max(160.0, size.width / targetColumns);

    final majorPaint = Paint()
      ..color = Color.lerp(
            gridColor.withOpacity(0.05),
            gridColor.withOpacity(0.12),
            zoomT,
          ) ??
          gridColor.withOpacity(0.08)
      ..strokeWidth = 1.0;

    final crossPaint = Paint()
      ..color = Color.lerp(
            crossColor.withOpacity(0.02),
            crossColor.withOpacity(0.06),
            zoomT,
          ) ??
          crossColor.withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }

    const crossSize = 4.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawLine(
          Offset(x - crossSize, y),
          Offset(x + crossSize, y),
          crossPaint,
        );
        canvas.drawLine(
          Offset(x, y - crossSize),
          Offset(x, y + crossSize),
          crossPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DeepZoomGridPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor ||
        oldDelegate.crossColor != crossColor ||
        oldDelegate.zoomT != zoomT;
  }
}