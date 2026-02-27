import 'package:flutter/material.dart';
import 'package:skycase/widgets/map_view.dart';

class MapScreen extends StatelessWidget {
  final String? jobFrom;
  final String? jobTo;
  final String? jobId;

  const MapScreen({
  super.key,
  this.jobFrom,
  this.jobTo,
  this.jobId,   // ⭐ NEW
});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapView(
        jobFrom: jobFrom,
        jobTo: jobTo,
        jobId:jobId
      ),
    );
  }
}
