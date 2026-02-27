import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:skycase/models/airport.dart';
import 'package:skycase/services/metar_service.dart';
import 'package:skycase/services/simlink_service.dart';

class WeatherEngineService {
  static const double simRadiusKm = 20; // Aircraft weather override radius
  static final Distance _dist = Distance();

  // ============================================================
  //  PUBLIC API
  // ============================================================
  static Future<Map<String, dynamic>> getAirportWeather(
    Airport airport,
  ) async {
    final icao = airport.icao.toUpperCase();

    // 1️⃣ SIMLINK (closest to reality in the SIM)
    final sim = await _trySimLinkWeather(airport);
    if (sim != null) {
      return {...sim, "source": "SIMLINK"};
    }

    // 2️⃣ REAL METAR
    final real = await MetarService.getBriefing(icao);
    if (real != null && (real["raw"] ?? "") != "N/A") {
      // Add visibilityMeters safely
      return {
        ...real,
        "visibilityMeters": _normalizeVisibility(real["visibility"]),
        "source": "REAL"
      };
    }

    // 3️⃣ REGIONAL FALLBACK
    final near = await _nearestRealMetarFallback(airport);
    if (near != null) {
      return {...near, "source": "REGIONAL"};
    }

    // 4️⃣ SYNTHETIC WEATHER
    final model = _generateSyntheticWeather(airport);
    return {...model, "source": "MODEL"};
  }

  // ============================================================
  //  SIMLINK WEATHER
  // ============================================================
  static Future<Map<String, dynamic>?> _trySimLinkWeather(
    Airport airport,
  ) async {
    final sim = SimLinkService.latest;
    if (sim == null) return null;

    final w = sim.weather;

    // distance check
    final distKm = _dist.as(
      LengthUnit.Kilometer,
      LatLng(airport.lat, airport.lon),
      LatLng(sim.latitude, sim.longitude),
    );

    if (distKm > simRadiusKm) return null;

    return {
      "icao": airport.icao,
      "raw": "SIMLINK WX",
      "wind":
          "${w.windDirection.toStringAsFixed(0).padLeft(3, '0')}${w.windVelocity.toStringAsFixed(0)}KT",
      "temp": w.temperature.toStringAsFixed(0),
      "dewpoint": (w.temperature - 3).toStringAsFixed(0),
      "clouds": _cloudLayerFromDensity(w.cloudDensity),
      "visibility": _visibilityFromSim(w.visibility),
      "visibilityMeters": _normalizeVisibility(w.visibility),
      "pressure": "Q${w.seaLevelPressure.toStringAsFixed(0)}",
      "category": _categoryFromSim(w),
    };
  }

  // ============================================================
  //  REGIONAL FALLBACK
  // ============================================================
  static Future<Map<String, dynamic>?> _nearestRealMetarFallback(
    Airport airport,
  ) async {
    final icaoList = MetarService.majorAerodromes();

    for (final cand in icaoList) {
      final wx = await MetarService.getBriefing(cand);
      if (wx == null) continue;
      if ((wx["raw"] ?? "") == "N/A") continue;

      final blended = _blendMetarToAirport(airport, wx);

      // add new field
      blended["visibilityMeters"] =
          _normalizeVisibility(blended["visibility"]);

      return blended;
    }

    return null;
  }

  // ============================================================
  //  BLEND REAL METAR TO TARGET AIRPORT
  // ============================================================
  static Map<String, dynamic> _blendMetarToAirport(
    Airport target,
    Map<String, dynamic> metar,
  ) {
    final rnd = Random();

    // temperature
    double temp = double.tryParse(metar["temp"].toString()) ?? 18;
    temp -= (target.elevation / 1000) * 2; // lapse rate
    temp += rnd.nextDouble() * 1.5 - 0.7;

    // pressure
    final rawP = metar["pressure"] ?? "Q1015";
    double pressure = 1015;
    if (rawP.toString().startsWith("Q")) {
      pressure = double.tryParse(rawP.toString().replaceAll("Q", "")) ?? 1015;
    }
    pressure += rnd.nextDouble() * 1.2 - 0.6;

    return {
      "icao": target.icao,
      "raw": "EST ${metar["raw"]}",
      "wind": metar["wind"] ?? "",
      "temp": temp.toStringAsFixed(0),
      "dewpoint": metar["dewpoint"] ?? "",
      "clouds": metar["clouds"] ?? [],
      "visibility": metar["visibility"] ?? "N/A",
      "pressure": "Q${pressure.toStringAsFixed(0)}",
      "category": metar["category"] ?? "UNKNOWN",
    };
  }

  // ============================================================
  //  SYNTHETIC WEATHER
  // ============================================================
  static Map<String, dynamic> _generateSyntheticWeather(Airport airport) {
    final rnd = Random();

    final temp =
        15 - (airport.elevation / 1000) * 2 + rnd.nextInt(4) - 2;

    final clouds = () {
      final r = rnd.nextDouble();
      if (r < 0.2) return [];
      if (r < 0.5) return ["FEW030"];
      if (r < 0.8) return ["SCT040"];
      return ["BKN050"];
    }();

    return {
      "icao": airport.icao,
      "raw": "MODEL WX",
      "wind":
          "${(rnd.nextInt(360)).toString().padLeft(3, '0')}${(5 + rnd.nextInt(10)).toString()}KT",
      "temp": temp.toString(),
      "dewpoint": (temp - 3).toString(),
      "clouds": clouds,
      "visibility": "10KM",
      "visibilityMeters": 10000,
      "pressure": "Q1015",
      "category": "VFR",
    };
  }

  // ============================================================
  //  UTILS
  // ============================================================
  static List<String> _cloudLayerFromDensity(double density) {
    if (density < 0.1) return [];
    if (density < 0.3) return ["FEW030"];
    if (density < 0.5) return ["SCT040"];
    if (density < 0.8) return ["BKN050"];
    return ["OVC060"];
  }

  static String _visibilityFromSim(double meters) {
    if (meters >= 10000) return "10KM";
    return "${(meters / 1000).toStringAsFixed(1)}KM";
  }

  static int _normalizeVisibility(dynamic value) {
    if (value == null) return 9999;

    if (value is int) return value;

    final str = value.toString().toUpperCase();

    if (str.endsWith("KM")) {
      final v = double.tryParse(str.replaceAll("KM", "")) ?? 10.0;
      return (v * 1000).round();
    }

    final maybe = int.tryParse(str);
    if (maybe != null) return maybe;

    return 9999;
  }

  static String _categoryFromSim(dynamic weather) {
    final vis = weather.visibility;
    final ceiling =
        weather.cloudDensity > 0.6 ? 500 : 3000;

    if (vis > 8000 && ceiling >= 3000) return "VFR";
    if (vis > 3000 && ceiling >= 1000) return "MVFR";
    if (vis > 1600 && ceiling >= 500) return "IFR";
    return "LIFR";
  }
}
