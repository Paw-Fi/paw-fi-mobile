import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/domain/entities/shared_budget.dart';
import 'package:moneko/features/households/domain/entities/household_summary.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';

Widget buildHouseholdBudgetCard(
  BuildContext context,
  shadcnui.ColorScheme colorScheme,
  List<SharedBudget> budgets, {
  required String currencyCode,
  List<BudgetStatus>? budgetStatuses,
  VoidCallback? onTap,
}) {
  final filtered = budgets.where((b) => b.currency.toUpperCase() == currencyCode.toUpperCase()).toList();
  final totalAmount = filtered.fold<double>(0.0, (sum, b) => sum + (b.amountCents / 100.0));

  double? remainingAmount;
  if (budgetStatuses != null && budgetStatuses.isNotEmpty) {
    final remainingCents = budgetStatuses.fold<int>(0, (sum, s) => sum + (s.remainingCents));
    remainingAmount = remainingCents / 100.0;
  }

  final card = Container(
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colorScheme.border.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            remainingAmount != null ? context.l10n.remaining : context.l10n.sharedBudgets,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          formatCurrency((remainingAmount ?? totalAmount), currencyCode.toUpperCase()),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${filtered.length} ${filtered.length == 1 ? context.l10n.budget : context.l10n.budgets}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorScheme.mutedForeground,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  if (onTap == null) return card;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    ),
  );
}

Widget buildHouseholdNetPositionCard(
  BuildContext context,
  shadcnui.ColorScheme colorScheme,
  HouseholdSummary? summary, {
  VoidCallback? onTap,
}) {
  final netCents = summary?.totals.netCents ?? 0;
  final isNegative = netCents < 0;
  final currency = (summary?.currency ?? 'USD').toUpperCase();
  final amount = (netCents.abs()) / 100.0;
  final formatted = formatCurrency(amount, currency);
  final displayText = isNegative ? '-$formatted' : formatted;
  
  final statusColor = isNegative ? const Color(0xFFEF4444) : const Color(0xFF10B981);
  
  final card = Container(
    decoration: BoxDecoration(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colorScheme.border.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            context.l10n.netPosition,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayText,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isNegative ? context.l10n.negative : context.l10n.positive,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  if (onTap == null) return card;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    ),
  );
}
