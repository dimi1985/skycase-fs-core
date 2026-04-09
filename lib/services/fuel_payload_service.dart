import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/fuel_tanks.dart';
class FuelPayloadService {
  final String baseUrl;

  const FuelPayloadService({
    required this.baseUrl,
  });

  Future<bool> sendFuelUpdate(FuelTanks tanks) async {
    try {
      final uri = Uri.parse('$baseUrl/api/simlink/fuel-update');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'tanks': tanks.toJson(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      print('sendFuelUpdate failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('sendFuelUpdate error: $e');
      return false;
    }
  }


}