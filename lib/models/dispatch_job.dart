class DispatchJob {
  final String id;
  final String title;
  final String type; // cargo | pax | fuel | priority | ferry
  final String fromIcao;
  final String toIcao;
  final double distanceNm;

  // Payload
  final int payloadLbs;
  final int paxCount;

  // Fuel
  final int requiredFuelGallons; // fuel required to fly the mission
  final int transferFuelGallons; // fuel delivered for tanker/fuel missions

  final bool isPriority;
  final int reward;

  // Backend state
  final String status; // open | accepted | completed | cancelled
  final String phase; // open | accepted | preparing | loading | ready | enroute | arrived | unloading
  final DateTime? phaseUpdatedAt;

  final String? userId;

  static const double fuelLbsPerGallon = 6.7;

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
    required this.phase,
    this.phaseUpdatedAt,
    this.userId,
  });

  factory DispatchJob.fromJson(Map<String, dynamic> json) {
    return DispatchJob(
      id: _readString(json['_id']),
      title: _readString(json['title']),
      type: _readString(json['type']).toLowerCase(),
      fromIcao: _readString(json['fromIcao']).toUpperCase(),
      toIcao: _readString(json['toIcao']).toUpperCase(),
      distanceNm: _readNonNegativeDouble(json['distanceNm']) ?? 0.0,

      payloadLbs: _readNonNegativeInt(json['payloadLbs']) ?? 0,
      paxCount: _readNonNegativeInt(json['paxCount']) ?? 0,

      requiredFuelGallons:
          _readNonNegativeInt(json['requiredFuelGallons']) ?? 0,
      transferFuelGallons:
          _readNonNegativeInt(json['transferFuelGallons']) ?? 0,

      isPriority: _readBool(json['isPriority']) ?? false,
      reward: _readNonNegativeInt(json['reward']) ?? 0,

      status: _readString(json['status'], fallback: 'open').toLowerCase(),
      phase: _readString(json['phase'], fallback: 'open').toLowerCase(),
      phaseUpdatedAt: _readDateTime(json['phaseUpdatedAt']),

      userId: _readNullableString(json['userId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'type': type,
      'fromIcao': fromIcao,
      'toIcao': toIcao,
      'distanceNm': distanceNm,
      'payloadLbs': payloadLbs,
      'paxCount': paxCount,
      'requiredFuelGallons': requiredFuelGallons,
      'transferFuelGallons': transferFuelGallons,
      'isPriority': isPriority,
      'reward': reward,
      'status': status,
      'phase': phase,
      if (phaseUpdatedAt != null)
        'phaseUpdatedAt': phaseUpdatedAt!.toIso8601String(),
      if (userId != null) 'userId': userId,
    };
  }

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
    String? phase,
    DateTime? phaseUpdatedAt,
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
      phase: phase ?? this.phase,
      phaseUpdatedAt: phaseUpdatedAt ?? this.phaseUpdatedAt,
      userId: userId ?? this.userId,
    );
  }

  // ─────────────────────────────────────────────
  // TYPE HELPERS
  // ─────────────────────────────────────────────

  bool get isCargoJob => type == 'cargo';
  bool get isPaxJob => type == 'pax';
  bool get isFuelJob => type == 'fuel';
  bool get isPriorityJob => type == 'priority' || isPriority;
  bool get isFerryJob => type == 'ferry';

  bool get isKnownType {
    return isCargoJob ||
        isPaxJob ||
        isFuelJob ||
        isPriorityJob ||
        isFerryJob;
  }

  String get typeLabel {
    switch (type) {
      case 'cargo':
        return 'Cargo';
      case 'pax':
        return 'Passengers';
      case 'fuel':
        return 'Fuel';
      case 'priority':
        return 'Priority';
      case 'ferry':
        return 'Ferry';
      default:
        return type.isEmpty ? 'Unknown' : type.toUpperCase();
    }
  }

  // ─────────────────────────────────────────────
  // STATE HELPERS
  // ─────────────────────────────────────────────

  bool get isOpen => status == 'open';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get isPendingApproval => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  bool get isPreparing => phase == 'preparing';
  bool get isLoading => phase == 'loading';
  bool get isReady => phase == 'ready';
  bool get isEnroute => phase == 'enroute';
  bool get isArrived => phase == 'arrived';
  bool get isUnloading => phase == 'unloading';

  bool get isActiveLifecycleState {
    return isAccepted ||
        isPendingApproval ||
        isApproved ||
        isPreparing ||
        isLoading ||
        isReady ||
        isEnroute ||
        isArrived ||
        isUnloading;
  }

  // ─────────────────────────────────────────────
  // PAYLOAD / DISPATCH HELPERS
  // ─────────────────────────────────────────────

  bool get needsFuel => requiredFuelGallons > 0;

  /// Fuel carried as cargo weight for tanker/fuel delivery jobs.
  int get transferFuelWeightLbs {
    return (transferFuelGallons * fuelLbsPerGallon).round();
  }

  /// Main payload value used for aircraft-fit checks.
  /// Fuel jobs use transfer fuel converted to weight.
  /// All other jobs use payloadLbs directly.
  int get effectivePayloadLbs {
    if (isFuelJob) {
      return transferFuelWeightLbs;
    }
    return payloadLbs;
  }

  bool get hasPayload => effectivePayloadLbs > 0;
  bool get hasPassengers => paxCount > 0;
  bool get hasTransferFuel => transferFuelGallons > 0;

  /// Nice compact summary for cards/UI.
  String get payloadSummary {
    if (isFuelJob && transferFuelGallons > 0) {
      return '$transferFuelGallons gal (${transferFuelWeightLbs} lbs)';
    }
    if (isPaxJob && paxCount > 0 && payloadLbs > 0) {
      return '$paxCount pax • $payloadLbs lbs';
    }
    if (isPaxJob && paxCount > 0) {
      return '$paxCount pax';
    }
    if (effectivePayloadLbs > 0) {
      return '$effectivePayloadLbs lbs';
    }
    return 'No payload';
  }

  // ─────────────────────────────────────────────
  // ROUTE / DISPLAY HELPERS
  // ─────────────────────────────────────────────

  String get routeLabel => '$fromIcao → $toIcao';

  String get rewardLabel => '$reward cr';

  String get distanceLabel {
    return '${distanceNm.toStringAsFixed(0)} NM';
  }

  // ─────────────────────────────────────────────
  // PARSERS
  // ─────────────────────────────────────────────

  static String _readString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
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

  static int? _readNonNegativeInt(dynamic value) {
    final parsed = _readInt(value);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static double? _readNonNegativeDouble(dynamic value) {
    final parsed = _readDouble(value);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  static bool? _readBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    final raw = value.toString().trim().toLowerCase();

    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;

    return null;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}