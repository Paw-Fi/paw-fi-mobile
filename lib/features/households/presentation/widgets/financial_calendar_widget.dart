import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/households/presentation/pages/daily_financial_details_page.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

String _safeCompactFormat(num value, BuildContext context) {
  try {
    final locale = Localizations.localeOf(context);
    final safe = intlSafeLocaleName(locale);
    return NumberFormat.compact(locale: safe).format(value);
  } catch (_) {
    return NumberFormat.compact(locale: 'en_US').format(value);
  }
}

class FinancialCalendarWidget extends ConsumerStatefulWidget {
  final String userId;
  final String? householdId;
  final List<ExpenseEntry> transactions;
  final List<RecurringTransaction> recurringTransactions;
  final String currency;
  final DateTime? initialMonth;
  final bool isExpanded;

  const FinancialCalendarWidget({
    super.key,
    required this.userId,
    this.householdId,
    this.transactions = const [],
    required this.recurringTransactions,
    required this.currency,
    this.initialMonth,
    this.isExpanded = false,
  });

  @override
  ConsumerState<FinancialCalendarWidget> createState() =>
      _FinancialCalendarWidgetState();
}

class _FinancialCalendarWidgetState
    extends ConsumerState<FinancialCalendarWidget> {
  late DateTime _focusedMonth;
  late DateTime _focusedWeekStart;
  final DateTime _today = DateTime.now();

  Map<DateTime, Map<String, double>> _buildRecurringDailyTotals({
    required List<ExpenseEntry> actualTransactions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final merged = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: actualTransactions,
      recurringTransactions: widget.recurringTransactions,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      selectedCurrency: widget.currency,
      includeFutureOccurrences: true,
    );
    final projected = merged
        .where((expense) =>
            extractRecurringTransactionIdFromProjectedExpenseId(expense.id) !=
            null)
        .toList(growable: false);

    final totals = <DateTime, Map<String, double>>{};

    for (final e in projected) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      final entry = totals.putIfAbsent(
          day,
          () => {
                'expense': 0.0,
                'income': 0.0,
              });

      final amount = e.amountCents.abs() / 100.0;
      final type = (e.type ?? 'expense').toLowerCase();
      if (type == 'income') {
        entry['income'] = (entry['income'] ?? 0) + amount;
      } else {
        entry['expense'] = (entry['expense'] ?? 0) + amount;
      }
    }

    return totals;
  }

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.initialMonth ?? DateTime(_today.year, _today.month);
    _focusedWeekStart = DateTime(_today.year, _today.month, _today.day)
        .subtract(const Duration(days: 6));
  }

  DateTime get _todayDateOnly =>
      DateTime(_today.year, _today.month, _today.day);

  bool get _isLatestWeek {
    final endOfWeek = _focusedWeekStart.add(const Duration(days: 6));
    return endOfWeek.isAtSameMomentAs(_todayDateOnly);
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _previousWeek() {
    setState(() {
      _focusedWeekStart = _focusedWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    if (_isLatestWeek) return;
    setState(() {
      _focusedWeekStart = _focusedWeekStart.add(const Duration(days: 7));
    });
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity.abs() < 200) return;

    if (velocity < 0) {
      if (widget.isExpanded) {
        _nextMonth();
      } else {
        _nextWeek();
      }
      return;
    }

    if (widget.isExpanded) {
      _previousMonth();
    } else {
      _previousWeek();
    }
  }

  Map<String, double> _calculateDailyTotals(
    DateTime date, {
    required List<ExpenseEntry> transactions,
    required Map<DateTime, Map<String, double>> recurringDailyTotals,
  }) {
    double totalExpense = 0;
    double totalIncome = 0;

    // 1. Actual Transactions
    for (final t in transactions) {
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

    final dateOnly = DateTime(date.year, date.month, date.day);
    final recurring = recurringDailyTotals[dateOnly];
    if (recurring != null) {
      totalExpense += recurring['expense'] ?? 0;
      totalIncome += recurring['income'] ?? 0;
    }

    return {'expense': totalExpense, 'income': totalIncome};
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final DateTime rangeStart;
    final DateTime rangeEnd;

    if (widget.isExpanded) {
      rangeStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      rangeEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    } else {
      rangeStart = _focusedWeekStart;
      rangeEnd = _focusedWeekStart.add(const Duration(days: 6));
    }

    final query = DashboardScopeQuery(
      userId: widget.userId,
      householdId: widget.householdId,
      selectedCurrency: widget.currency,
      startDate: rangeStart,
      endDate: rangeEnd,
    );
    final transactionsAsync = widget.userId.isEmpty
        ? const AsyncValue<List<ExpenseEntry>>.data(<ExpenseEntry>[])
        : ref.watch(dashboardCalendarTransactionsProvider(query));
    if (transactionsAsync.hasError && !transactionsAsync.hasValue) {
      return _buildCalendarErrorState(context, colorScheme, () {
        ref.invalidate(dashboardCalendarTransactionsProvider(query));
      });
    }
    final resolvedTransactions = mergeDashboardTransactionsWithLocalOverlay(
      base: transactionsAsync.valueOrNull ?? widget.transactions,
      localOverlay: ref.watch(dashboardLocalOverlayTransactionsProvider(query)),
      query: query,
    );
    final recurringDailyTotals = _buildRecurringDailyTotals(
      actualTransactions: resolvedTransactions,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    return GestureDetector(
      onHorizontalDragEnd: _handleHorizontalSwipe,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.homeCardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.homeCardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
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
                    icon:
                        Icon(Icons.chevron_left, color: colorScheme.foreground),
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
                    onPressed: _nextMonth,
                    icon: Icon(Icons.chevron_right,
                        color: colorScheme.foreground),
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
              _buildExpandedView(
                  colorScheme, resolvedTransactions, recurringDailyTotals)
            else
              _buildCollapsedView(
                  colorScheme, resolvedTransactions, recurringDailyTotals),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView(
    ColorScheme colorScheme,
    List<ExpenseEntry> transactions,
    Map<DateTime, Map<String, double>> recurringDailyTotals,
  ) {
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

            return _buildDayCell(
                date, colorScheme, transactions, recurringDailyTotals);
          },
        ),
      ],
    );
  }

  Widget _buildCollapsedView(
    ColorScheme colorScheme,
    List<ExpenseEntry> transactions,
    Map<DateTime, Map<String, double>> recurringDailyTotals,
  ) {
    final last7Days = List.generate(7, (index) {
      return _focusedWeekStart.add(Duration(days: index));
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
                child: _buildDayCell(
                    date, colorScheme, transactions, recurringDailyTotals),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    ColorScheme colorScheme,
    List<ExpenseEntry> transactions,
    Map<DateTime, Map<String, double>> recurringDailyTotals,
  ) {
    final totals = _calculateDailyTotals(
      date,
      transactions: transactions,
      recurringDailyTotals: recurringDailyTotals,
    );
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
              transactions: transactions,
              recurringTransactions: widget.recurringTransactions,
              currency: widget.currency,
              userId: widget.userId,
              householdId: widget.householdId,
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
                  '+${_safeCompactFormat(totals['income'] ?? 0, context)}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.success,
                  ),
                ),
              ),
            if (hasExpense)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '-${_safeCompactFormat(totals['expense'] ?? 0, context)}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.destructive,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildCalendarErrorState(
  BuildContext context,
  ColorScheme colorScheme,
  VoidCallback onRetry,
) {
  return Container(
    decoration: BoxDecoration(
      color: colorScheme.homeCardSurface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: colorScheme.homeCardBorder),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.errorLoadingDashboard,
          style: TextStyle(color: colorScheme.foreground),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
      ],
    ),
  );
}
