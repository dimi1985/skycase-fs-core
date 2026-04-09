// lib/services/simbrief_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SimBriefImportResult {
  final String source;
  final String destination;
  final String route;
  final String? alternate;
  final String? flightNumber;
  final String? aircraftIcao;
  final String? cruiseAltitude;
  final Map<String, dynamic> raw;

  const SimBriefImportResult({
    required this.source,
    required this.destination,
    required this.route,
    required this.raw,
    this.alternate,
    this.flightNumber,
    this.aircraftIcao,
    this.cruiseAltitude,
  });
}

class SimBriefService {
  static const String _baseUrl = 'https://www.simbrief.com/api/xml.fetcher.php';

  Future<SimBriefImportResult> fetchLatestOfp({
    String? username,
    String? pilotId,
  }) async {
    final hasUsername = username != null && username.trim().isNotEmpty;
    final hasPilotId = pilotId != null && pilotId.trim().isNotEmpty;

    if (!hasUsername && !hasPilotId) {
      throw Exception('Please provide a SimBrief username or Pilot ID.');
    }

    final query = <String, String>{
      if (hasUsername) 'username': username!.trim(),
      if (hasPilotId) 'userid': pilotId!.trim(),
      // official docs mention json=1, forum mentions json=v2
      // try v2 first for richer JSON, then caller can fall back if needed
      'json': 'v2',
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: query);

    debugPrint('SimBrief fetch: $uri');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'SimBrief returned ${response.statusCode}. Check username/Pilot ID and make sure an OFP exists.',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid SimBrief response.');
    }

    final origin = _readString(decoded, [
      ['origin', 'icao_code'],
      ['origin', 'icao'],
      ['general', 'orig_icao'],
      ['general', 'departure_airport', 'icao_code'],
    ]);

    final destination = _readString(decoded, [
      ['destination', 'icao_code'],
      ['destination', 'icao'],
      ['general', 'dest_icao'],
      ['general', 'arrival_airport', 'icao_code'],
    ]);

    final route = _readString(decoded, [
      ['general', 'route'],
      ['navlog', 'route'],
      ['atc', 'route'],
    ]);

    final alternate = _readString(decoded, [
      ['alternate', 'icao_code'],
      ['general', 'alt_icao'],
    ]);

    final flightNumber = _readString(decoded, [
      ['general', 'flight_number'],
      ['general', 'flightno'],
    ]);

    final aircraftIcao = _readString(decoded, [
      ['aircraft', 'icaocode'],
      ['aircraft', 'icao_code'],
      ['general', 'icao_aircraft'],
    ]);

    final cruiseAltitude = _readString(decoded, [
      ['general', 'initial_altitude'],
      ['general', 'cruise_altitude'],
      ['general', 'avg_altitude'],
    ]);

    if (origin == null || destination == null) {
      throw Exception(
        'SimBrief OFP loaded, but departure/destination were missing.',
      );
    }

    return SimBriefImportResult(
      source: origin.toUpperCase(),
      destination: destination.toUpperCase(),
      route: route?.trim() ?? '',
      alternate: alternate?.toUpperCase(),
      flightNumber: flightNumber,
      aircraftIcao: aircraftIcao?.toUpperCase(),
      cruiseAltitude: cruiseAltitude,
      raw: decoded,
    );
  }

  String? _readString(
    Map<String, dynamic> json,
    List<List<String>> candidatePaths,
  ) {
    for (final path in candidatePaths) {
      dynamic current = json;
      bool failed = false;

      for (final segment in path) {
        if (current is Map<String, dynamic> && current.containsKey(segment)) {
          current = current[segment];
        } else {
          failed = true;
          break;
        }
      }

      if (!failed && current != null) {
        final value = current.toString().trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }
}