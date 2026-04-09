import 'package:flutter/material.dart';
import 'package:skycase/models/dispatch_job.dart';
import 'package:skycase/utils/manifest_generator.dart';

class GroundOpsManifestCard extends StatelessWidget {
  final DispatchJob job;

  const GroundOpsManifestCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 0.6),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋 Manifest', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('• Type: ${job.type.toUpperCase()}'),
            if (job.payloadLbs > 0) ...[
              const SizedBox(height: 6),
              const Text('• Cargo:'),
              for (final e in ManifestGenerator.cargo(job.payloadLbs)) Text('   - $e'),
            ],
            if (job.paxCount > 0) ...[
              const SizedBox(height: 6),
              const Text('• Pax:'),
              for (final p in ManifestGenerator.pax(job.paxCount)) Text('   - $p'),
            ],
            if (job.isFuelJob) ...[
              const SizedBox(height: 6),
              const Text('• Fuel Delivery:'),
              for (final f in ManifestGenerator.fuel(job.transferFuelGallons)) Text('   - $f'),
            ],
          ],
        ),
      ),
    );
  }
}
