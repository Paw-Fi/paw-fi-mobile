import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AddEnvelopeCard extends StatelessWidget {
  const AddEnvelopeCard({
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
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.0),
        child: InkWell(
          onTap: isEnabled ? onTap : onDisabledTap,
          borderRadius: BorderRadius.circular(32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isEnabled
                  ? colorScheme.pocketAddSurface
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isEnabled
                    ? colorScheme.pocketAddBorder
                    : colorScheme.outline.withValues(alpha: 0.22),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isEnabled
                          ? colorScheme.primary.withValues(alpha: 0.08)
                          : colorScheme.surface,
                      border: isEnabled
                          ? null
                          : Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                    ),
                    child: Icon(
                      isEnabled
                          ? Icons.add_rounded
                          : Icons.account_balance_wallet_outlined,
                      color: isEnabled
                          ? colorScheme.primary
                          : colorScheme.mutedForeground,
                      size: 29,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isEnabled
                          ? colorScheme.pocketAddText
                          : colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: subtitle == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
