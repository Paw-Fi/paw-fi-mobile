import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AddEnvelopeListTile extends StatelessWidget {
  const AddEnvelopeListTile({
    super.key,
    required this.colorScheme,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.pocketAddSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.pocketAddBorder,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.newPocketTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
