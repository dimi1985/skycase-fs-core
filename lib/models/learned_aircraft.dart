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
  final int totalMinutes;

  const LearnedAircraft({
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
    this.totalMinutes = 0,
  });

  factory LearnedAircraft.fromJson(Map<String, dynamic> json) {
    return LearnedAircraft(
      id: _readString(json["aircraftId"]),
      title: _readString(json["title"]),
      emptyWeight: _readPositiveDouble(json["emptyWeight"]),
      mtow: _readPositiveDouble(json["mtow"]),
      mzfw: _readPositiveDouble(json["mzfw"]),
      mlgw: _readPositiveDouble(json["mlgw"]),
      fuelCapacityGallons: _readPositiveDouble(json["fuelCapacityGallons"]),
      retractable: _readBool(json["retractable"]),
      floats: _readBool(json["floats"]),
      skids: _readBool(json["skids"]),
      skis: _readBool(json["skis"]),
      wheels: _readBool(json["wheels"]),
      updatedAt: _readDateTime(json["updatedAt"]),
      aircraftUuid: _readNullableString(json["aircraftUuid"]),
      totalMinutes: _readInt(json["totalMinutes"]) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "aircraftId": id,
      "title": title,
      if (emptyWeight != null) "emptyWeight": emptyWeight,
      if (mtow != null) "mtow": mtow,
      if (mzfw != null) "mzfw": mzfw,
      if (mlgw != null) "mlgw": mlgw,
      if (fuelCapacityGallons != null)
        "fuelCapacityGallons": fuelCapacityGallons,
      if (retractable != null) "retractable": retractable,
      if (floats != null) "floats": floats,
      if (skids != null) "skids": skids,
      if (skis != null) "skis": skis,
      if (wheels != null) "wheels": wheels,
      if (updatedAt != null) "updatedAt": updatedAt!.toIso8601String(),
      if (aircraftUuid != null) "aircraftUuid": aircraftUuid,
      "totalMinutes": totalMinutes,
    };
  }

  LearnedAircraft copyWith({
    String? id,
    String? title,
    double? emptyWeight,
    double? mtow,
    double? mzfw,
    double? mlgw,
    double? fuelCapacityGallons,
    bool? retractable,
    bool? floats,
    bool? skids,
    bool? skis,
    bool? wheels,
    DateTime? updatedAt,
    String? aircraftUuid,
    int? totalMinutes,
  }) {
    return LearnedAircraft(
      id: id ?? this.id,
      title: title ?? this.title,
      emptyWeight: emptyWeight ?? this.emptyWeight,
      mtow: mtow ?? this.mtow,
      mzfw: mzfw ?? this.mzfw,
      mlgw: mlgw ?? this.mlgw,
      fuelCapacityGallons: fuelCapacityGallons ?? this.fuelCapacityGallons,
      retractable: retractable ?? this.retractable,
      floats: floats ?? this.floats,
      skids: skids ?? this.skids,
      skis: skis ?? this.skis,
      wheels: wheels ?? this.wheels,
      updatedAt: updatedAt ?? this.updatedAt,
      aircraftUuid: aircraftUuid ?? this.aircraftUuid,
      totalMinutes: totalMinutes ?? this.totalMinutes,
    );
  }

  // ─────────────────────────────────────────────
  // WEIGHT / LOAD HELPERS
  // ─────────────────────────────────────────────

  /// Broad "useful load" estimate.
  /// MTOW - empty weight
  double? get usefulLoadLbs {
    if (mtow != null && emptyWeight != null) {
      final value = mtow! - emptyWeight!;
      return value > 0 ? value : null;
    }
    return null;
  }

  /// Better payload estimate when MZFW exists.
  /// For many aircraft this is more appropriate for dispatch cargo logic.
  /// Falls back to useful load if MZFW is unavailable.
  double? get payloadCapacityLbs {
    if (mzfw != null && emptyWeight != null) {
      final value = mzfw! - emptyWeight!;
      if (value > 0) return value;
    }
    return usefulLoadLbs;
  }

  /// Rounded payload capacity, handy for UI/fit checks.
  int? get payloadCapacityLbsRounded {
    final value = payloadCapacityLbs;
    return value != null ? value.round() : null;
  }

  int? get usefulLoadLbsRounded {
    final value = usefulLoadLbs;
    return value != null ? value.round() : null;
  }

  bool get hasWeightData {
    return emptyWeight != null ||
        mtow != null ||
        mzfw != null ||
        mlgw != null;
  }

  // ─────────────────────────────────────────────
  // AIRFRAME / ROLE HELPERS
  // ─────────────────────────────────────────────

  bool get isHelicopter => skids == true;

  bool get isFloatplane => floats == true && wheels != true;

  bool get isAmphibious => floats == true && wheels == true;

  bool get isLandplane => wheels == true && floats != true && skids != true;

  bool get isSkiAircraft => skis == true;

  bool get isRetractableGear => retractable == true;

  String get aircraftTypeLabel {
    if (isHelicopter) return "helicopter";
    if (isAmphibious) return "amphibious";
    if (isFloatplane) return "floatplane";
    if (isSkiAircraft) return "ski";
    if (isLandplane) return "airplane";
    return "airplane";
  }

  // ─────────────────────────────────────────────
  // DISPATCH HELPERS
  // ─────────────────────────────────────────────

  /// Best-effort type value to send to backend dispatch generator.
  String get dispatchAircraftType {
    return isHelicopter ? "helicopter" : "airplane";
  }

  /// Returns true if the aircraft can likely carry the provided payload weight.
  /// This is a dispatch approximation, not a full W&B solver.
  bool canCarryPayloadLbs(num lbs) {
    final capacity = payloadCapacityLbs;
    if (capacity == null) return true;
    return lbs <= capacity;
  }

  // ─────────────────────────────────────────────
  // PARSERS
  // ─────────────────────────────────────────────

  static String _readString(dynamic value) {
    final text = value?.toString().trim() ?? "";
    return text;
  }

  static String? _readNullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static double? _readPositiveDouble(dynamic value) {
    final parsed = _readDouble(value);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static bool? _readBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    final raw = value.toString().trim().toLowerCase();

    if (raw == "true" || raw == "1" || raw == "yes") return true;
    if (raw == "false" || raw == "0" || raw == "no") return false;

    return null;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}