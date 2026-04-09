import 'dart:ui';

import 'package:skycase/models/ground_ops/ground_ops_template.dart';

extension NormalizedPointCanvasX on NormalizedPoint {
  Offset toCanvas(Size size) {
    return Offset(x * size.width, y * size.height);
  }
}

extension PolygonCanvasX on List<NormalizedPoint> {
  List<Offset> toCanvasOffsets(Size size) {
    return map((p) => p.toCanvas(size)).toList();
  }
}