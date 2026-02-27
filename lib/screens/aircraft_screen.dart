import 'package:flutter/material.dart';
import 'package:skycase/models/learned_aircraft.dart';
import 'package:skycase/services/aircraft_service.dart';

class AircraftScreen extends StatefulWidget {
  const AircraftScreen({super.key});

  @override
  State<AircraftScreen> createState() => _AircraftScreenState();
}

class _AircraftScreenState extends State<AircraftScreen> {
  List<LearnedAircraft> aircraft = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAircraft();
  }

  Future<void> _loadAircraft() async {
    final list = await AircraftService.getAll();
    if (!mounted) return;

    setState(() {
      aircraft = list;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;

    // Responsive columns
    int columns = 2;
    if (width > 900) columns = 3;
    if (width > 1300) columns = 4;

    return Scaffold(
      appBar: AppBar(title: const Text("Aircraft Hangar")),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : aircraft.isEmpty
              ? const Center(child: Text("No aircraft recorded yet"))
              : Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.builder(
                  itemCount: aircraft.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final ac = aircraft[index];
                    return _aircraftCard(theme, colors, ac);
                  },
                ),
              ),
    );
  }

  // -----------------------------------------------------
  // AIRCRAFT CARD (GRID ITEM)
  // -----------------------------------------------------
  Widget _aircraftCard(
    ThemeData theme,
    ColorScheme colors,
    LearnedAircraft ac,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withOpacity(0.25), width: 1),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Text(
              ac.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ac.id,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 12),

     
            // FUEL
            _section(theme, "Fuel", [
              _row("Capacity", ac.fuelCapacityGallons, suffix: " gal"),
            ]),

            // GEAR (ICONS KEEP THIS COMPACT)
            _section(theme, "Gear", [
              _boolRow("Wheels", ac.wheels),
              _boolRow("Retractable", ac.retractable),
            ]),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // HELPERS
  // -----------------------------------------------------
  Widget _section(ThemeData theme, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, num? value, {String suffix = " lbs"}) {
    if (value == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            "${value.toStringAsFixed(0)}$suffix",
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _boolRow(String label, bool? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Icon(
            value == true ? Icons.check_circle : Icons.cancel,
            color: value == true ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }
}
