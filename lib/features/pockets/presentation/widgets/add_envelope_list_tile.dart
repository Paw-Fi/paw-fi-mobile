import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AddEnvelopeListTile extends StatelessWidget {
  const AddEnvelopeListTile({
    super.key,
    required this.colorScheme,
    required this.onTap,
    required this.isEnabled,
    this.onDisabledTap,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final bool isEnabled;
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    final title =
        isEnabled ? context.l10n.newPocketTitle : context.l10n.monthlyBudget;
    final subtitle =
        isEnabled ? null : context.l10n.pleaseSetMonthlyBudgetFirst;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: subtitle == null ? title : '$title. $subtitle',
      child: GestureDetector(
        onTap: isEnabled ? onTap : onDisabledTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEnabled
                ? colorScheme.pocketAddSurface
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isEnabled
                  ? colorScheme.pocketAddBorder
                  : colorScheme.outline.withValues(alpha: 0.22),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEnabled
                      ? colorScheme.primary.withValues(alpha: 0.08)
                      : colorScheme.surface,
                ),
                child: Icon(
                  isEnabled
                      ? Icons.add_rounded
                      : Icons.account_balance_wallet_outlined,
                  color: isEnabled
                      ? colorScheme.primary
                      : colorScheme.mutedForeground,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isEnabled
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isEnabled
                    ? Icons.add_circle_outline_rounded
                    : Icons.lock_outline_rounded,
                color: isEnabled
                    ? colorScheme.primary
                    : colorScheme.mutedForeground,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
