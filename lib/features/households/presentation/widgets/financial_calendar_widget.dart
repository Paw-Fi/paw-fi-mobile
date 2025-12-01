import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/households/presentation/pages/daily_financial_details_page.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

class FinancialCalendarWidget extends StatefulWidget {
  final List<ExpenseEntry> transactions;
  final List<RecurringTransaction> recurringTransactions;
  final String currency;
  final DateTime? initialMonth;
  final bool isExpanded;

  const FinancialCalendarWidget({
    super.key,
    required this.transactions,
    required this.recurringTransactions,
    required this.currency,
    this.initialMonth,
    this.isExpanded = false,
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
    final isFutureOrToday =
        !date.isBefore(DateTime(_today.year, _today.month, _today.day));

    if (isFutureOrToday) {
      for (final r in widget.recurringTransactions) {
        if (!r.isActive) continue;
        if (r.currency.toUpperCase() != widget.currency) continue;

        final next = r.getNextOccurrence(date);
        final isMatch = next.year == date.year &&
            next.month == date.month &&
            next.day == date.day;

        if (isMatch) {
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
              if (widget.isExpanded) ...[
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
              ] else
                const Spacer(),
            ],
          ),
          if (widget.isExpanded) const SizedBox(height: 8),

          if (widget.isExpanded)
            _buildExpandedView(colorScheme)
          else
            _buildCollapsedView(colorScheme),
        ],
      ),
    );
  }

  Widget _buildExpandedView(ColorScheme colorScheme) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday - 1; // Mon=1 -> 0

    return Column(
      children: [
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
            final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);

            return _buildDayCell(date, colorScheme);
          },
        ),
      ],
    );
  }

  Widget _buildCollapsedView(ColorScheme colorScheme) {
    final last7Days = List.generate(7, (index) {
      return _today.subtract(Duration(days: 6 - index));
    });

    return Row(
      children: last7Days.map((date) {
        return Expanded(
          child: Column(
            children: [
              Text(
                DateFormat.E().format(date),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              AspectRatio(
                aspectRatio: 0.85,
                child: _buildDayCell(date, colorScheme),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayCell(DateTime date, ColorScheme colorScheme) {
    final totals = _calculateDailyTotals(date);
    final hasExpense = totals['expense']! > 0;
    final hasIncome = totals['income']! > 0;

    final isToday = date.year == _today.year &&
        date.month == _today.month &&
        date.day == _today.day;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DailyFinancialDetailsPage(
              date: date,
              transactions: widget.transactions,
              recurringTransactions: widget.recurringTransactions,
              currency: widget.currency,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.muted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color:
                    isToday ? colorScheme.primary : colorScheme.mutedForeground,
              ),
            ),
            const Spacer(),
            if (hasIncome)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '+${NumberFormat.compact().format(totals['income'])}',
                  style: const TextStyle(
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
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
