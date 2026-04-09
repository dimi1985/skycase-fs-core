class JobPayload {
  final double totalWeight;
  final double cargoWeight;
  final double passengerWeight;
  final String note;
  final bool ready;

  JobPayload({
    required this.totalWeight,
    required this.cargoWeight,
    required this.passengerWeight,
    required this.note,
    required this.ready,
  });

  factory JobPayload.fromJson(Map<String, dynamic> j) {
    return JobPayload(
      totalWeight: (j['totalWeight'] ?? 0).toDouble(),
      cargoWeight: (j['cargoWeight'] ?? 0).toDouble(),
      passengerWeight: (j['passengerWeight'] ?? 0).toDouble(),
      note: j['note'] ?? '',
      ready: j['ready'] == true,
    );
  }
}