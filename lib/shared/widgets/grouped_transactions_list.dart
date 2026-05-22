import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/home/presentation/utils/transaction_row_display_entry.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

/// Callback signature for when a transaction is tapped
typedef OnTransactionTap = void Function(ExpenseEntry expense);

/// Callback signature for building a custom transaction row
typedef TransactionItemBuilder = Widget Function(
  BuildContext context,
  ExpenseEntry expense,
  bool isFirst,
  bool isLast,
);

/// A reusable widget that displays transactions grouped by month and day
/// with headers showing totals, matching the design from TransactionsPage.
///
/// Features:
/// - Month headers with formatted totals (e.g., "April 2026  -€40")
/// - Day headers with line divider and totals (e.g., "Today  ———  -€40")
/// - Grouped transaction cards with rounded corners (first/last styling)
/// - 56px indented dividers between transactions
/// - Uses TransactionListTile for consistent transaction row appearance
class GroupedTransactionsList extends StatelessWidget {
  /// List of transactions to display
  final List<ExpenseEntry> transactions;

  /// Original source-currency rows keyed by id when [transactions] have been
  /// converted for group totals.
  final Map<String, ExpenseEntry>? rowDisplayTransactionsById;

  /// Currency code for amount formatting (e.g., 'USD', 'EUR')
  final String currency;

  /// Optional timezone for date formatting (defaults to local)
  final String? preferredTimezone;

  /// Called when a transaction is tapped
  final OnTransactionTap? onTransactionTap;

  /// Called when a transaction is long-pressed
  final OnTransactionTap? onTransactionLongPress;

  /// Background color for the card container (defaults to theme card color)
  final Color? cardColor;

  /// Optional padding around the entire list (defaults to EdgeInsets.zero)
  final EdgeInsetsGeometry padding;

  /// Widget to display when there are no transactions
  final Widget? emptyStateWidget;

  /// Whether to apply shadow to the grouped cards (defaults to true in light mode)
  final bool? applyCardShadow;

  /// Border radius for the grouped cards (defaults to Radius 24)
  final double cardBorderRadius;

  /// Whether to show horizontal padding for the list (defaults to true)
  final bool useHorizontalPadding;

  /// Custom builder for transaction items. If provided, overrides the default
  /// TransactionListTile rendering. Useful for selection mode, slidable actions, etc.
  final TransactionItemBuilder? itemBuilder;

  const GroupedTransactionsList({
    super.key,
    required this.transactions,
    this.rowDisplayTransactionsById,
    required this.currency,
    this.preferredTimezone,
    this.onTransactionTap,
    this.onTransactionLongPress,
    this.cardColor,
    this.padding = EdgeInsets.zero,
    this.emptyStateWidget,
    this.applyCardShadow,
    this.cardBorderRadius = 24,
    this.useHorizontalPadding = true,
    this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveCardColor = cardColor ?? colorScheme.homeCardSurface;
    final effectiveApplyShadow =
        applyCardShadow ?? Theme.of(context).brightness == Brightness.light;

    if (transactions.isEmpty) {
      return emptyStateWidget ??
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              context.l10n.noTransactionsYet,
              style: TextStyle(color: colorScheme.mutedForeground),
            ),
          );
    }

    // Group transactions by month and day
    final monthGroups = groupTransactionsByMonth(transactions);
    final listItems = <_TransactionListItem>[];

