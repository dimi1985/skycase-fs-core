import 'package:flutter/material.dart';

class SnapshotCardBox extends StatelessWidget {
  final String? tailNumber;
  final String? snapshotDate;
  final double totalFuel;
  final Map<String, double> payloadDistribution;
  final Map<String, double> fuelReadings;

  const SnapshotCardBox({
    super.key,
    required this.tailNumber,
    required this.snapshotDate,
    required this.totalFuel,
    required this.payloadDistribution,
    required this.fuelReadings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '🛫 AIRCRAFT STATE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                tailNumber ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📅 Updated: $snapshotDate',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          /// Fuel
          Row(
            children: [
              const Icon(Icons.local_gas_station, size: 20),
              const SizedBox(width: 8),
              Text(
                'Fuel: ${totalFuel.toStringAsFixed(1)} gal',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 32),

          /// Payload
          const Text(
            '📦 Payload Distribution',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...payloadDistribution.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key),
                  Text('${entry.value.toStringAsFixed(1)} lbs'),
                ],
              ),
            );
          }),

          const Divider(height: 32),

          /// Fuel Tanks
          const Text(
            '🧪 Fuel Tank Readings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...fuelReadings.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key),
                  Text('${entry.value.toStringAsFixed(1)} gal'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
