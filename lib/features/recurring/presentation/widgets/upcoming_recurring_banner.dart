import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

String buildUpcomingDueLabel(BuildContext context, int daysUntil) {
  if (daysUntil <= 0) return context.l10n.today;
  if (daysUntil == 1) return context.l10n.tomorrow;
  return context.l10n.inDays(daysUntil);
}

class UpcomingRecurringBanner extends StatelessWidget {
  const UpcomingRecurringBanner({
    super.key,
    required this.upcoming,
    required this.onTap,
  });

  final UpcomingRecurringTransaction upcoming;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transaction = upcoming.transaction;
    final isIncome = transaction.type == 'income';
    final heading =
        isIncome ? context.l10n.upcomingPaychecks : context.l10n.upcomingBills;
    final detail = (transaction.description?.trim().isNotEmpty ?? false)
        ? transaction.description!.trim()
        : transaction.category;
    final dueLabel = buildUpcomingDueLabel(context, upcoming.daysUntil);
    final normalized = double.parse(formatAmount(transaction.amount.abs()));
    final localized = formatLocalizedNumber(context, normalized);
    final symbol = resolveCurrencySymbol(transaction.currency);
    final sign = isIncome ? '+' : '-';
    final amountText = '$sign$symbol$localized';

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.muted,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.border.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isIncome ? colorScheme.success : colorScheme.primary)
                      .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.repeat,
                  color: isIncome ? colorScheme.success : colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dueLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isIncome
                          ? colorScheme.success
                          : colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colorScheme.mutedForeground,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
