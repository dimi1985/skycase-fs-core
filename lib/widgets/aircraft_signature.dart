import 'package:flutter/material.dart';

class AircraftSignature extends StatelessWidget {
  final String title;
  const AircraftSignature({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        color: colors.onSurface.withOpacity(0.45),
        letterSpacing: 1.2,
        fontStyle: FontStyle.italic,
        shadows: [
          Shadow(
            blurRadius: 4,
            color: Colors.black.withOpacity(0.6),
          ),
        ],
      ),
    );
  }
}
