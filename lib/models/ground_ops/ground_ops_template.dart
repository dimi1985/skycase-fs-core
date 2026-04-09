import 'dart:ui';

import 'package:flutter/material.dart';

enum AircraftPartType {
  fuselage,
  wingLeft,
  wingRight,
  flapLeft,
  flapRight,
  aileronLeft,
  aileronRight,
  elevatorLeft,
  elevatorRight,
  rudder,
  engineSingle,
  engineLeft,
  engineRight,
  engineCenter,
  propeller,
  rotorMain,
  noseGear,
  mainGearLeft,
  mainGearRight,
  mainGearCenter,
}

enum DoorType {
  mainEntry,
  service,
  cargo,
  baggage,
  emergencyExit,
  overwingExit,
  cockpitAccess,
  custom,
}

enum LightType {
  beacon,
  navLeft,
  navRight,
  strobeLeft,
  strobeRight,
  landing,
  taxi,
  logo,
  cabin,
  generic,
}

enum DoorAnimationStyle {
  swingOut,
  slideUp,
  slideSide,
  foldOut,
}

enum ServicePointType {
  fuel,
  gpu,
  catering,
  baggage,
  lavatory,
  water,
  pushback,
  airStart,
  custom,
}

@immutable
class NormalizedPoint {
  final double x;
  final double y;

  const NormalizedPoint(this.x, this.y);

  Offset toOffset() => Offset(x, y);

  NormalizedPoint copyWith({double? x, double? y}) {
    return NormalizedPoint(x ?? this.x, y ?? this.y);
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory NormalizedPoint.fromJson(Map<String, dynamic> json) {
    return NormalizedPoint(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }
}

@immutable
class AircraftPolygonPart {
  final String id;
  final String name;
  final AircraftPartType type;
  final List<NormalizedPoint> points;
  final String? systemKey;
  final bool trackCondition;
  final Color? colorHint;

  const AircraftPolygonPart({
    required this.id,
    required this.name,
    required this.type,
    required this.points,
    this.systemKey,
    this.trackCondition = false,
    this.colorHint,
  });

  bool get isValidPolygon => points.length >= 3;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'points': points.map((e) => e.toJson()).toList(),
        'systemKey': systemKey,
        'trackCondition': trackCondition,
        'colorHint': colorHint?.value,
      };

  factory AircraftPolygonPart.fromJson(Map<String, dynamic> json) {
    return AircraftPolygonPart(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AircraftPartType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AircraftPartType.fuselage,
      ),
      points: ((json['points'] as List?) ?? const [])
          .map((e) => NormalizedPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      systemKey: json['systemKey'] as String?,
      trackCondition: json['trackCondition'] == true,
      colorHint: json['colorHint'] == null ? null : Color(json['colorHint'] as int),
    );
  }

  AircraftPolygonPart copyWith({
    String? id,
    String? name,
    AircraftPartType? type,
    List<NormalizedPoint>? points,
    String? systemKey,
    bool? trackCondition,
    Color? colorHint,
  }) {
    return AircraftPolygonPart(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      points: points ?? this.points,
      systemKey: systemKey ?? this.systemKey,
      trackCondition: trackCondition ?? this.trackCondition,
      colorHint: colorHint ?? this.colorHint,
    );
  }
}

@immutable
class GroundDoor {
  final String id;
  final String name;
  final DoorType type;
  final List<NormalizedPoint> points;
  final String? code;
  final bool enabled;
  final DoorAnimationStyle animationStyle;

  const GroundDoor({
    required this.id,
    required this.name,
    required this.type,
    required this.points,
    this.code,
    this.enabled = true,
    this.animationStyle = DoorAnimationStyle.swingOut,
  });

  bool get isValidPolygon => points.length >= 3;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'points': points.map((e) => e.toJson()).toList(),
        'code': code,
        'enabled': enabled,
        'animationStyle': animationStyle.name,
      };

  factory GroundDoor.fromJson(Map<String, dynamic> json) {
    return GroundDoor(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DoorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DoorType.custom,
      ),
      points: ((json['points'] as List?) ?? const [])
          .map((e) => NormalizedPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      code: json['code'] as String?,
      enabled: json['enabled'] != false,
      animationStyle: DoorAnimationStyle.values.firstWhere(
        (e) => e.name == json['animationStyle'],
        orElse: () => DoorAnimationStyle.swingOut,
      ),
    );
  }

  GroundDoor copyWith({
    String? id,
    String? name,
    DoorType? type,
    List<NormalizedPoint>? points,
    String? code,
    bool? enabled,
    DoorAnimationStyle? animationStyle,
  }) {
    return GroundDoor(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      points: points ?? this.points,
      code: code ?? this.code,
      enabled: enabled ?? this.enabled,
      animationStyle: animationStyle ?? this.animationStyle,
    );
  }
}

@immutable
class GroundLight {
  final String id;
  final String name;
  final LightType type;
  final NormalizedPoint position;
  final Color color;
  final bool enabled;
  final double intensity;

