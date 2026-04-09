import 'package:skycase/models/fuel_tanks.dart';
import 'package:skycase/models/job_payload.dart';

class GroundState {
  final String aircraftId;
  final String aircraftTitle;

  final double fuelGallons;
  final double fuelCapacityGallons;

  final FuelTanks fuelTanks;
  final JobPayload jobPayload;

  GroundState({
    required this.aircraftId,
    required this.aircraftTitle,
    required this.fuelGallons,
    required this.fuelCapacityGallons,
    required this.fuelTanks,
    required this.jobPayload,
  });

  factory GroundState.fromJson(Map<String, dynamic> j) {
    final s = j['state'] ?? j;

    return GroundState(
      aircraftId: s['aircraftId'] ?? '',
      aircraftTitle: s['aircraftTitle'] ?? '',
      fuelGallons: (s['fuelGallons'] ?? 0).toDouble(),
      fuelCapacityGallons: (s['fuelCapacityGallons'] ?? 0).toDouble(),
      fuelTanks: FuelTanks.fromJson(s['fuelTanks'] ?? {}),
      jobPayload: JobPayload.fromJson(s['jobPayload'] ?? {}),
    );
  }
}