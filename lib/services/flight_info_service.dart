import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flight_info.dart';

class FlightInfoService {
  static const baseUrl = "http://38.242.241.46:3000/api/flightinfo";

  static Future<FlightInfo?> lookup(String callsign) async {
    final uri = Uri.parse("$baseUrl/lookup?callsign=$callsign");

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      return FlightInfo.fromJson(jsonDecode(res.body));

    } catch (e) {
      print("❌ FlightInfo error: $e");
      return null;
    }
  }
}
