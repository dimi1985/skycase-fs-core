import 'package:flutter/material.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/models/simlink_data.dart';

class GroundOpsFuelPayloadCard extends StatelessWidget {
  final SimLinkData simData;
  final DispatchJob? job;

  const GroundOpsFuelPayloadCard({
    super.key,
    required this.simData,
    required this.job,
  });

  @override
  Widget build(BuildContext context) {
    final tanks = simData.fuelTanks;
    final hasTanks = tanks != null;
    final totalFuel = hasTanks ? tanks.totalCurrent : simData.fuelGallons;
    final payloadLbs = job?.payloadLbs ?? 0;
    final pax = job?.paxCount ?? 0;
    final isPayloadReady = payloadLbs > 0 || pax > 0;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 0.6),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⛽ Fuel', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${totalFuel.toStringAsFixed(1)} gal'),
            if (hasTanks) ...[
              const SizedBox(height: 4),
              Text('L: ${tanks.leftMain.current.toStringAsFixed(1)}'),
              Text('R: ${tanks.rightMain.current.toStringAsFixed(1)}'),
            ],
            const SizedBox(height: 10),
            const Text('📦 Payload', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Cargo: ${payloadLbs.toStringAsFixed(0)} lb'),
            Text('Pax: $pax'),
            const SizedBox(height: 6),
            Text(
              isPayloadReady ? 'READY' : 'NOT READY',
              style: TextStyle(
                color: isPayloadReady ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Load manually in MSFS', style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
