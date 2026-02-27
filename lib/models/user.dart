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
                ? DateTime.tryParse(user['lastLogin']) ?? null
                : null,
        stats:
            user['stats'] != null
                ? UserStats.fromJson(user['stats'])
                : UserStats(totalFlights: 0, totalFlightHours: 0),
        hq: user['hq'] != null ? HqLocation.fromJson(user['hq']) : null,
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
}

class UserStats {
  final int totalFlights;
  final double totalFlightHours;

  UserStats({required this.totalFlights, required this.totalFlightHours});

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalFlights: json['totalFlights'] ?? 0,
      totalFlightHours: (json['totalFlightHours'] ?? 0).toDouble(),
    );
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
