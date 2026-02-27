import 'package:flutter/material.dart';

class ChecklistFAB extends StatelessWidget {
  final VoidCallback onTap;

  const ChecklistFAB({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FloatingActionButton(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onPressed: onTap,
      child: const Icon(Icons.checklist),
    );
  }
}
