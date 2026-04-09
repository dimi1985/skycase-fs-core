import 'package:flutter/material.dart';

class LandingReplayHud extends StatelessWidget {
  final String runway;
  final Duration elapsed;
  final Duration total;
  final double altitudeFt;
  final double groundSpeedKt;
  final double headingDeg;
  final double verticalSpeedFpm;
  final bool onGround;

  const LandingReplayHud({
    super.key,
    required this.runway,
    required this.elapsed,
    required this.total,
    required this.altitudeFt,
    required this.groundSpeedKt,
    required this.headingDeg,
    required this.verticalSpeedFpm,
    required this.onGround,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _hudChip('RWY', runway.isEmpty ? '—' : runway),
        _hudChip('TIME', '${_fmt(elapsed)} / ${_fmt(total)}'),
        _hudChip('ALT', '${altitudeFt.toStringAsFixed(0)} ft'),
        _hudChip('GS', '${groundSpeedKt.toStringAsFixed(0)} kt'),
        _hudChip('HDG', '${headingDeg.toStringAsFixed(0)}°'),
        _hudChip('VS', '${verticalSpeedFpm.toStringAsFixed(0)} fpm'),
        _hudChip('STATE', onGround ? 'GND' : 'AIR'),
      ],
    );
  }

  Widget _hudChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC0F1822),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final totalSeconds = d.inSeconds;
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}