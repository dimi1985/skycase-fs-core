import 'package:skycase/models/aircraft_planning_spec.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/models/dispatch_job_fit_result.dart';

class DispatchJobEvaluator {
  static DispatchJobFitResult evaluate({
    required DispatchJob job,
    required AircraftPlanningSpec? spec,
    double? departureFuelLbs,
  }) {
    if (spec == null) {
      return const DispatchJobFitResult.ok();
    }

    final usableRange = spec.usableRangeNm;
    if (usableRange != null &&
        usableRange > 0 &&
        job.distanceNm > usableRange) {
      return DispatchJobFitResult.fail(
        'Not enough range (${job.distanceNm.toStringAsFixed(0)} NM > '
        '${usableRange.toStringAsFixed(0)} NM usable)',
      );
    }

    if (job.paxCount > 0 && spec.maxPax != null) {
      if (job.paxCount > spec.maxPax!) {
        return DispatchJobFitResult.fail(
          'Too many passengers (${job.paxCount} > ${spec.maxPax})',
        );
      }
    }

    final emptyWeight = spec.emptyWeightLbs;
    final mzfw = spec.mzfwLbs;
    if (emptyWeight != null && mzfw != null && mzfw > 0) {
      final zeroFuelWeight = emptyWeight + job.effectivePayloadLbs;
      if (zeroFuelWeight > mzfw) {
        return DispatchJobFitResult.fail(
          'Over MZFW (${zeroFuelWeight.toStringAsFixed(0)} lbs > '
          '${mzfw.toStringAsFixed(0)} lbs)',
        );
      }
    }

    final mtow = spec.mtowLbs;
    if (emptyWeight != null &&
        mtow != null &&
        mtow > 0 &&
        departureFuelLbs != null &&
        departureFuelLbs > 0) {
      final takeoffWeight =
          emptyWeight + job.effectivePayloadLbs + departureFuelLbs;

      if (takeoffWeight > mtow) {
        return DispatchJobFitResult.fail(
          'Over MTOW (${takeoffWeight.toStringAsFixed(0)} lbs > '
          '${mtow.toStringAsFixed(0)} lbs)',
        );
      }
    }

    final payloadCapacity = spec.payloadCapacityLbs;
    if (payloadCapacity != null &&
        payloadCapacity > 0 &&
        job.effectivePayloadLbs > payloadCapacity) {
      return DispatchJobFitResult.fail(
        'Payload too heavy (${job.effectivePayloadLbs} lbs > '
        '${payloadCapacity.toStringAsFixed(0)} lbs)',
      );
    }

    if (job.isFuelJob && payloadCapacity != null) {
      if (job.effectivePayloadLbs > payloadCapacity) {
        return const DispatchJobFitResult.fail(
          'Fuel transfer load exceeds payload capability',
        );
      }
    }

    return const DispatchJobFitResult.ok();
  }
}