class LearnedAircraft {
  final String id; // normalized aircraftId
  final String title;

  final double? emptyWeight;
  final double? mtow;
  final double? mzfw;
  final double? mlgw;

  final double? fuelCapacityGallons;

  final bool? retractable;
  final bool? floats;
  final bool? skids;
  final bool? skis;
  final bool? wheels;

  final DateTime? updatedAt;

  final String? aircraftUuid;

  LearnedAircraft({
    required this.id,
    required this.title,
    this.emptyWeight,
    this.mtow,
    this.mzfw,
    this.mlgw,
    this.fuelCapacityGallons,
    this.retractable,
    this.floats,
    this.skids,
    this.skis,
    this.wheels,
    this.updatedAt,
    this.aircraftUuid,
  });

  factory LearnedAircraft.fromJson(Map<String, dynamic> j) {
    return LearnedAircraft(
      id: j["aircraftId"],
      title: j["title"],
      emptyWeight: (j["emptyWeight"] ?? 0).toDouble(),
      mtow: (j["mtow"] ?? 0).toDouble(),
      mzfw: (j["mzfw"] ?? 0).toDouble(),
      mlgw: (j["mlgw"] ?? 0).toDouble(),
      fuelCapacityGallons: (j["fuelCapacityGallons"] ?? 0).toDouble(),
      retractable: j["retractable"],
      floats: j["floats"],
      skids: j["skids"],
      skis: j["skis"],
      wheels: j["wheels"],
      updatedAt: j["updatedAt"] != null ? DateTime.parse(j["updatedAt"]) : null,
      aircraftUuid: j['aircraftUuid'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "aircraftId": id,
      "title": title,
      "emptyWeight": emptyWeight,
      "mtow": mtow,
      "mzfw": mzfw,
      "mlgw": mlgw,
      "fuelCapacityGallons": fuelCapacityGallons,
      "retractable": retractable,
      "floats": floats,
      "skids": skids,
      "skis": skis,
      "wheels": wheels,
      if (aircraftUuid != null) 'aircraftUuid': aircraftUuid,
    };
  }
}