    for (final month in monthGroups) {
      listItems.add(_TransactionListItem.monthHeader(month));
      final dayGroups = groupTransactionsByDay(month.expenses);
      for (final day in dayGroups) {
        listItems.add(_TransactionListItem.dayHeader(day));
        for (var i = 0; i < day.expenses.length; i++) {
          listItems.add(
            _TransactionListItem.entry(
              expense: day.expenses[i],
              isFirst: i == 0,
              isLast: i == day.expenses.length - 1,
            ),
          );
        }
      }
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: listItems.map((item) {
          if (item.isMonthHeader) {
            return _buildMonthHeader(
              context,
              item.monthGroup!,
              colorScheme,
            );
          }
          if (item.isDayHeader) {
            return _buildDayHeader(
              context,
              item.dayGroup!,
              colorScheme,
            );
          }
          final rowExpense = rowDisplayTransactionsById == null
              ? item.expense!
              : resolveTransactionRowDisplayEntry(
                  item.expense!,
                  rowDisplayTransactionsById!,
                );
          return _buildTransactionRow(
            context,
            rowExpense,
            colorScheme,
            effectiveCardColor,
            isFirst: item.isFirst,
            isLast: item.isLast,
            applyShadow: effectiveApplyShadow,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthHeader(
    BuildContext context,
    MonthTransactionGroup group,
    ColorScheme colorScheme,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = formatMonthHeader(group.monthStart, locale: locale);

    final totalFormatted = formatLocalizedNumber(context, group.total.abs());
    final symbol = resolveCurrencySymbol(currency);
    final totalString = '${group.total < 0 ? '-' : ''}$symbol$totalFormatted';

    final horizontalPadding = useHorizontalPadding ? 16.0 : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 8),
      child: Row(
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Text(
            totalString,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    DayTransactionGroup group,
    ColorScheme colorScheme,
  ) {
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final date = group.date;
    String dateLabel;

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      dateLabel = context.l10n.today;
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      dateLabel = context.l10n.yesterday;
    } else {
      final locale = Localizations.localeOf(context).toString();
      dateLabel = DateFormat('MMM d', locale).format(date);
    }

    final totalFormatted = formatLocalizedNumber(context, group.total.abs());
    final symbol = resolveCurrencySymbol(currency);
    final totalString = '${group.total < 0 ? '-' : ''}$symbol$totalFormatted';

    final horizontalPadding = useHorizontalPadding ? 16.0 : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 6),
      child: Row(
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            totalString,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(
    BuildContext context,
    ExpenseEntry expense,
    ColorScheme colorScheme,
    Color cardColor, {
    required bool isFirst,
    required bool isLast,
    required bool applyShadow,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? Radius.circular(cardBorderRadius) : Radius.zero,
      bottom: isLast ? Radius.circular(cardBorderRadius) : Radius.zero,
    );
    final shouldShadow = isFirst || isLast;

    // If custom itemBuilder is provided, use it
    if (itemBuilder != null) {
      final horizontalPadding = useHorizontalPadding ? 16.0 : 0.0;
      return Container(
        margin: EdgeInsets.fromLTRB(
            horizontalPadding, 0, horizontalPadding, isLast ? 16 : 0),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: radius,
          boxShadow: !applyShadow || !shouldShadow
              ? null
              : [
                  BoxShadow(
                    color: colorScheme.homeCardShadow,
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  )
                ],
        ),
        child: itemBuilder!(context, expense, isFirst, isLast),
      );
    }

    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';

    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, isLast ? 16 : 0),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: radius,
        boxShadow: !applyShadow || !shouldShadow
            ? null
            : [
                BoxShadow(
                  color: colorScheme.homeCardShadow,
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTransactionTap != null
              ? () => onTransactionTap!(expense)
              : null,
          onLongPress: onTransactionLongPress != null
              ? () => onTransactionLongPress!(expense)
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: TransactionListTile(
                  category: expense.category ?? 'uncategorized',
                  title: getCategoryTranslation(
                      context, expense.category ?? 'uncategorized'),
                  description: expense.rawText,
                  date: expense.date,
                  amount: expense.amount,
                  currency: expense.currency ?? currency,
                  isIncome: isIncome,
                  showYouLabel: false,
                  showRecurringChip: expense.isRecurring,
                  accountLabel: expense.accountName,
                ),
              ),
              // Inset Divider (56px indent per design spec)
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 56,
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal helper class to represent different item types in the list
class _TransactionListItem {
  final MonthTransactionGroup? monthGroup;
  final DayTransactionGroup? dayGroup;
  final ExpenseEntry? expense;
  final bool isMonthHeader;
  final bool isDayHeader;
  final bool isFirst;
  final bool isLast;

  const _TransactionListItem._({
    this.monthGroup,
    this.dayGroup,
    this.expense,
    required this.isMonthHeader,
    required this.isDayHeader,
    required this.isFirst,
    required this.isLast,
  });

  factory _TransactionListItem.monthHeader(MonthTransactionGroup group) {
    return _TransactionListItem._(
      monthGroup: group,
      isMonthHeader: true,
      isDayHeader: false,
      isFirst: false,
      isLast: false,
    );
  }

  factory _TransactionListItem.dayHeader(DayTransactionGroup group) {
    return _TransactionListItem._(
      dayGroup: group,
      isMonthHeader: false,
      isDayHeader: true,
      isFirst: false,
      isLast: false,
    );
  }

  factory _TransactionListItem.entry({
    required ExpenseEntry expense,
    required bool isFirst,
    required bool isLast,
  }) {
    return _TransactionListItem._(
      expense: expense,
      isMonthHeader: false,
      isDayHeader: false,
      isFirst: isFirst,
      isLast: isLast,
    );
  }
}
