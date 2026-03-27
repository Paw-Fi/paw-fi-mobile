import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/l10n/l10n.dart';

void showEnvelopeModeSettingsModal(
  BuildContext context,
  ColorScheme colorScheme,
  bool envelopeMode,
  ValueChanged<bool> onEnvelopeModeChanged,
  bool includeUpcomingRecurring,
  ValueChanged<bool> onIncludeUpcomingRecurringChanged,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
    builder: (context) {
      var forecastEnabled = includeUpcomingRecurring;
      return StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: colorScheme.sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.howItWorksTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          Icon(Icons.close, color: colorScheme.mutedForeground),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InfoRow(
                  icon: Icons.pie_chart_outline_rounded,
                  title: context.l10n.allocateYourIncomeTitle,
                  description: context.l10n.allocateYourIncomeDescription,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),
                InfoRow(
                  icon: Icons.track_changes_rounded,
                  title: context.l10n.trackSpendingTitle,
                  description: context.l10n.trackSpendingDescription,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),
                InfoRow(
                  icon: Icons.warning_amber_rounded,
                  title: context.l10n.avoidOverspendingTitle,
                  description: context.l10n.avoidOverspendingDescription,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.pocketsForecastRecurringSpentTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.foreground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n
                                  .pocketsForecastRecurringSpentDescription,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch.adaptive(
                        value: forecastEnabled,
                        onChanged: (value) {
                          setModalState(() => forecastEnabled = value);
                          onIncludeUpcomingRecurringChanged(value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
