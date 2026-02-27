import 'package:flutter/material.dart';
import 'package:skycase/models/simlink_data.dart';

class WeightBalanceHUD extends StatelessWidget {
  final SimLinkData simData;

  const WeightBalanceHUD({super.key, required this.simData});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outline, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _line("GW", simData.weights.totalWeight),
          _line("MTOW", simData.weights.maxTakeoffWeight),
          _line("MGW", simData.weights.maxGrossWeight),
          const SizedBox(height: 4),
          _line("ZFW", simData.weights.zfw),
          _line("Fuel", simData.weights.fuelWeight),
          _line("Payload", simData.weights.payloadWeight),
        ],
      ),
    );
  }

  Widget _line(String label, double value) {
    return Text(
      "$label: ${value.toStringAsFixed(0)} lbs",
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withOpacity(0.85),
        letterSpacing: 0.4,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
