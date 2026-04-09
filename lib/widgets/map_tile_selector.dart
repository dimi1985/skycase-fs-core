import 'package:flutter/material.dart';

class MapTileOption {
  final String name;
  final String url;
  final List<String> subdomains;

  final Color mapBackgroundColor;
  final Color fallbackGridColor;
  final Color fallbackCrossColor;

  const MapTileOption({
    required this.name,
    required this.url,
    this.subdomains = const [],
    required this.mapBackgroundColor,
    required this.fallbackGridColor,
    required this.fallbackCrossColor,
  });
}

class MapTileSelector extends StatelessWidget {
  final int selectedIndex;
  final List<MapTileOption> tileOptions;
  final ValueChanged<int> onSelected;
  final Color? iconColor;

  const MapTileSelector({
    super.key,
    required this.selectedIndex,
    required this.tileOptions,
    required this.onSelected,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: Icon(Icons.layers, color: iconColor ?? Colors.white),
      onSelected: onSelected,
      itemBuilder: (context) {
        return tileOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;

          return PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.name,
                    style: TextStyle(
                      fontWeight: selectedIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (selectedIndex == index)
                  const Icon(Icons.check, size: 18),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}