import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/dashboard_snapshot_models.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/home/presentation/widgets/transactions_pie_chart.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

String _safeCompactFormat(num value, BuildContext context) {
  try {
    final locale = Localizations.localeOf(context);
    final safe = intlSafeLocaleName(locale);
    return NumberFormat.compact(locale: safe).format(value);
  } catch (_) {
    return NumberFormat.compact(locale: 'en_US').format(value);
  }
}

String _safeLocaleName(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return intlSafeLocaleName(locale);
}

class DailyFinancialDetailsPage extends ConsumerStatefulWidget {
  final DateTime date;
  final List<ExpenseEntry> transactions;
  final List<RecurringTransaction> recurringTransactions;
  final String currency;
  final String userId;
  final String? householdId;

  const DailyFinancialDetailsPage({
    super.key,
    required this.date,
    required this.transactions,
    required this.recurringTransactions,
    required this.currency,
    required this.userId,
    this.householdId,
  });

  @override
  ConsumerState<DailyFinancialDetailsPage> createState() =>
      _DailyFinancialDetailsPageState();
}

class _DailyFinancialDetailsPageState
    extends ConsumerState<DailyFinancialDetailsPage> {
  static const int _initialCalendarPage = 1200;

  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  late final DateTime _baseMonth;
  late final PageController _calendarPageController;
  int _currentCalendarPage = _initialCalendarPage;
  late int _preferredDayOfMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate =
        DateTime(widget.date.year, widget.date.month, widget.date.day);
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _baseMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _preferredDayOfMonth = _selectedDate.day;
    _calendarPageController = PageController(initialPage: _initialCalendarPage);
    _calendarPageController.addListener(_handleCalendarScroll);
  }

  @override
  void dispose() {
    _calendarPageController.removeListener(_handleCalendarScroll);
    _calendarPageController.dispose();
    super.dispose();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _preferredDayOfMonth = date.day;
      _selectedDate = DateTime(date.year, date.month, date.day);
      _focusedMonth = DateTime(date.year, date.month);
    });
  }

  DateTime _monthFromPage(int page) {
    final offset = page - _initialCalendarPage;
    return DateTime(_baseMonth.year, _baseMonth.month + offset);
  }

  DateTime _selectedDateForMonth(DateTime month) {
    final maxDay = DateUtils.getDaysInMonth(month.year, month.month);
    final selectedDay =
        _preferredDayOfMonth > maxDay ? maxDay : _preferredDayOfMonth;
    return DateTime(month.year, month.month, selectedDay);
  }

  void _setCalendarPage(int page) {
    if (page == _currentCalendarPage) {
      return;
    }

    final nextMonth = _monthFromPage(page);
    final nextSelectedDate = _selectedDateForMonth(nextMonth);

    setState(() {
      _currentCalendarPage = page;
      _focusedMonth = DateTime(nextMonth.year, nextMonth.month);
      _selectedDate = nextSelectedDate;
    });
  }

  void _handleCalendarScroll() {
    if (!_calendarPageController.hasClients) {
      return;
    }

    final page = _calendarPageController.page;
    if (page == null) {
      return;
    }

    _setCalendarPage(page.round());
  }

  void _onCalendarPageChanged(int page) => _setCalendarPage(page);

  void _animateCalendarPage(int pageOffset) {
    final currentPage = _calendarPageController.hasClients &&
            _calendarPageController.page != null
        ? _calendarPageController.page!.round()
        : _currentCalendarPage;

    _calendarPageController.animateToPage(
      currentPage + pageOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Map<DateTime, Map<String, double>> _buildRecurringDailyTotals({
    required List<ExpenseEntry> actualTransactions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required List<String>? selectedCurrencies,
    required CurrencyRateTable rates,
  }) {
    final merged = mergeActualExpensesWithProjectedRecurring(
      actualExpenses: actualTransactions,
      recurringTransactions: widget.recurringTransactions,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      selectedCurrency: widget.currency,
      selectedCurrencies: selectedCurrencies,
      includeFutureOccurrences: true,
    );

    final projected = merged
        .where((expense) =>
            extractRecurringTransactionIdFromProjectedExpenseId(expense.id) !=
            null)
        .toList(growable: false);

    final totals = <DateTime, Map<String, double>>{};
    for (final entry in projected) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      final item = totals.putIfAbsent(
        day,
        () => {
          'expense': 0.0,
          'income': 0.0,
        },
      );

      final sourceCurrency =
          (entry.currency ?? widget.currency).trim().toUpperCase();
      final amount = convertAmountCentsToCurrency(
            entry.amountCents.abs(),
            fromCurrency:
                sourceCurrency.isEmpty ? widget.currency : sourceCurrency,
            targetCurrency: widget.currency,
            rates: rates,
          ) /
          100.0;
      final type = (entry.type ?? 'expense').toLowerCase();
      if (type == 'income') {
        item['income'] = (item['income'] ?? 0) + amount;
      } else {
        item['expense'] = (item['expense'] ?? 0) + amount;
      }
    }

    return totals;
  }

  Map<String, double> _calculateDailyTotals(
    DateTime date, {
    required List<ExpenseEntry> transactions,
    required Map<DateTime, Map<String, double>> recurringDailyTotals,
    required CurrencyRateTable rates,
  }) {
    double totalExpense = 0;
    double totalIncome = 0;

    for (final transaction in transactions) {
      if (transaction.date.year == date.year &&
          transaction.date.month == date.month &&
          transaction.date.day == date.day) {
        final transactionCurrency =
            (transaction.currency ?? widget.currency).trim().toUpperCase();
        final amount = convertAmountCentsToCurrency(
              transaction.amountCents.abs(),
              fromCurrency: transactionCurrency.isEmpty
                  ? widget.currency
                  : transactionCurrency,
              targetCurrency: widget.currency,
              rates: rates,
            ) /
            100.0;
        final type = (transaction.type ?? 'expense').toLowerCase();
        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpense += amount;
        }
      }
    }

    final recurring =
        recurringDailyTotals[DateTime(date.year, date.month, date.day)];
    if (recurring != null) {
      totalExpense += recurring['expense'] ?? 0;
      totalIncome += recurring['income'] ?? 0;
    }

    return {'expense': totalExpense, 'income': totalIncome};
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final initialMonth = DateTime(widget.date.year, widget.date.month);

    final query = DashboardScopeQuery(
      userId: widget.userId,
      householdId: widget.householdId,
      selectedCurrency: widget.currency,
      selectedCurrencies: ref.watch(
        homeFilterProvider
            .select((state) => state.normalizedSelectedCurrencies),
      ),
      startDate: monthStart,
      endDate: monthEnd,
    );
    final monthTransactionsAsync = widget.userId.isEmpty
        ? const AsyncValue<List<ExpenseEntry>>.data(<ExpenseEntry>[])
        : ref.watch(dashboardCalendarTransactionsProvider(query));
    final resolvedTransactions = monthTransactionsAsync.valueOrNull ??
        widget.transactions.where((transaction) {
          return transaction.date.year == initialMonth.year &&
              transaction.date.month == initialMonth.month &&
              _focusedMonth.year == initialMonth.year &&
              _focusedMonth.month == initialMonth.month;
        }).toList(growable: false);
    final selectedCurrencies = query.normalizedCurrencies;
    final isMultiCurrencySelection =
        selectedCurrencies != null && selectedCurrencies.length > 1;
    final rates = ref.watch(currencyRateTableProvider).valueOrNull ??
        const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: CurrencyRates.rates,
          isStale: true,
        );
    final aggregateTransactions = isMultiCurrencySelection
        ? convertTransactionsToCurrency(
            resolvedTransactions,
            targetCurrency: widget.currency,
            rates: rates,
          )
        : resolvedTransactions;
    final recurringDailyTotals = _buildRecurringDailyTotals(
      actualTransactions: resolvedTransactions,
      rangeStart: monthStart,
      rangeEnd: monthEnd,
      selectedCurrencies: selectedCurrencies,
      rates: rates,
    );

    // Filter transactions for this specific day
    final dailyTransactions = resolvedTransactions.where((t) {
      final matchesDate = t.date.year == _selectedDate.year &&
          t.date.month == _selectedDate.month &&
          t.date.day == _selectedDate.day;
      if (!matchesDate) return false;
      if (isMultiCurrencySelection) return true;
      return (t.currency ?? '').trim().toUpperCase() == widget.currency;
    }).toList();
    final dailyAggregateTransactions = aggregateTransactions.where((t) {
      return t.date.year == _selectedDate.year &&
          t.date.month == _selectedDate.month &&
          t.date.day == _selectedDate.day;
    }).toList(growable: false);

    final rawProjectedRecurringEntriesForDay =
        mergeActualExpensesWithProjectedRecurring(
      actualExpenses: dailyTransactions,
      recurringTransactions: widget.recurringTransactions,
      rangeStart: _selectedDate,
      rangeEnd: _selectedDate,
      selectedCurrency: widget.currency,
      selectedCurrencies: selectedCurrencies,
      includeFutureOccurrences: true,
    ).where((expense) {
      return extractRecurringTransactionIdFromProjectedExpenseId(expense.id) !=
          null;
    }).toList();
    final projectedRecurringEntriesForDay = isMultiCurrencySelection
        ? convertTransactionsToCurrency(
            rawProjectedRecurringEntriesForDay,
            targetCurrency: widget.currency,
            rates: rates,
          )
        : rawProjectedRecurringEntriesForDay;

    String? tryExtractRecurringId(String syntheticId) {
      final d =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      final key = '$y$m$day';
      const prefix = 'recurring_';
      final suffix = '_$key';

      if (!syntheticId.startsWith(prefix)) return null;
      if (!syntheticId.endsWith(suffix)) return null;

      final endIndex = syntheticId.length - suffix.length;
      if (endIndex <= prefix.length) return null;
      return syntheticId.substring(prefix.length, endIndex);
    }

    final recurringIdsForDay = projectedRecurringEntriesForDay
        .map((e) => tryExtractRecurringId(e.id))
        .whereType<String>()
        .toSet();
    final chartTransactions = [
      ...dailyAggregateTransactions,
      ...projectedRecurringEntriesForDay,
    ];

    // Filter recurring transactions for this specific day
    final dailyRecurring = widget.recurringTransactions
        .where((r) => recurringIdsForDay.contains(r.id))
        .toList();

    // Calculate totals
    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in dailyAggregateTransactions) {
      final amount = t.amountCents.abs() / 100.0;
      if ((t.type ?? 'expense').toLowerCase() == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    for (final e in projectedRecurringEntriesForDay) {
      final amount = e.amountCents.abs() / 100.0;
      if ((e.type ?? 'expense').toLowerCase() == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
    }

    final net = totalIncome - totalExpense;
    final pageTitle =
        DateFormat.yMMMMd(_safeLocaleName(context)).format(_selectedDate);

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: pageTitle,
        useNativeToolbar: false,
      ),
      body: Material(
        child: Container(
          color: colorScheme.appBackground,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  top: 0, left: 12, right: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const horizontalCardPadding = 16.0;
                      const gridSpacing = 3.0;
                      const monthRows = 6;
                      const headerHeight = 35.0;
                      const weekdayHeaderHeight = 18.0;
                      const topBottomPadding = 16.0;
                      const verticalGaps = 12.0;

                      final gridWidth =
                          constraints.maxWidth - horizontalCardPadding;
                      final dayCellWidth = (gridWidth - (gridSpacing * 6)) / 7;
                      final calendarHeight = topBottomPadding +
                          headerHeight +
                          weekdayHeaderHeight +
                          verticalGaps +
                          (dayCellWidth * monthRows) +
                          (gridSpacing * (monthRows - 1));

                      return SizedBox(
                        height: calendarHeight,
                        child: PageView.builder(
                          controller: _calendarPageController,
                          onPageChanged: _onCalendarPageChanged,
                          itemBuilder: (context, page) {
                            final month = _monthFromPage(page);
                            return _DetailsPageCalendarCard(
                              focusedMonth: month,
                              selectedDate: _selectedDate,
                              onPreviousMonth: () => _animateCalendarPage(-1),
                              onNextMonth: () => _animateCalendarPage(1),
                              onSelectDate: _selectDate,
                              calculateDailyTotals: (date) =>
                                  _calculateDailyTotals(
                                date,
                                transactions: aggregateTransactions,
                                recurringDailyTotals: recurringDailyTotals,
                                rates: rates,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryCard(
                          income: totalIncome,
                          expense: totalExpense,
                          net: net,
                          currency: widget.currency,
                        ),
                        const SizedBox(height: 16),
                        if (chartTransactions.any((t) =>
                            (t.type ?? 'expense').toLowerCase() !=
                            'income')) ...[
                          _DailySpendingChart(
                            transactions: chartTransactions,
                            currency: widget.currency,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (dailyTransactions.isNotEmpty) ...[
                          Text(
                            l10n.transactions,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...dailyTransactions.map((t) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
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
                                child: Material(
                                  color: colorScheme.surface
                                      .withValues(alpha: 0.0),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 1),
                                    child: TransactionListTile(
                                      category: t.category ?? 'other',
                                      title: getCategoryTranslation(
                                        context,
                                        t.category ?? 'other',
                                      ),
                                      description: t.rawText,
                                      amount: t.amountCents.abs() / 100.0,
                                      currency: t.currency ?? widget.currency,
                                      isIncome:
                                          (t.type ?? 'expense').toLowerCase() ==
                                              'income',
                                      date: t.date,
                                      onTap: () {
                                        showUnifiedTransactionSheet(
                                          context,
                                          existingExpense: t,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (dailyRecurring.isNotEmpty) ...[
                          Text(
                            l10n.recurring,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...dailyRecurring.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _RecurringTransactionTile(
                                  transaction: r,
                                  currency: widget.currency,
                                ),
                              )),
                        ],
                        if (dailyTransactions.isEmpty && dailyRecurring.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                l10n.noTransactionsFound,
                                style: TextStyle(
                                    color: colorScheme.mutedForeground),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class _DetailsPageCalendarCard extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;
  final Map<String, double> Function(DateTime date) calculateDailyTotals;

  const _DetailsPageCalendarCard({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.calculateDailyTotals,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeLocale = _safeLocaleName(context);
    final daysInMonth =
        DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday - 1;

    final weekdayHeaders = List.generate(7, (index) {
      final weekdayDate = DateTime(2024, 1, 1).add(Duration(days: index));
      return DateFormat.E(safeLocale).format(weekdayDate);
    });

    return Container(
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
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: Icon(Icons.chevron_left, color: colorScheme.foreground),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                DateFormat('MMMM yyyy', safeLocale).format(focusedMonth),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: Icon(Icons.chevron_right, color: colorScheme.foreground),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: weekdayHeaders
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: daysInMonth + weekdayOffset,
            itemBuilder: (context, index) {
              if (index < weekdayOffset) {
                return const SizedBox.shrink();
              }

              final day = index - weekdayOffset + 1;
              final date = DateTime(focusedMonth.year, focusedMonth.month, day);
              final totals = calculateDailyTotals(date);
              final hasIncome = (totals['income'] ?? 0) > 0;
              final hasExpense = (totals['expense'] ?? 0) > 0;
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;

              return GestureDetector(
                onTap: () => onSelectDate(date),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.1)
                        : colorScheme.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
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
                            '+${_safeCompactFormat(totals['income'] ?? 0, context)}',
                            style: TextStyle(
                              fontSize: 8,
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
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.destructive,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _formatLocalizedCurrency(
  BuildContext context,
  double amount,
  String currency,
) {
  final normalized = double.parse(formatAmount(amount));
  final symbol = resolveCurrencySymbol(currency);
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}

class _SummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final String currency;

  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.net,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final netColor = net > 0
        ? AppTheme.success
        : net < 0
            ? AppTheme.danger
            : colorScheme.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: context.l10n.income,
                  amount: income,
                  currency: currency,
                  color: AppTheme.success,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: context.l10n.expenses,
                  amount: expense,
                  currency: currency,
                  color: AppTheme.danger,
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: context.l10n.net,
                  amount: net,
                  currency: currency,
                  color: netColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color color;

  const _StatItem({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatLocalizedCurrency(context, amount, currency),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecurringTransactionTile extends StatelessWidget {
  final RecurringTransaction transaction;
  final String currency;

  const _RecurringTransactionTile({
    required this.transaction,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = transaction.type == 'income';

    return Container(
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
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: TransactionListTile(
            category: transaction.category,
            title: transaction.description ??
                getCategoryTranslation(context, transaction.category),
            description: transaction.description,
            date: transaction.date,
            amount: transaction.amount,
            currency: transaction.currency,
            isIncome: isIncome,
            subtitleWidget: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    getLocalizedFrequencyText(context, transaction),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    formatLocalizedDate(
                        context, transaction.getNextOccurrence()),
                    style: TextStyle(
                      color: colorScheme.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _DailySpendingChart extends StatelessWidget {
  final List<ExpenseEntry> transactions;
  final String currency;

  const _DailySpendingChart({
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter for expenses only
    final expenses = transactions.where((t) {
      final type = (t.type ?? 'expense').toLowerCase();
      return type != 'income';
    }).toList();

    if (expenses.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.spendingBreakdown.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          TransactionsPieChart(
            colorScheme: colorScheme,
            expenses: expenses,
            selectedCurrency: currency,
            periodLabel: context.l10n.today,
          ),
        ],
      ),
    );
  }
}
