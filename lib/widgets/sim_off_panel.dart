import 'package:flutter/material.dart';

class SimOffPanel extends StatelessWidget {
  const SimOffPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.onSurface.withOpacity(0.15),
                  Colors.transparent,
                ],
                radius: 0.7,
              ),
            ),
            child: Icon(
              Icons.power_settings_new,
              size: 48,
              color: colors.onSurface.withOpacity(0.35),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            "Systems OFF",
            style: theme.textTheme.titleLarge?.copyWith(
              color: colors.onSurface.withOpacity(0.85),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Waiting for aircraft…",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
