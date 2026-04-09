import 'package:flutter/material.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/widgets/ground_ops/ground_ops_canvas_area.dart';

class AnimatedGroundOps extends StatelessWidget {
  final SimLinkData? simData;
  final GroundOpsTemplate? template;
  final bool minimalView;

  const AnimatedGroundOps({
    super.key,
    required this.simData,
    required this.template,
    this.minimalView = false,
  });

  @override
  Widget build(BuildContext context) {
    return GroundOpsCanvasArea(
      simData: simData,
      template: template,
      minimalView: minimalView,
    );
  }
}