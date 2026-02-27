import 'turbulence_event.dart';
import 'flight_trail_point.dart';
import 'airport_location.dart';

class FlightLog {
  final String userId;
  final String aircraft;

  final DateTime startTime;
  final DateTime endTime;
  final int duration;

  final AirportLocation? startLocation;
  final AirportLocation? endLocation;

  final double distanceFlown;
  final int avgAirspeed;
  final int maxAltitude;
  final int cruiseTime;

  final List<TurbulenceEvent> turbulence;
  final Map<String, dynamic> events;
  final List<FlightTrailPoint> trail;

  final String type; // free | job | mission
  final String? jobId;

  FlightLog({
    required this.userId,
    required this.aircraft,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.distanceFlown,
    required this.avgAirspeed,
    required this.maxAltitude,
    required this.cruiseTime,
    required this.turbulence,
    required this.events,
    required this.trail,
    this.type = 'free',
    this.jobId,
  });

  // =========================
  // FROM JSON (Mongo → Flutter)
  // =========================
  factory FlightLog.fromJson(Map<String, dynamic> json) {
    return FlightLog(
      userId: json['userId'] ?? 'Unknown',
      aircraft: json['aircraft'] ?? 'Unknown',

      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      duration: (json['duration'] as num?)?.toInt() ?? 0,

      startLocation:
          json['startLocation'] != null
              ? AirportLocation.fromJson(json['startLocation'])
              : null,

      endLocation:
          json['endLocation'] != null
              ? AirportLocation.fromJson(json['endLocation'])
              : null,

      distanceFlown: (json['distanceFlown'] as num?)?.toDouble() ?? 0.0,
      avgAirspeed: (json['avgAirspeed'] as num?)?.toInt() ?? 0,
      maxAltitude: (json['maxAltitude'] as num?)?.toInt() ?? 0,
      cruiseTime: (json['cruiseTime'] as num?)?.toInt() ?? 0,

      turbulence:
          (json['turbulence'] as List<dynamic>? ?? [])
              .map((e) => TurbulenceEvent.fromJson(e))
              .toList(),

      events: Map<String, dynamic>.from(json['events'] ?? {}),

      trail:
          (json['trail'] as List<dynamic>? ?? [])
              .map((e) => FlightTrailPoint.fromJson(e))
              .toList(),

      type: json['type'] ?? 'free',
      jobId: json['jobId'],
    );
  }

  // =========================
  // TO JSON (Flutter → Mongo)
  // =========================
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'aircraft': aircraft,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'duration': duration,

        'startLocation': startLocation?.toJson(),
        'endLocation': endLocation?.toJson(),

        'distanceFlown': distanceFlown,
        'avgAirspeed': avgAirspeed,
        'maxAltitude': maxAltitude,
        'cruiseTime': cruiseTime,

        'turbulence': turbulence.map((e) => e.toJson()).toList(),
        'events': events,
        'trail': trail.map((e) => e.toJson()).toList(),

        'type': type,
        'jobId': jobId,
      };
}
