import 'package:flutter/material.dart';

class ConnectingBanner extends StatelessWidget {
  const ConnectingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          "Connecting to SimLink...",
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
