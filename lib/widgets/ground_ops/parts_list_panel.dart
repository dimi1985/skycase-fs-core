import 'package:flutter/material.dart';
import 'package:skycase/models/ground_ops/ground_ops_template.dart';

class PartsListPanel extends StatelessWidget {
  final List<AircraftPolygonPart> parts;
  final String? selectedPartId;
  final ValueChanged<String> onSelectPart;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String partId)? onDeletePart;

  const PartsListPanel({
    super.key,
    required this.parts,
    required this.selectedPartId,
    required this.onSelectPart,
    required this.onReorder,
    this.onDeletePart,
  });

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return const Center(
        child: Text('No parts yet'),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: parts.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final part = parts[index];
        final isSelected = part.id == selectedPartId;

        return Container(
          key: ValueKey(part.id),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade700,
            ),
          ),
          child: ListTile(
            dense: true,
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            title: Text(part.name),
            subtitle: Text(_labelForType(part.type)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                ),
                if (onDeletePart != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDeletePart!(part.id),
                  ),
                ],
              ],
            ),
            onTap: () => onSelectPart(part.id),
          ),
        );
      },
    );
  }

static String _labelForType(AircraftPartType type) {
  switch (type) {
    case AircraftPartType.fuselage:
      return 'Fuselage';
    case AircraftPartType.wingLeft:
      return 'Left Wing';
    case AircraftPartType.wingRight:
      return 'Right Wing';
    case AircraftPartType.flapLeft:
      return 'Left Flap';
    case AircraftPartType.flapRight:
      return 'Right Flap';
    case AircraftPartType.aileronLeft:
      return 'Left Aileron';
    case AircraftPartType.aileronRight:
      return 'Right Aileron';
    case AircraftPartType.elevatorLeft:
      return 'Left Elevator';
    case AircraftPartType.elevatorRight:
      return 'Right Elevator';
    case AircraftPartType.rudder:
      return 'Rudder';
    case AircraftPartType.engineSingle:
      return 'Single Engine';
    case AircraftPartType.engineLeft:
      return 'Left Engine';
    case AircraftPartType.engineRight:
      return 'Right Engine';
    case AircraftPartType.engineCenter:
      return 'Center Engine';
    case AircraftPartType.propeller:
      return 'Propeller';
    case AircraftPartType.rotorMain:
      return 'Main Rotor';
    case AircraftPartType.noseGear:
      return 'Nose Gear';
    case AircraftPartType.mainGearLeft:
      return 'Left Main Gear';
    case AircraftPartType.mainGearRight:
      return 'Right Main Gear';
    case AircraftPartType.mainGearCenter:
      return 'Center Main Gear';
  }
}
}