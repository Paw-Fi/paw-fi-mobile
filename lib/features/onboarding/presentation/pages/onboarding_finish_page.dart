import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class OnboardingFinishPage extends StatelessWidget {
  const OnboardingFinishPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.startLoggingExpenses,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.startLoggingExpensesToSeeCategories,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 46,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: PrimaryAdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      context.l10n.start,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
