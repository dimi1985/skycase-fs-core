import 'package:flutter/material.dart';
import 'package:skycase/models/simlink_data.dart';

class BatteryStatusHUD extends StatelessWidget {
  final SimLinkData simData;

  const BatteryStatusHUD({super.key, required this.simData});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final on = simData.mission.battery;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: on ? Colors.greenAccent : Colors.redAccent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bolt,
            size: 16,
            color: on ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 6),
          Text(
            on ? "BATTERY ON" : "BATTERY OFF",
            style: TextStyle(
              fontSize: 12,
              color: on
                  ? Colors.greenAccent.withOpacity(0.9)
                  : Colors.redAccent.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
