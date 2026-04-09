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
  final Landing2d? landing2d;
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
    this.landing2d,
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
      landing2d:
          json['landing2d'] != null
              ? Landing2d.fromJson(Map<String, dynamic>.from(json['landing2d']))
              : null,
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
    'landing2d': landing2d?.toJson(),
    'type': type,
    'jobId': jobId,
  };
}

class Landing2dSample {
  final double lat;
  final double lng;
  final double heading;
  final double airspeed;
  final double altitude;
  final double verticalSpeed;
  final bool onGround;
  final DateTime timestamp;

  Landing2dSample({
    required this.lat,
    required this.lng,
    required this.heading,
    required this.airspeed,
    required this.altitude,
    required this.verticalSpeed,
    required this.onGround,
    required this.timestamp,
  });

  factory Landing2dSample.fromJson(Map<String, dynamic> json) {
    return Landing2dSample(
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0,
      airspeed: (json['airspeed'] as num?)?.toDouble() ?? 0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0,
      verticalSpeed: (json['verticalSpeed'] as num?)?.toDouble() ?? 0,
      onGround: json['onGround'] == true,
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'heading': heading,
    'airspeed': airspeed,
    'altitude': altitude,
    'verticalSpeed': verticalSpeed,
    'onGround': onGround,
    'timestamp': timestamp.toIso8601String(),
  };
}
class Landing2d {
  final String runway;
  final double runwayHeading;
  final double touchdownLat;
  final double touchdownLng;
  final double touchdownHeading;
  final double touchdownVerticalSpeed;
  final double touchdownGroundSpeed;
  final double touchdownPitch;
  final double touchdownBank;
  final bool hardLanding;
  final int butterScore;
  final int rolloutSeconds;
  final List<Landing2dSample> samples;

  Landing2d({
    required this.runway,
    required this.runwayHeading,
    required this.touchdownLat,
    required this.touchdownLng,
    required this.touchdownHeading,
    required this.touchdownVerticalSpeed,
    required this.touchdownGroundSpeed,
    required this.touchdownPitch,
    required this.touchdownBank,
    required this.hardLanding,
    required this.butterScore,
    required this.rolloutSeconds,
    required this.samples,
  });

  factory Landing2d.fromJson(Map<String, dynamic> json) {
    return Landing2d(
      runway: json['runway'] ?? '',
      runwayHeading: (json['runwayHeading'] as num?)?.toDouble() ?? 0,
      touchdownLat: (json['touchdownLat'] as num?)?.toDouble() ?? 0,
      touchdownLng: (json['touchdownLng'] as num?)?.toDouble() ?? 0,
      touchdownHeading: (json['touchdownHeading'] as num?)?.toDouble() ?? 0,
      touchdownVerticalSpeed:
          (json['touchdownVerticalSpeed'] as num?)?.toDouble() ?? 0,
      touchdownGroundSpeed:
          (json['touchdownGroundSpeed'] as num?)?.toDouble() ?? 0,
      touchdownPitch: (json['touchdownPitch'] as num?)?.toDouble() ?? 0,
      touchdownBank: (json['touchdownBank'] as num?)?.toDouble() ?? 0,
      hardLanding: json['hardLanding'] == true,
      butterScore: (json['butterScore'] as num?)?.toInt() ?? 0,
      rolloutSeconds: (json['rolloutSeconds'] as num?)?.toInt() ?? 0,
      samples:
          (json['samples'] as List<dynamic>? ?? [])
              .map(
                (e) => Landing2dSample.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'runway': runway,
    'runwayHeading': runwayHeading,
    'touchdownLat': touchdownLat,
    'touchdownLng': touchdownLng,
    'touchdownHeading': touchdownHeading,
    'touchdownVerticalSpeed': touchdownVerticalSpeed,
    'touchdownGroundSpeed': touchdownGroundSpeed,
    'touchdownPitch': touchdownPitch,
    'touchdownBank': touchdownBank,
    'hardLanding': hardLanding,
    'butterScore': butterScore,
    'rolloutSeconds': rolloutSeconds,
    'samples': samples.map((e) => e.toJson()).toList(),
  };
}
