import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/recurring/presentation/widgets/confirm_recurring_occurrence_sheet.dart';
import 'package:moneko/features/recurring/presentation/utils/recurring_occurrence_schedule.dart';

/// Get localized frequency text for a recurring transaction
String getLocalizedFrequencyText(
    BuildContext context, RecurringTransaction transaction) {
  final l10n = context.l10n;

  if (transaction.recurrenceRule == null) return l10n.oneTime;

  final rule = transaction.recurrenceRule!;
  switch (rule.frequency) {
    case 'daily':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXDays(rule.interval!)
          : l10n.daily;
    case 'weekly':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXWeeks(rule.interval!)
          : l10n.weekly;
    case 'biweekly':
      return l10n.every2Weeks;
    case 'semi_monthly':
      return l10n.custom;
    case 'monthly':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXMonths(rule.interval!)
          : l10n.monthly;
    case 'yearly':
      return rule.interval != null && rule.interval! > 1
          ? l10n.everyXYears(rule.interval!)
          : l10n.yearly;
    case 'custom':
      return l10n.custom;
    default:
      return l10n.unknown;
  }
}

/// Modern, Apple-inspired recurring transaction card with slidable actions
class RecurringTransactionCard extends ConsumerWidget {
  final RecurringTransaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const RecurringTransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = transaction.type == 'income';
    final description = transaction.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final localizedCategory =
        getCategoryTranslation(context, transaction.category);

    final preferredTimezone = ref
        .watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
    final userNow = effectiveNow(preferredTimezone: preferredTimezone);
    final userToday = DateTime(userNow.year, userNow.month, userNow.day);
    final nextOccurrence = transaction.getNextOccurrence(userNow);
    final historyStartDate =
        transaction.recurrenceRule?.anchorDate ?? transaction.date;

    final categoryColor = getCategoryColor(transaction.category, context);
    final adaptedCategoryColor =
        AppTheme.adaptCategoryColorForTheme(categoryColor, colorScheme);
    final categoryIcon = getCategoryIcon(transaction.category);

    // Format amount
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? colorScheme.success : colorScheme.foreground;
    final normalizedAmount = double.parse(formatAmount(transaction.amount));
    final localizedNumber = formatLocalizedNumber(context, normalizedAmount);
    final currencySymbol = resolveCurrencySymbol(transaction.currency);
    final amountText = '$sign$currencySymbol$localizedNumber';

    final userId = ref.watch(authProvider).uid;
    final timeline = userId.isEmpty
        ? const <RecurringOccurrenceTimelineItem>[]
        : ref
                .watch(recurringOccurrenceTimelineProvider(
                  RecurringOccurrenceTimelineQuery(
                    userId: userId,
                    householdId: transaction.householdId,
                    recurringId: transaction.id,
                    startDate: historyStartDate,
                    endDate: userToday,
                  ),
                ))
                .valueOrNull ??
            const <RecurringOccurrenceTimelineItem>[];
    final confirmedDates = <String>{
      for (final item in timeline)
        if (item.isConfirmed) formatDateOnlyYmd(item.scheduledOccurrenceDate),
    };
    final latestUnconfirmedOccurrence = getOccurrencesList(transaction, userNow)
        .where((occurrence) =>
            !occurrence.isAfter(userToday) &&
            !confirmedDates.contains(formatDateOnlyYmd(occurrence)))
        .fold<DateTime?>(
            null,
            (latest, occurrence) => latest == null || occurrence.isAfter(latest)
                ? occurrence
                : latest);
    final canConfirm = latestUnconfirmedOccurrence != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(transaction.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.22,
          children: [
            SlidableAction(
              onPressed: (_) async {
                if (onDelete != null) {
                  onDelete!();
                }
              },
              backgroundColor: colorScheme.destructive,
              foregroundColor: colorScheme.onError,
              icon: Icons.delete,
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.homeCardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.homeCardBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.homeCardShadow,
                blurRadius: 20,
                offset: const Offset(0, 6),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Material(
            color: colorScheme.surface.withValues(alpha: 0.0),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Category Icon with adapted background color and soft glow
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: adaptedCategoryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: adaptedCategoryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: adaptedCategoryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and subtitle info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasDescription ? description : localizedCategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          if (hasDescription) ...[
                            const SizedBox(height: 2),
                            Text(
                              localizedCategory,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.mutedForeground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Frequency label
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      colorScheme.muted.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: colorScheme.border
                                        .withValues(alpha: 0.1),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  getLocalizedFrequencyText(
                                      context, transaction),
                                  style: TextStyle(
                                    color: colorScheme.mutedForeground,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: colorScheme.mutedForeground,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  formatLocalizedDate(context, nextOccurrence),
                                  style: TextStyle(
                                    color: colorScheme.mutedForeground,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Amount and Action/Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          amountText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (transaction.isActive)
                          canConfirm
                              ? InkWell(
                                  onTap: () =>
                                      showConfirmRecurringOccurrenceSheet(
                                    context: context,
                                    recurringTransaction: transaction,
                                    scheduledOccurrenceDate:
                                        latestUnconfirmedOccurrence,
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_rounded,
                                          size: 12,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          context.l10n.confirmPayment,
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink()
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.muted.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.l10n.ended.toUpperCase(),
                              style: TextStyle(
                                color: colorScheme.mutedForeground,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget for when there are no recurring transactions
class EmptyRecurringState extends StatelessWidget {
  final String type; // 'expense' or 'income'
  final VoidCallback? onAddPressed;

  const EmptyRecurringState({
    super.key,
    required this.type,
    this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedType = type.trim().toLowerCase();
    final isExpense =
        normalizedType == 'expense' || normalizedType == 'expenses';
    final isIncome = normalizedType == 'income' || normalizedType == 'incomes';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Beautiful animated-like background circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: (isExpense ? colorScheme.primary : colorScheme.success)
                    .withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isExpense ? colorScheme.primary : colorScheme.success)
                      .withValues(alpha: 0.12),
                  width: 2,
                ),
              ),
              child: Icon(
                isExpense ? Icons.autorenew_rounded : Icons.trending_up_rounded,
                size: 44,
                color: isExpense ? colorScheme.primary : colorScheme.success,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              isExpense
                  ? context.l10n.noRecurringExpenses
                  : isIncome
                      ? context.l10n.noRecurringIncome
                      : context.l10n.noRecurringExpenses,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              isExpense
                  ? context.l10n.setupAutomaticExpenseTracking
                  : isIncome
                      ? context.l10n.setupAutomaticIncomeTracking
                      : context.l10n.setupAutomaticExpenseTracking,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),

            if (onAddPressed != null) ...[
              const SizedBox(height: 24),
              AdaptiveButton(
                onPressed: onAddPressed,
                label: isExpense
                    ? context.l10n.addRecurringExpense
                    : context.l10n.addRecurringIncome,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
