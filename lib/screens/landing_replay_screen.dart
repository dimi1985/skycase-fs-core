import 'package:flutter/material.dart';

import '../models/flight_log.dart';
import '../widgets/landing/landing_replay_view.dart';

class LandingReplayScreen extends StatelessWidget {
  final Landing2d landing;
  final String? airportIcao;

  const LandingReplayScreen({
    super.key,
    required this.landing,
    this.airportIcao,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final subtitleParts = <String>[
      if ((airportIcao ?? '').trim().isNotEmpty) airportIcao!.trim(),
      if (landing.runway.trim().isNotEmpty) 'RWY ${landing.runway.trim()}',
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Landing Replay'),
            if (subtitleParts.isNotEmpty)
              Text(
                subtitleParts.join(' • '),
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: LandingReplayView(landing: landing),
    );
  }
}