typedef J = Map<String, dynamic>;

bool b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v == 1;
  return false;
}

class GsxStatus {
  final bool installed;
  final bool running;
  final bool availableInSim;

  final bool boarding;
  final bool deboarding;
  final bool refueling;
  final bool pushback;

  final int boardingState;
  final int deboardingState;
  final int refuelingState;

  final String rawState;
  final bool undergroundRefueling;

  GsxStatus({
    required this.installed,
    required this.running,
    required this.availableInSim,
    required this.boarding,
    required this.deboarding,
    required this.refueling,
    required this.pushback,
    required this.boardingState,
    required this.deboardingState,
    required this.refuelingState,
    required this.rawState,
    required this.undergroundRefueling,
  });

  factory GsxStatus.fromJson(J j) {
    return GsxStatus(
      installed: b(j['installed']),
      running: b(j['running']),
      availableInSim: b(j['availableInSim']),
      boarding: b(j['boarding']),
      deboarding: b(j['deboarding']),
      refueling: b(j['refueling']),
      pushback: b(j['pushback']),
      boardingState: j['boardingState'] ?? 0,
      deboardingState: j['deboardingState'] ?? 0,
      refuelingState: j['refuelingState'] ?? 0,
      rawState: j['rawState'] ?? '',
      undergroundRefueling: b(j['undergroundRefueling']),
    );
  }
}