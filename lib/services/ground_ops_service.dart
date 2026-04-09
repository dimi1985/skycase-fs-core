import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:skycase/models/fuel_tanks.dart';
import 'package:skycase/models/job_payload.dart';

import '../models/ground_state.dart';

class GroundOpsService {
  final String baseUrl;
  final String token;

  GroundOpsService({
    required this.baseUrl,
    required this.token,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ========================
  // LOAD STATE
  // ========================
  Future<GroundState?> getState(String aircraftId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/ground-state/$aircraftId'),
      headers: _headers,
    );

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body);
    return GroundState.fromJson(data);
  }

  // ========================
  // SAVE STATE
  // ========================
  Future<void> saveState({
    required String aircraftId,
    required String aircraftTitle,
    required double fuelGallons,
    required double fuelCapacityGallons,
    required FuelTanks fuelTanks,
    required JobPayload payload,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/ground-state/save'),
      headers: _headers,
      body: jsonEncode({
        "aircraftId": aircraftId,
        "aircraftTitle": aircraftTitle,
        "fuelGallons": fuelGallons,
        "fuelCapacityGallons": fuelCapacityGallons,
        "fuelTanks": {
          "leftMain": fuelTanks.leftMain,
          "rightMain": fuelTanks.rightMain,
          "center": fuelTanks.center,
          "leftAux": fuelTanks.leftAux,
          "rightAux": fuelTanks.rightAux,
        },
        "jobPayload": {
          "totalWeight": payload.totalWeight,
          "cargoWeight": payload.cargoWeight,
          "passengerWeight": payload.passengerWeight,
          "note": payload.note,
          "ready": payload.ready,
        }
      }),
    );
  }

  // ========================
  // APPLY FUEL TO SIM
  // ========================
  Future<void> applyFuel(String aircraftId) async {
    await http.post(
      Uri.parse('$baseUrl/ground-state/$aircraftId/apply-fuel'),
      headers: _headers,
    );
  }
}