  const GroundLight({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.color,
    this.enabled = true,
    this.intensity = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'position': position.toJson(),
        'color': color.value,
        'enabled': enabled,
        'intensity': intensity,
      };

  factory GroundLight.fromJson(Map<String, dynamic> json) {
    return GroundLight(
      id: json['id'] as String,
      name: json['name'] as String,
      type: LightType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LightType.generic,
      ),
      position: NormalizedPoint.fromJson(Map<String, dynamic>.from(json['position'] as Map)),
      color: Color((json['color'] as num).toInt()),
      enabled: json['enabled'] != false,
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1.0,
    );
  }

  GroundLight copyWith({
    String? id,
    String? name,
    LightType? type,
    NormalizedPoint? position,
    Color? color,
    bool? enabled,
    double? intensity,
  }) {
    return GroundLight(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      position: position ?? this.position,
      color: color ?? this.color,
      enabled: enabled ?? this.enabled,
      intensity: intensity ?? this.intensity,
    );
  }
}

@immutable
class GroundServicePoint {
  final String id;
  final String name;
  final ServicePointType type;
  final NormalizedPoint position;
  final String? notes;
  final bool enabled;

  const GroundServicePoint({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    this.notes,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'position': position.toJson(),
        'notes': notes,
        'enabled': enabled,
      };

  factory GroundServicePoint.fromJson(Map<String, dynamic> json) {
    return GroundServicePoint(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ServicePointType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ServicePointType.custom,
      ),
      position: NormalizedPoint.fromJson(Map<String, dynamic>.from(json['position'] as Map)),
      notes: json['notes'] as String?,
      enabled: json['enabled'] != false,
    );
  }

  GroundServicePoint copyWith({
    String? id,
    String? name,
    ServicePointType? type,
    NormalizedPoint? position,
    String? notes,
    bool? enabled,
  }) {
    return GroundServicePoint(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      position: position ?? this.position,
      notes: notes ?? this.notes,
      enabled: enabled ?? this.enabled,
    );
  }
}

@immutable
class GroundOpsTemplate {
  final String id;
  final String name;
  final String? aircraftCode;
  final String? manufacturer;
  final String? variant;
  final List<AircraftPolygonPart> parts;
  final List<GroundDoor> doors;
  final List<GroundLight> lights;
  final List<GroundServicePoint> servicePoints;
  final NormalizedPoint? propCenter;
  final double propRadius;

  const GroundOpsTemplate({
    required this.id,
    required this.name,
    this.aircraftCode,
    this.manufacturer,
    this.variant,
    required this.parts,
    required this.doors,
    required this.lights,
    required this.servicePoints,
    this.propCenter,
    this.propRadius = 0.04,
  });

  factory GroundOpsTemplate.empty({
    String id = 'empty',
    String name = 'Empty Template',
  }) {
    return GroundOpsTemplate(
      id: id,
      name: name,
      parts: const [],
      doors: const [],
      lights: const [],
      servicePoints: const [],
      propCenter: null,
      propRadius: 0.04,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'aircraftCode': aircraftCode,
        'manufacturer': manufacturer,
        'variant': variant,
        'parts': parts.map((e) => e.toJson()).toList(),
        'doors': doors.map((e) => e.toJson()).toList(),
        'lights': lights.map((e) => e.toJson()).toList(),
        'servicePoints': servicePoints.map((e) => e.toJson()).toList(),
        'propCenter': propCenter?.toJson(),
        'propRadius': propRadius,
      };

  factory GroundOpsTemplate.fromJson(Map<String, dynamic> json) {
    return GroundOpsTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      aircraftCode: json['aircraftCode'] as String?,
      manufacturer: json['manufacturer'] as String?,
      variant: json['variant'] as String?,
      parts: ((json['parts'] as List?) ?? const [])
          .map((e) => AircraftPolygonPart.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      doors: ((json['doors'] as List?) ?? const [])
          .map((e) => GroundDoor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      lights: ((json['lights'] as List?) ?? const [])
          .map((e) => GroundLight.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      servicePoints: ((json['servicePoints'] as List?) ?? const [])
          .map((e) => GroundServicePoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      propCenter: json['propCenter'] == null
          ? null
          : NormalizedPoint.fromJson(Map<String, dynamic>.from(json['propCenter'] as Map)),
      propRadius: (json['propRadius'] as num?)?.toDouble() ?? 0.04,
    );
  }

  GroundOpsTemplate copyWith({
    String? id,
    String? name,
    String? aircraftCode,
    String? manufacturer,
    String? variant,
    List<AircraftPolygonPart>? parts,
    List<GroundDoor>? doors,
    List<GroundLight>? lights,
    List<GroundServicePoint>? servicePoints,
    NormalizedPoint? propCenter,
    double? propRadius,
    bool clearPropCenter = false,
  }) {
    return GroundOpsTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      aircraftCode: aircraftCode ?? this.aircraftCode,
      manufacturer: manufacturer ?? this.manufacturer,
      variant: variant ?? this.variant,
      parts: parts ?? this.parts,
      doors: doors ?? this.doors,
      lights: lights ?? this.lights,
      servicePoints: servicePoints ?? this.servicePoints,
      propCenter: clearPropCenter ? null : (propCenter ?? this.propCenter),
      propRadius: propRadius ?? this.propRadius,
    );
  }
}
