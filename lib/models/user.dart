class User {
  final String id;
  final String username;
  final String email;
  final String token;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final UserStats stats;
  final HqLocation? hq;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.token,
    required this.createdAt,
    required this.lastLogin,
    required this.stats,
    this.hq,
  });

  factory User.fromJson(Map<String, dynamic>? json) {
    try {
      if (json == null || json['user'] == null || json['token'] == null) {
        print('[User.fromJson] ❌ Invalid structure: $json');
        throw Exception('Invalid user profile response');
      }

      final user = json['user'];

      return User(
        id: user['_id'] ?? '',
        username: user['username'] ?? '',
        email: user['email'] ?? '',
        token: json['token'] ?? '',
        createdAt: DateTime.tryParse(user['createdAt'] ?? '') ?? DateTime.now(),
        lastLogin:
            user['lastLogin'] != null
                ? DateTime.tryParse(user['lastLogin'])
                : null,
        stats:
            user['stats'] != null
                ? UserStats.fromJson(user['stats'])
                : UserStats.empty(),
        hq: _parseHq(user['hq']),
      );
    } catch (e, stack) {
      print('[User.fromJson] ❌ Exception while parsing: $e');
      print('[User.fromJson] Stack:\n$stack');
      throw Exception('Failed to parse user data');
    }
  }

  User copyWith({String? token}) {
    return User(
      id: id,
      username: username,
      email: email,
      token: token ?? this.token,
      createdAt: createdAt,
      lastLogin: lastLogin,
      stats: stats,
      hq: hq,
    );
  }

  static HqLocation? _parseHq(dynamic value) {
    if (value is! Map) return null;

    final icao = value['icao']?.toString().trim();
    final lat = value['lat'];
    final lon = value['lon'];

    if (icao == null || icao.isEmpty || lat == null || lon == null) {
      return null;
    }

    return HqLocation.fromJson(Map<String, dynamic>.from(value));
  }
}

class UserStats {
  final int totalFlights;
  final double totalFlightHours;

  final List<String> departureAirports;
  final List<String> arrivalAirports;

  final Map<String, int> departureCounts;
  final Map<String, int> arrivalCounts;

  final String? favoriteDepartureAirport;
  final String? favoriteArrivalAirport;

  final int jobsAccepted;
  final int jobsCompleted;
  final int jobsCancelled;

  final Map<String, int> aircraftUsage;
  final Map<String, double> aircraftHours;
  final String? favoriteAircraft;

  final List<String> visitedPois;
  final Map<String, int> poiVisitCounts;
  final Map<String, double> poiTotalLoiterMinutes;
  final String? favoritePoi;

  UserStats({
    required this.totalFlights,
    required this.totalFlightHours,
    required this.departureAirports,
    required this.arrivalAirports,
    required this.departureCounts,
    required this.arrivalCounts,
    required this.favoriteDepartureAirport,
    required this.favoriteArrivalAirport,
    required this.jobsAccepted,
    required this.jobsCompleted,
    required this.jobsCancelled,
    required this.aircraftUsage,
    required this.aircraftHours,
    required this.favoriteAircraft,
    required this.visitedPois,
    required this.poiVisitCounts,
    required this.poiTotalLoiterMinutes,
    required this.favoritePoi,
  });

  factory UserStats.empty() {
    return UserStats(
      totalFlights: 0,
      totalFlightHours: 0,
      departureAirports: const [],
      arrivalAirports: const [],
      departureCounts: const {},
      arrivalCounts: const {},
      favoriteDepartureAirport: null,
      favoriteArrivalAirport: null,
      jobsAccepted: 0,
      jobsCompleted: 0,
      jobsCancelled: 0,
      aircraftUsage: const {},
      aircraftHours: const {},
      favoriteAircraft: null,
      visitedPois: const [],
      poiVisitCounts: const {},
      poiTotalLoiterMinutes: const {},
      favoritePoi: null,
    );
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalFlights: _asInt(json['totalFlights']),
      totalFlightHours: _asDouble(json['totalFlightHours']),
      departureAirports: _asStringList(json['departureAirports']),
      arrivalAirports: _asStringList(json['arrivalAirports']),
      departureCounts: _asIntMap(json['departureCounts']),
      arrivalCounts: _asIntMap(json['arrivalCounts']),
      favoriteDepartureAirport: _asNullableString(
        json['favoriteDepartureAirport'],
      ),
      favoriteArrivalAirport: _asNullableString(json['favoriteArrivalAirport']),
      jobsAccepted: _asInt(json['jobsAccepted']),
      jobsCompleted: _asInt(json['jobsCompleted']),
      jobsCancelled: _asInt(json['jobsCancelled']),
      aircraftUsage: _asIntMap(json['aircraftUsage']),
      aircraftHours: _asDoubleMap(json['aircraftHours']),
      favoriteAircraft: _asNullableString(json['favoriteAircraft']),
      visitedPois: _asStringList(json['visitedPois']),
      poiVisitCounts: _asIntMap(json['poiVisitCounts']),
      poiTotalLoiterMinutes: _asDoubleMap(json['poiTotalLoiterMinutes']),
      favoritePoi: _asNullableString(json['favoritePoi']),
    );
  }

  int get uniqueDepartureAirportCount => departureAirports.length;
  int get uniqueArrivalAirportCount => arrivalAirports.length;
  int get discoveredPoiCount => visitedPois.length;
  double get totalPoiLoiterMinutes =>
      poiTotalLoiterMinutes.values.fold(0.0, (a, b) => a + b);

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Map<String, int> _asIntMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _asInt(val)));
    }
    return {};
  }

  static Map<String, double> _asDoubleMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _asDouble(val)));
    }
    return {};
  }
}

class HqLocation {
  final String icao;
  final double lat;
  final double lon;

  HqLocation({required this.icao, required this.lat, required this.lon});

  factory HqLocation.fromJson(Map<String, dynamic> json) {
    return HqLocation(
      icao: json['icao'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'icao': icao, 'lat': lat, 'lon': lon};
  }
}
