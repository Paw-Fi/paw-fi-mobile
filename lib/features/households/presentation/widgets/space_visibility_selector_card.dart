import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_selector_button.dart';

class SpaceVisibilitySelectorCard extends StatelessWidget {
  const SpaceVisibilitySelectorCard({
    super.key,
    required this.isSharedSpace,
    required this.onChanged,
    this.onInfoTap,
    this.enabled = true,
  });

  final bool isSharedSpace;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onInfoTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.whoCanSeeAndAddExpense,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.foreground,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),
              AdaptivePopupMenuButton.widget<bool>(
                items: [
                  AdaptivePopupMenuItem(
                    label: context.l10n.allGroupMembers,
                    value: true,
                    icon: PlatformInfo.isIOS26OrHigher()
                        ? 'person.2'
                        : Icons.group_outlined,
                  ),
                  AdaptivePopupMenuItem(
                    label: context.l10n.justMyself,
                    value: false,
                    icon: PlatformInfo.isIOS26OrHigher()
                        ? 'person'
                        : Icons.person_outline,
                  ),
                ],
                onSelected: (_, item) {
                  final value = item.value;
                  if (value != null) onChanged?.call(value);
                },
                child: IgnorePointer(
                  child: MonekoSelectorButton(
                    label: isSharedSpace
                        ? context.l10n.allGroupMembers
                        : context.l10n.justMyself,
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: isSharedSpace
                          ? context
                              .l10n.everyoneInSpaceCanViewAndAddTransactions
                          : context
                              .l10n.onlyYouCanSeeAndAddTransactionsInThisSpace,
                    ),
                    if (onInfoTap != null)
                      TextSpan(
                        text: context.l10n.howItWorksTitle,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onInfoTap,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
