import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:skycase/models/airway_segment.dart';

class AirwayRepository {
  static final AirwayRepository _instance = AirwayRepository._internal();
  factory AirwayRepository() => _instance;
  AirwayRepository._internal();

  List<AirwaySegment> _segments = [];

  List<AirwaySegment> get segments => _segments;

  Future<void> load() async {
    if (_segments.isNotEmpty) return;

    final raw = await rootBundle.loadString('assets/data/airways.json');
    final List<dynamic> data = jsonDecode(raw);

    _segments =
        data
            .map((e) => AirwaySegment.fromJson(e as Map<String, dynamic>))
            .toList();
  }
}