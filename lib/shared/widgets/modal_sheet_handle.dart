import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Reusable modal sheet drag handle component
class ModalSheetHandle extends StatelessWidget {
  const ModalSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.mutedForeground.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
