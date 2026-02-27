import 'package:flutter/material.dart';

class MapTileOption {
  final String name;
  final String url;
  final List<String> subdomains;

  const MapTileOption({
    required this.name,
    required this.url,
    this.subdomains = const ['a', 'b', 'c'],
  });
}

class MapTileSelector extends StatelessWidget {
  final int selectedIndex;
  final List<MapTileOption> tileOptions;
  final void Function(int) onSelected;
  final Color? iconColor; // <-- Add this
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
        return tileOptions
            .asMap()
            .entries
            .map(
              (entry) => PopupMenuItem<int>(
                value: entry.key,
                child: Text(
                  entry.value.name,
                  style: TextStyle(
                    fontWeight:
                        selectedIndex == entry.key
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList();
      },
    );
  }
}
