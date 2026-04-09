import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:skycase/models/airport_frequencies.dart';
import 'package:skycase/models/vors.dart';
import '../models/ndb.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// --- Background Parsers ---
List<Vor> _parseVors(String jsonStr) {
  final List<dynamic> jsonList = json.decode(jsonStr);
  return jsonList.map((e) => Vor.fromJson(e)).toList();
}

List<Ndb> _parseNdbs(String jsonStr) {
  final List<dynamic> jsonList = json.decode(jsonStr);
  return jsonList.map((e) => Ndb.fromJson(e)).toList();
}

class NavRepository {
  static final NavRepository _instance = NavRepository._internal();
  factory NavRepository() => _instance;
  NavRepository._internal();

  bool _vorsLoaded = false;
  bool _ndbsLoaded = false;
  final List<Vor> vors = [];
  final List<Ndb> ndbs = [];

  Future<void> loadVors() async {
    if (_vorsLoaded) return;
    final jsonStr = await rootBundle.loadString('assets/data/vors.json');
    final list = await compute(_parseVors, jsonStr);
    vors.addAll(list);
    _vorsLoaded = true;
  }

  Future<void> loadNdbs() async {
    if (_ndbsLoaded) return;
    final jsonStr = await rootBundle.loadString('assets/data/ndb.json');
    final list = await compute(_parseNdbs, jsonStr);
    ndbs.addAll(list);
    _ndbsLoaded = true;
  }
}

// Helper class για να επιστρέφουμε δύο πράγματα από το compute
class FreqData {
  final List<AirportFrequency> all;
  final Map<String, List<AirportFrequency>> grouped;
  FreqData(this.all, this.grouped);
}

// Αυτό τρέχει σε δικό του thread
FreqData _parseFreqBackground(String jsonStr) {
  final List<dynamic> jsonList = json.decode(jsonStr);
  final list = jsonList.map((e) => AirportFrequency.fromJson(e)).toList();

  final Map<String, List<AirportFrequency>> grouped = {};
  for (final f in list) {
    grouped.putIfAbsent(f.airportIdent, () => []).add(f);
  }
  return FreqData(list, grouped);
}

class FrequencyRepository {
  static final FrequencyRepository _instance = FrequencyRepository._internal();
  factory FrequencyRepository() => _instance;
  FrequencyRepository._internal();

  bool _loaded = false;
  List<AirportFrequency> allFrequencies = [];
  Map<String, List<AirportFrequency>> freqByIcao = {};

  Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString(
      'assets/data/airport_frequencies.json',
    );
    final data = await compute(_parseFreqBackground, jsonStr);

    allFrequencies = data.all;
    freqByIcao = data.grouped;
    _loaded = true;
  }
}
