import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AddEnvelopeCard extends StatelessWidget {
  const AddEnvelopeCard({
    super.key,
    required this.colorScheme,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.pocketAddSurface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colorScheme.pocketAddBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.08),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.newPocketTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.pocketAddText,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
