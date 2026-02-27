import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MetarService {
  // Cache lifespan (10 minutes)
  static const int cacheSeconds = 600;

  // NOAA modern endpoint
  static const String _noaaUrl =
      "https://aviationweather.gov/api/data/metar?format=json&ids=";

  // AVWX fallback endpoint
  static const String _avwxBase = "https://avwx.rest/api";
  static const String _avwxToken =
      "qXAk3-vIC5MxoVwZg3bXi5wD427t6mDd33wrXdz1cGM";

  // =======================================================
  // BASIC RAW VALIDATOR
  // =======================================================
  static bool _isValidRaw(String? raw) {
    if (raw == null) return false;
    final r = raw.trim();
    if (r.isEmpty) return false;
    if (r == "N/A") return false;
    if (r.contains("NIL")) return false;
    if (r.contains("////")) return false;
    return true;
  }

  // =======================================================
  // FETCH RAW METAR
  // NOAA → AVWX → null
  // =======================================================
  static Future<String?> fetchRawMetar(String icao) async {
    icao = icao.toUpperCase().trim();

    final prefs = await SharedPreferences.getInstance();
    final ck = "metar_$icao";
    final tk = "metar_time_$icao";

    // ----- CACHE CHECK -----
    final cached = prefs.getString(ck);
    final cachedTime = prefs.getInt(tk);
    if (cached != null && cachedTime != null) {
      final age =
          DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(cachedTime))
              .inSeconds;

      if (age < cacheSeconds && _isValidRaw(cached)) {
        return cached;
      }
    }

    // ----- NOAA -----
    final noaa = await _fetchFromNoaa(icao);
    if (_isValidRaw(noaa)) {
      _saveCache(prefs, ck, tk, noaa!);
      return noaa;
    }

    // ----- AVWX -----
    final avwx = await _fetchFromAvwx(icao);
    if (_isValidRaw(avwx)) {
      _saveCache(prefs, ck, tk, avwx!);
      return avwx;
    }

    return null;
  }

  static void _saveCache(
    SharedPreferences prefs,
    String key,
    String timeKey,
    String metar,
  ) {
    prefs.setString(key, metar);
    prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
  }

  // NOAA FETCHER
  static Future<String?> _fetchFromNoaa(String icao) async {
    try {
      final url = Uri.parse("$_noaaUrl$icao");
      final res = await http.get(url);

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data is List && data.isNotEmpty) {
        return data.first["raw_text"];
      }
    } catch (_) {}

    return null;
  }

  // AVWX FETCHER (inline)
  static Future<String?> _fetchFromAvwx(String icao) async {
    try {
      final url = Uri.parse("$_avwxBase/metar/$icao?format=json&onfail=cache");
      final res = await http.get(
        url,
        headers: {"Authorization": "Bearer $_avwxToken"},
      );

      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body);
      return json["raw"];
    } catch (_) {
      return null;
    }
  }

  // =======================================================
  // DECODER (safe)
  // =======================================================
  static Map<String, dynamic> decodeMetar(String metar) {
    if (!_isValidRaw(metar)) {
      return {
        "raw": metar,
        "wind": "",
        "visibility": "N/A",
        "clouds": const <String>[],
        "ceiling": null,
        "phenomena": const <String>[],
        "pressure": "",
        "temp": "N/A",
        "dewpoint": "N/A",
        "category": "UNKNOWN",
      };
    }

    final parts = metar.split(" ").where((p) => p.trim().isNotEmpty).toList();

    // WIND
    final windToken = parts.firstWhere(
      (p) =>
          RegExp(r'^\d{5}KT$').hasMatch(p) ||
          RegExp(r'^\d{5}G\d{2}KT$').hasMatch(p),
      orElse: () => "",
    );

    // VISIBILITY
    String visibility = "N/A";
    final visToken = parts.firstWhere(
      (p) => RegExp(r'^\d{4}$').hasMatch(p) || p.contains("SM"),
      orElse: () => "",
    );
    if (visToken.isNotEmpty) visibility = visToken;

    // CLOUDS
    final clouds =
        parts.where((p) {
          return p.startsWith("FEW") ||
              p.startsWith("SCT") ||
              p.startsWith("BKN") ||
              p.startsWith("OVC");
        }).toList();

    // CEILING
    int? ceiling;

    int? _extractBase(String token) {
      if (token.length < 6) return null;
      final digits = token.substring(3, 6);
      if (digits.contains("/")) return null;
      return int.tryParse(digits);
    }

    for (final c in clouds) {
      if (c.startsWith("BKN") || c.startsWith("OVC")) {
        final base = _extractBase(c);
        if (base != null) {
          final alt = base * 100;
          if (ceiling == null || alt < ceiling) ceiling = alt;
        }
      }
    }

    // PHENOMENA
    final wx =
        parts.where((p) {
          return RegExp(r'(RA|DZ|SN|TS|FG|BR|SA|HZ|VA|GR|GS)').hasMatch(p);
        }).toList();

    // TEMP/DEW
    String temp = "N/A";
    String dew = "N/A";

    final tempPart = parts.firstWhere((p) => p.contains("/"), orElse: () => "");
    if (tempPart.isNotEmpty) {
      final sp = tempPart.split("/");
      if (sp.isNotEmpty) temp = sp[0].replaceAll("M", "-");
      if (sp.length > 1) dew = sp[1].replaceAll("M", "-");
    }

    // PRESSURE
    final qnh = parts.firstWhere(
      (p) => p.startsWith("Q") || p.startsWith("A"),
      orElse: () => "",
    );

    // CATEGORY
    String category = "UNKNOWN";

    int visVal = 9999;
    if (visibility.contains("SM")) {
      visVal = 5000;
    } else {
      visVal = int.tryParse(visibility) ?? 9999;
    }

    if (ceiling != null) {
      if (visVal < 1600 || ceiling < 500)
        category = "LIFR";
      else if (visVal < 4800 || ceiling < 1000)
        category = "IFR";
      else if (visVal < 8000 || ceiling < 3000)
        category = "MVFR";
      else
        category = "VFR";
    }

    return {
      "raw": metar,
      "wind": windToken,
      "visibility": visibility,
      "clouds": clouds,
      "ceiling": ceiling,
      "phenomena": wx,
      "pressure": qnh,
      "temp": temp,
      "dewpoint": dew,
      "category": category,
    };
  }

  // =======================================================
  // BRIEFING
  // =======================================================
  static Future<Map<String, dynamic>?> getBriefing(String icao) async {
    final raw = await fetchRawMetar(icao);
    if (!_isValidRaw(raw)) {
      return {
        "icao": icao.toUpperCase(),
        "raw": "N/A",
        "wind": "",
        "temp": "N/A",
        "clouds": const <String>[],
        "visibility": "N/A",
        "category": "UNKNOWN",
        "summary": "${icao.toUpperCase()} • Weather N/A",
      };
    }

    final d = decodeMetar(raw!);

    return {
      "icao": icao.toUpperCase(),
      "raw": d["raw"],
      "wind": d["wind"],
      "temp": d["temp"],
      "clouds": d["clouds"],
      "visibility": d["visibility"],
      "category": d["category"],
      "summary":
          "${icao.toUpperCase()} • ${d["temp"]}°C • ${d["wind"]} • ${d["clouds"].isNotEmpty ? d["clouds"][0] : ""}"
              .trim(),
    };
  }

  // =======================================================
  // MAJOR AERODROMES (unchanged)
  // =======================================================
  static List<String> majorAerodromes() {
    return [
      "EGLL",
      "EGKK",
      "EGCC",
      "EGPH",
      "EHAM",
      "EHBK",
      "EDDF",
      "EDDM",
      "EDDW",
      "LFPG",
      "LFPO",
      "LFMN",
      "LEMD",
      "LEBL",
      "LEPA",
      "LIRF",
      "LIMC",
      "LIPZ",
      "LOWW",
      "LOWI",
      "LSZH",
      "LSGG",
      "EKCH",
      "ESSA",
      "EVRA",
      "EPWA",
      "EETN",
      "ULLI",
      "LGAV",
      "LGTS",
      "LGIR",
      "LGKF",
      "LGMT",
      "LGRP",
      "LGKO",
      "LGKJ",
      "LGSM",
      "LGZA",
      "LGSA",
      "LGSR",
      "LGSK",
      "LGIO",
      "LGKR",
      "LGML",
      "LGHI",
      "LGNX",
      "LGPA",
      "LGST",
      "LGPL",
      "LTFM",
      "LTBA",
      "LTAI",
      "LTAC",
      "LTBJ",
      "LTBS",
      "LCLK",
      "LCPH",
      "LCRA",
      "LGRD",
      "LYBE",
      "LBSF",
      "LROP",
      "LDZA",
      "LQSA",
      "LWSK",
      "LATI",
      "LHBP",
      "OMDB",
      "OMAA",
      "OTHH",
      "OKBK",
      "OERK",
      "OEJN",
      "OEDF",
      "OJAI",
      "OLBA",
      "HECA",
      "HEAX",
      "HSSS",
      "GMMN",
      "DAAG",
      "DTTA",
      "KJFK",
      "KLAX",
      "KSFO",
      "KSEA",
      "KATL",
      "KORD",
      "KDFW",
      "KIAD",
      "KBOS",
      "KMIA",
      "KPHX",
      "KDEN",
      "CYYZ",
      "CYVR",
      "CYUL",
      "CYYC",
      "RJTT",
      "RJAA",
      "ROAH",
      "VHHH",
      "VMMC",
      "ZBAA",
      "ZSPD",
      "ZGGG",
      "RCTP",
      "RCSS",
      "WSSS",
      "VTBS",
      "VTBD",
      "WMKK",
      "VIDP",
      "VABB",
      "YSSY",
      "YMML",
      "NZAA",
      "NZWN",
    ];
  }

  static Future<String?> getAmbientLine(String icao) async {
    icao = icao.toUpperCase().trim();

    final raw = await fetchRawMetar(icao);
    if (!_isValidRaw(raw)) return null;

    final d = decodeMetar(raw!);

    final temp = d["temp"] ?? "N/A";
    final wind = d["wind"] ?? "";
    final clouds = (d["clouds"] as List).isNotEmpty ? d["clouds"][0] : "";

    return "$icao • $temp°C • $wind • $clouds".trim();
  }
}
