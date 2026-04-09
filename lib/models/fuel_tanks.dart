class FuelTanks {
  final double leftMain;
  final double rightMain;
  final double center;
  final double leftAux;
  final double rightAux;

  const FuelTanks({
    required this.leftMain,
    required this.rightMain,
    required this.center,
    required this.leftAux,
    required this.rightAux,
  });

  double get total =>
      leftMain + rightMain + center + leftAux + rightAux;

  Map<String, dynamic> toJson() => {
        'leftMain': leftMain,
        'rightMain': rightMain,
        'center': center,
        'leftAux': leftAux,
        'rightAux': rightAux,
      };

  // ✅ ADD THIS
  factory FuelTanks.fromJson(Map<String, dynamic> j) {
    return FuelTanks(
      leftMain: (j['leftMain'] ?? 0).toDouble(),
      rightMain: (j['rightMain'] ?? 0).toDouble(),
      center: (j['center'] ?? 0).toDouble(),
      leftAux: (j['leftAux'] ?? 0).toDouble(),
      rightAux: (j['rightAux'] ?? 0).toDouble(),
    );
  }
}


class LiveFuelTank {
  final double current;
  final double capacity;
  final bool enabled;

  const LiveFuelTank({
    required this.current,
    required this.capacity,
    required this.enabled,
  });

  double get percent => capacity <= 0 ? 0 : (current / capacity).clamp(0, 1);

  factory LiveFuelTank.fromJson(Map<String, dynamic> j) {
    return LiveFuelTank(
      current: (j['current'] ?? 0).toDouble(),
      capacity: (j['capacity'] ?? 0).toDouble(),
      enabled: j['enabled'] == true,
    );
  }
}

class LiveFuelTanks {
  final LiveFuelTank leftMain;
  final LiveFuelTank rightMain;
  final LiveFuelTank center;
  final LiveFuelTank leftAux;
  final LiveFuelTank rightAux;

  const LiveFuelTanks({
    required this.leftMain,
    required this.rightMain,
    required this.center,
    required this.leftAux,
    required this.rightAux,
  });

  double get totalCurrent =>
      leftMain.current +
      rightMain.current +
      center.current +
      leftAux.current +
      rightAux.current;

  double get totalCapacity =>
      leftMain.capacity +
      rightMain.capacity +
      center.capacity +
      leftAux.capacity +
      rightAux.capacity;

  factory LiveFuelTanks.fromJson(Map<String, dynamic> j) {
    return LiveFuelTanks(
      leftMain: LiveFuelTank.fromJson(
        Map<String, dynamic>.from(j['leftMain'] ?? {}),
      ),
      rightMain: LiveFuelTank.fromJson(
        Map<String, dynamic>.from(j['rightMain'] ?? {}),
      ),
      center: LiveFuelTank.fromJson(
        Map<String, dynamic>.from(j['center'] ?? {}),
      ),
      leftAux: LiveFuelTank.fromJson(
        Map<String, dynamic>.from(j['leftAux'] ?? {}),
      ),
      rightAux: LiveFuelTank.fromJson(
        Map<String, dynamic>.from(j['rightAux'] ?? {}),
      ),
    );
  }
}