import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/derived_selectors.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/util/logger.dart';

class RunwayGauge extends ConsumerWidget {
  const RunwayGauge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final info = ref.watch(runwayProvider);
    final currencyCode =
        ref.watch(homeFilterProvider).selectedCurrency ?? 'USD';
    appLog('widget_viewed: runway_gauge');

    String _formatCurrencyValue(double amount) {
      final normalized = double.parse(formatAmount(amount));
      final symbol = resolveCurrencySymbol(currencyCode);
      final localized = formatLocalizedNumber(context, normalized);
      return '$symbol$localized';
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with days on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.budgetRunway,
                  style: TextStyle(
                      fontSize: 13, color: colorScheme.mutedForeground)),
              Text(
                  '${formatLocalizedNumber(context, info.daysRemaining.round())}d',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.foreground)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: info.gauge,
              backgroundColor: colorScheme.muted.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                  info.gauge < 0.8 ? colorScheme.primary : colorScheme.warning),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '${context.l10n.avgDaily} ${_formatCurrencyValue(info.avgDailySpend)}',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.mutedForeground)),
              Text(
                  '${context.l10n.left} ${_formatCurrencyValue(info.budgetRemaining)}',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.mutedForeground)),
            ],
          ),
        ],
      ),
    );
  }
}
