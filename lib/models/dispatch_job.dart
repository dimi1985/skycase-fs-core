class DispatchJob {
  final String id;
  final String title;
  final String type; // cargo | pax | fuel | ferry | priority
  final String fromIcao;
  final String toIcao;
  final double distanceNm;

  // Payload
  final int payloadLbs;
  final int paxCount;

  // 🔥 FUEL (SEPARATED — IMPORTANT)
  final int requiredFuelGallons;   // fuel needed to fly (cargo/pax/ferry)
  final int transferFuelGallons;   // fuel being delivered (fuel jobs only)

  final bool isPriority;
  final int reward;
  final String status;
  final String? userId;

  const DispatchJob({
    required this.id,
    required this.title,
    required this.type,
    required this.fromIcao,
    required this.toIcao,
    required this.distanceNm,
    required this.payloadLbs,
    required this.paxCount,
    required this.requiredFuelGallons,
    required this.transferFuelGallons,
    required this.isPriority,
    required this.reward,
    required this.status,
    this.userId,
  });

  // --------------------------------------------------
  // FROM JSON
  // --------------------------------------------------
  factory DispatchJob.fromJson(Map<String, dynamic> json) {
    return DispatchJob(
      id: json["_id"],
      title: json["title"],
      type: json["type"],
      fromIcao: json["fromIcao"],
      toIcao: json["toIcao"],
      distanceNm: (json["distanceNm"] as num).toDouble(),

      payloadLbs: json["payloadLbs"] ?? 0,
      paxCount: json["paxCount"] ?? 0,

      requiredFuelGallons: json["requiredFuelGallons"] ?? 0,
      transferFuelGallons: json["transferFuelGallons"] ?? 0,

      isPriority: json["isPriority"] ?? false,
      reward: json["reward"],
      status: json["status"],
      userId: json["userId"],
    );
  }

  // --------------------------------------------------
  // TO JSON
  // --------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "title": title,
      "type": type,
      "fromIcao": fromIcao,
      "toIcao": toIcao,
      "distanceNm": distanceNm,

      "payloadLbs": payloadLbs,
      "paxCount": paxCount,

      "requiredFuelGallons": requiredFuelGallons,
      "transferFuelGallons": transferFuelGallons,

      "isPriority": isPriority,
      "reward": reward,
      "status": status,
      "userId": userId,
    };
  }

  // --------------------------------------------------
  // COPY WITH
  // --------------------------------------------------
  DispatchJob copyWith({
    String? id,
    String? title,
    String? type,
    String? fromIcao,
    String? toIcao,
    double? distanceNm,
    int? payloadLbs,
    int? paxCount,
    int? requiredFuelGallons,
    int? transferFuelGallons,
    bool? isPriority,
    int? reward,
    String? status,
    String? userId,
  }) {
    return DispatchJob(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      fromIcao: fromIcao ?? this.fromIcao,
      toIcao: toIcao ?? this.toIcao,
      distanceNm: distanceNm ?? this.distanceNm,
      payloadLbs: payloadLbs ?? this.payloadLbs,
      paxCount: paxCount ?? this.paxCount,
      requiredFuelGallons:
          requiredFuelGallons ?? this.requiredFuelGallons,
      transferFuelGallons:
          transferFuelGallons ?? this.transferFuelGallons,
      isPriority: isPriority ?? this.isPriority,
      reward: reward ?? this.reward,
      status: status ?? this.status,
      userId: userId ?? this.userId,
    );
  }

  // --------------------------------------------------
  // CONVENIENCE GETTERS (UI GOLD)
  // --------------------------------------------------
  bool get needsFuel => requiredFuelGallons > 0;
  bool get isFuelJob => type == "fuel" && transferFuelGallons > 0;
}
