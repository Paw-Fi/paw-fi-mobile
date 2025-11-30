import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

class FinancialCalendarWidget extends StatefulWidget {
  final List<ExpenseEntry> transactions;
  final List<RecurringTransaction> recurringTransactions;
  final String currency;
  final DateTime? initialMonth;

  const FinancialCalendarWidget({
    super.key,
    required this.transactions,
    required this.recurringTransactions,
    required this.currency,
    this.initialMonth,
  });

  @override
  State<FinancialCalendarWidget> createState() =>
      _FinancialCalendarWidgetState();
}

class _FinancialCalendarWidgetState extends State<FinancialCalendarWidget> {
  late DateTime _focusedMonth;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.initialMonth ?? DateTime(_today.year, _today.month);
  }

  bool get _isCurrentMonth {
    return _focusedMonth.year == _today.year &&
        _focusedMonth.month == _today.month;
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  Map<String, double> _calculateDailyTotals(DateTime date) {
    double totalExpense = 0;
    double totalIncome = 0;

    // 1. Actual Transactions
    for (final t in widget.transactions) {
      if (t.date.year == date.year &&
          t.date.month == date.month &&
          t.date.day == date.day) {
        final tCurrency = (t.currency ?? '').trim().toUpperCase();
        if (tCurrency.isNotEmpty && tCurrency != widget.currency) continue;

        final amount = t.amountCents.abs() / 100.0;
        final type = (t.type ?? 'expense').toLowerCase();

        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }
    }

    // 2. Recurring Transactions (Projected)
    // Only include if date is today or in the future
    // Or should we include them for past dates if no actual transaction exists?
    // User said "calculates and includes".
    // To avoid double counting, we'll only add recurring if it's in the future relative to now.
    // However, for a "calendar view" of the month, seeing what was *supposed* to happen vs what happened is complex.
    // Simple approach: If date >= today, add recurring.

    final isFutureOrToday =
        !date.isBefore(DateTime(_today.year, _today.month, _today.day));

    if (isFutureOrToday) {
      for (final r in widget.recurringTransactions) {
        if (!r.isActive) continue;
        if (r.currency.toUpperCase() != widget.currency) continue;

        // Check if this recurring transaction occurs on 'date'
        // We use getNextOccurrence from the start of the day
        // If the next occurrence IS this day, then it matches.

        // We need to be careful. getNextOccurrence(date) returns the next one >= date.
        // So if we ask for getNextOccurrence(date) and it returns date, it's a match.
        // But we must ensure we don't match if the *actual* start date of the recurring rule is after 'date'.

        // Also, getNextOccurrence logic in the model might be tricky.
        // Let's rely on the model's logic.

        final next = r.getNextOccurrence(date);
        final isMatch = next.year == date.year &&
            next.month == date.month &&
            next.day == date.day;

        if (isMatch) {
          // Check if this specific occurrence is already covered by an actual transaction?
          // That's hard to know without linking.
          // For now, we add it.

          final amount = r.amount;
          if (r.type.toLowerCase() == 'income') {
            totalIncome += amount;
          } else {
            totalExpense += amount;
          }
        }
      }
    }

    return {'expense': totalExpense, 'income': totalIncome};
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday - 1; // Mon=1 -> 0

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: Icon(Icons.chevron_left, color: colorScheme.foreground),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedMonth),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              IconButton(
                onPressed: _isCurrentMonth ? null : _nextMonth,
                icon: Icon(Icons.chevron_right,
                    color: _isCurrentMonth
                        ? colorScheme.mutedForeground.withValues(alpha: 0.3)
                        : colorScheme.foreground),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday Headers
          Row(
            children:
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85, // More compact
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: daysInMonth + weekdayOffset,
            itemBuilder: (context, index) {
              if (index < weekdayOffset) {
                return const SizedBox.shrink();
              }

              final day = index - weekdayOffset + 1;
              final date =
                  DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final totals = _calculateDailyTotals(date);
              final hasExpense = totals['expense']! > 0;
              final hasIncome = totals['income']! > 0;

              final isToday = date.year == _today.year &&
                  date.month == _today.month &&
                  date.day == _today.day;

              return Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.5))
                      : null,
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.mutedForeground,
                      ),
                    ),
                    const Spacer(),
                    if (hasIncome)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+${NumberFormat.compact().format(totals['income'])}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    if (hasExpense)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '-${NumberFormat.compact().format(totals['expense'])}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
