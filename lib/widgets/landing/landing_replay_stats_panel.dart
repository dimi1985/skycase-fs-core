import 'package:flutter/material.dart';

import '../../models/flight_log.dart';

class LandingReplayStatsPanel extends StatelessWidget {
  final Landing2d landing;
  final dynamic frame;

  const LandingReplayStatsPanel({
    super.key,
    required this.landing,
    required this.frame,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Landing Data',
            style: TextStyle(
              color: colors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _row('Touchdown VS', '${landing.touchdownVerticalSpeed.toStringAsFixed(0)} fpm'),
          _row('Touchdown GS', '${landing.touchdownGroundSpeed.toStringAsFixed(0)} kt'),
          _row('Touchdown Bank', '${landing.touchdownBank.toStringAsFixed(1)}°'),
          _row('Rollout', '${landing.rolloutSeconds} sec'),
          _row('Hard Landing', landing.hardLanding ? 'Yes' : 'No'),
          const Divider(height: 24),
          _row('Replay ALT', '${(frame.altitudeFt as double).toStringAsFixed(0)} ft'),
          _row('Replay GS', '${(frame.groundSpeedKt as double).toStringAsFixed(0)} kt'),
          _row('Replay HDG', '${(frame.headingDeg as double).toStringAsFixed(0)}°'),
          _row('Replay VS', '${(frame.verticalSpeedFpm as double).toStringAsFixed(0)} fpm'),
          _row('State', (frame.onGround as bool) ? 'On Ground' : 'Airborne'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}