class AircraftSnapshot {
  final String tailNumber;
  final String aircraftType; // ✈️ new
  final double fuelGallons;
  final Map<String, dynamic> fuelTanks;
  final List<PayloadStation> payloadStations;
  final DateTime timestamp;

  AircraftSnapshot({
    required this.tailNumber,
    required this.aircraftType,
    required this.fuelGallons,
    required this.fuelTanks,
    required this.payloadStations,
    required this.timestamp,
  });

  /// ✅ Factory for parsing from API/DB
  factory AircraftSnapshot.fromJson(Map<String, dynamic> json) {
    // Handle MongoDB `$date` object or plain ISO string
    String? tsString;
    final rawTimestamp = json['timestamp'];
    if (rawTimestamp is String) {
      tsString = rawTimestamp;
    } else if (rawTimestamp is Map && rawTimestamp.containsKey(r'$date')) {
      tsString = rawTimestamp[r'$date'];
    }

    return AircraftSnapshot(
      tailNumber: json['tailNumber'] ?? 'Unknown',
      aircraftType: json['aircraftType'] ?? 'Unknown', // fallback
      fuelGallons: (json['fuelGallons'] as num?)?.toDouble() ?? 0.0,
      fuelTanks: Map<String, dynamic>.from(json['fuelTanks'] ?? {}),
      payloadStations: (json['payloadStations'] as List? ?? [])
          .map((s) => PayloadStation.fromJson(s))
          .toList(),
      timestamp: tsString != null ? DateTime.parse(tsString) : DateTime.now(),
    );
  }


  Map<String, dynamic> toJson({required String userId}) {
    return {
      'userId': userId,
      'tailNumber': tailNumber,
      'aircraftType': aircraftType,
      'fuelGallons': fuelGallons,
      'fuelTanks': fuelTanks,
      'payloadStations': payloadStations.map((s) => s.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class PayloadStation {
  final String name;
  final double weight;

  PayloadStation({required this.name, required this.weight});

  factory PayloadStation.fromJson(Map<String, dynamic> json) {
    return PayloadStation(
      name: json['name'] ?? 'Unknown',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight': weight,
    };
  }
}
