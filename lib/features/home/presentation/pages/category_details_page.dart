import 'dart:async';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/state/date_range_utils.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/utils/transaction_display_datetime.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/home/presentation/utils/transactions_page_derived_data.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';

class CategoryDetailsPage extends ConsumerStatefulWidget {
  final String categoryKey;
  final String? currency;
  final DateRangeFilter? initialDateFilter;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const CategoryDetailsPage({
    super.key,
    required this.categoryKey,
    this.currency,
    this.initialDateFilter,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  ConsumerState<CategoryDetailsPage> createState() =>
      _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends ConsumerState<CategoryDetailsPage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _dateFilterScrollController = ScrollController();
  final GlobalKey _dateFilterScrollViewKey = GlobalKey();
  final Map<DateRangeFilter, GlobalKey> _dateFilterChipKeys = {
    for (final filter in _dateFilterOptions) filter: GlobalKey(),
  };
  bool _didScrollInitialDateFilterIntoView = false;

  late DateRangeFilter _selectedDateFilter;
  DateTime? _customStart;
  DateTime? _customEnd;

  static const _dateFilterOptions = [
    DateRangeFilter.last7Days,
    DateRangeFilter.today,
    DateRangeFilter.yesterday,
    DateRangeFilter.thisWeek,
    DateRangeFilter.lastWeek,
    DateRangeFilter.thisMonth,
    DateRangeFilter.lastMonth,
    DateRangeFilter.last3Months,
    DateRangeFilter.last30Days,
    DateRangeFilter.thisYear,
    DateRangeFilter.allTime,
    DateRangeFilter.custom,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDateFilter != null) {
      _selectedDateFilter = widget.initialDateFilter!;
      if (_selectedDateFilter == DateRangeFilter.custom &&
          widget.initialStartDate != null &&
          widget.initialEndDate != null) {
        _customStart = widget.initialStartDate;
        _customEnd = widget.initialEndDate;
      } else {
        _customStart = null;
        _customEnd = null;
      }
    } else if (widget.initialStartDate != null &&
        widget.initialEndDate != null) {
      _selectedDateFilter = DateRangeFilter.custom;
      _customStart = widget.initialStartDate;
      _customEnd = widget.initialEndDate;
    } else {
      _selectedDateFilter = DateRangeFilter.thisMonth;
    }

    _scrollController.addListener(_onScroll);
    _scheduleInitialDateFilterScroll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dateFilterScrollController.dispose();
    super.dispose();
  }

  void _scheduleInitialDateFilterScroll() {
    if (_didScrollInitialDateFilterIntoView) {
      return;
    }
    _didScrollInitialDateFilterIntoView = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSelectedDateFilterIntoView();
    });
  }

  void _scrollSelectedDateFilterIntoView() {
    if (!mounted || !_dateFilterScrollController.hasClients) {
      return;
    }

    final chipContext =
        _dateFilterChipKeys[_selectedDateFilter]?.currentContext;
    final scrollContext = _dateFilterScrollViewKey.currentContext;
    if (chipContext == null || scrollContext == null) {
      return;
    }

    final chipBox = chipContext.findRenderObject() as RenderBox?;
    final scrollBox = scrollContext.findRenderObject() as RenderBox?;
    if (chipBox == null || scrollBox == null) {
      return;
    }

    final chipLeft = chipBox.localToGlobal(Offset.zero).dx;
    final scrollLeft = scrollBox.localToGlobal(Offset.zero).dx;
    final targetOffset = (_dateFilterScrollController.offset +
            chipLeft -
            scrollLeft -
            (scrollBox.size.width - chipBox.size.width) / 2)
        .clamp(0.0, _dateFilterScrollController.position.maxScrollExtent)
        .toDouble();

    _dateFilterScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onScroll() {
    // Basic pagination trigger
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final query = _buildFeedQuery();
      final feedState = ref.read(transactionsFeedProvider(query));
      if (feedState.hasMore && !feedState.isLoadingMore) {
        ref.read(transactionsFeedProvider(query).notifier).loadMore();
      }
    }
  }

  TransactionsFeedQuery _buildFeedQuery() {
    final currentUserId = ref.watch(authProvider).uid;
    final householdScope = ref.watch(householdScopeProvider);
    final effectiveHouseholdId =
        householdScope.activeAccountType == ActiveWalletType.personal
            ? null
            : householdScope.activeAccountHouseholdId;
    final filterState = ref.watch(homeFilterProvider);
    final userNow = effectiveNow(
      preferredTimezone: ref.watch(analyticsProvider
          .select((state) => state.contact?.preferredTimezone)),
    );

    DateTime? queryStartDate = _customStart;
    DateTime? queryEndDate = _customEnd;

    if (_selectedDateFilter != DateRangeFilter.custom &&
        _selectedDateFilter != DateRangeFilter.allTime) {
      final range = getDateRangeFromFilter(
        _selectedDateFilter,
        null,
        null,
        now: userNow,
      );
      queryStartDate = range['from'];
      queryEndDate = range['to'];
    } else if (_selectedDateFilter == DateRangeFilter.allTime) {
      queryStartDate = null;
      queryEndDate = null;
    }

    return TransactionsFeedQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: filterState.selectedCurrency,
      selectedCurrencies: filterState.normalizedSelectedCurrencies,
      selectedCategory: widget.categoryKey,
      selectedType: 'expense',
      searchQuery: '',
      startDate: queryStartDate,
      endDate: queryEndDate,
    );
  }

  Future<void> _refreshData() async {
    final query = _buildFeedQuery();
    await ref.read(transactionsFeedProvider(query).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryName = getCategoryTranslation(context, widget.categoryKey);

    final query = _buildFeedQuery();
    final feedState = ref.watch(transactionsFeedProvider(query));
    final isMultiCurrencySelection =
        (query.normalizedSelectedCurrencies?.length ?? 0) > 1;
    final allItemsAsync = isMultiCurrencySelection
        ? ref.watch(transactionsFeedAllItemsProvider(query))
        : null;
    final rateTable = ref.watch(currencyRateTableProvider).valueOrNull ??
        const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: CurrencyRates.rates,
          isStale: true,
        );
    final currentUserId = ref.watch(authProvider.select((state) => state.uid));
    final contact =
        ref.watch(analyticsProvider.select((state) => state.contact));
    final householdScope = ref.watch(householdScopeProvider);
    final recurringScopeHouseholdId =
        householdScope.activeAccountType == ActiveWalletType.personal
            ? null
            : householdScope.activeAccountHouseholdId;
    final recurringTransactions = ref
            .watch(recurringTransactionsProvider(recurringScopeHouseholdId))
            .data
            .valueOrNull ??
        const [];
    final userNow = effectiveNow(
      preferredTimezone: contact?.preferredTimezone,
    );

    final projectedRecurring = recurringTransactions.isEmpty
        ? const <ExpenseEntry>[]
        : projectRecurringTransactionsAsExpenseEntries(
            recurringTransactions: recurringTransactions,
            rangeStart: DateTime(2000),
            rangeEnd: userNow,
            selectedCurrency: query.selectedCurrency,
            selectedCurrencies: query.normalizedCurrencies,
          );
    final normalizedCategory = widget.categoryKey.trim().toLowerCase();
    final projectedRecurringInCategory = projectedRecurring.where((expense) {
      if ((expense.type ?? 'expense').toLowerCase() == 'income') {
        return false;
      }
      final expenseCategory =
          (expense.category ?? 'uncategorized').trim().toLowerCase();
      if (expenseCategory != normalizedCategory) {
        return false;
      }
      final dateOnly =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
      if (query.startDate != null &&
          dateOnly.isBefore(DateTime(query.startDate!.year,
              query.startDate!.month, query.startDate!.day))) {
        return false;
      }
      if (query.endDate != null &&
          dateOnly.isAfter(DateTime(
              query.endDate!.year, query.endDate!.month, query.endDate!.day))) {
        return false;
      }
      return true;
    }).toList();

    final dedupedProjectedRecurringInCategory =
        dedupeProjectedRecurringExpenseEntries(
      projectedExpenses: projectedRecurringInCategory,
      actualExpenses: feedState.items,
    );

    final expenses = [
      ...feedState.items,
      ...dedupedProjectedRecurringInCategory,
    ]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.createdAt.compareTo(a.createdAt);
      });

    // Derived states
    final monthGroups = groupTransactionsByMonth(expenses);
    final renderItems = buildVisibleTransactionRenderItems(
      monthGroups: monthGroups,
      visibleExpenseCount: expenses.length,
    );

    final aggregateActualExpenses =
        allItemsAsync?.valueOrNull ?? const <ExpenseEntry>[];
    final aggregateExpenses = isMultiCurrencySelection
        ? [
            ...aggregateActualExpenses,
            ...dedupeProjectedRecurringExpenseEntries(
              projectedExpenses: projectedRecurringInCategory,
              actualExpenses: aggregateActualExpenses,
            ),
          ]
        : expenses;
    final aggregateSummary = isMultiCurrencySelection
        ? summarizeTransactionsInCurrency(
            aggregateExpenses,
            targetCurrency: query.selectedCurrency ?? 'USD',
            rates: rateTable,
          )
        : feedState.summary.addingExpenses(dedupedProjectedRecurringInCategory);
    final totalSpent = aggregateSummary.expenseTotal.abs();
    final count = aggregateSummary.transactionCount;
    final avg = count > 0 ? totalSpent / count : 0.0;

    // Top merchant
    final Map<String, double> merchantTally = {};
    final convertedAggregateExpenses = isMultiCurrencySelection
        ? convertTransactionsToCurrency(
            aggregateExpenses,
            targetCurrency: query.selectedCurrency ?? 'USD',
            rates: rateTable,
          )
        : aggregateExpenses;
    for (final e in convertedAggregateExpenses) {
      final merchant = (e.merchant ?? e.rawText ?? '').trim();
      if (merchant.isNotEmpty) {
        merchantTally[merchant] =
            (merchantTally[merchant] ?? 0) + e.amount.abs();
      }
    }

    final sortedMerchants = merchantTally.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topMerchant =
        sortedMerchants.isNotEmpty ? sortedMerchants.first : null;

    final symbol = resolveCurrencySymbol(query.selectedCurrency ?? 'USD');

    return AdaptiveScaffold(
      body: Material(
        color: colorScheme.appleGroupedBackground,
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: colorScheme.surface,
                title: Text(
                  categoryName,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Filters sticky bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyFilterDelegate(
                  child: Container(
                    color: colorScheme.surface,
                    child: _buildDateFilterChips(colorScheme),
                  ),
                ),
              ),

              if (isMultiCurrencySelection &&
                  allItemsAsync?.valueOrNull == null &&
                  (allItemsAsync?.hasError ?? false))
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.errorLoadingDashboard,
                          style: TextStyle(color: colorScheme.foreground),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            transactionsFeedAllItemsProvider(query),
                          ),
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              else if ((feedState.isLoading && expenses.isEmpty) ||
                  (isMultiCurrencySelection &&
                      allItemsAsync?.valueOrNull == null &&
                      (allItemsAsync?.isLoading ?? false)))
                SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: colorScheme.primary),
                  ),
                )
              else ...[
                // Summary Block
                SliverToBoxAdapter(
                  child: _buildSummaryBlock(
                    colorScheme: colorScheme,
                    categoryName: categoryName,
                    symbol: symbol,
                    totalSpent: totalSpent,
                    count: count,
                    avg: avg,
                    topMerchant: topMerchant,
                  ),
                ),

                // Mini Insight Cards
                if (expenses.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Row(
                        children: [
                          Expanded(
                              child: _buildTrendMiniChart(
                                  colorScheme, monthGroups)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _buildMerchantSplitCard(
                                  colorScheme, sortedMerchants, symbol)),
                        ],
                      ),
                    ),
                  ),

                // Ledger
                if (expenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          context.l10n.noData,
                          style: TextStyle(color: colorScheme.mutedForeground),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = renderItems[index];

                        if (item.isMonthHeader) {
                          return _buildMonthHeader(
                              context, item.monthGroup!, colorScheme);
                        }
                        if (item.isDayHeader) {
                          return _buildDayHeader(
                              context, item.dayGroup!, colorScheme);
                        }

                        return _buildTransactionRow(
                          context,
                          item.expense!,
                          contact,
                          colorScheme,
                          currentUserId: currentUserId,
                          isFirst: item.isFirst,
                          isLast: item.isLast,
                        );
                      },
                      childCount: renderItems.length,
                    ),
                  ),

                PaginatedLoadMoreSliverIndicator(show: feedState.isLoadingMore),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBlock({
    required ColorScheme colorScheme,
    required String categoryName,
    required String symbol,
    required double totalSpent,
    required int count,
    required double avg,
    required MapEntry<String, double>? topMerchant,
  }) {
    final color = getCategoryColor(widget.categoryKey);
    final icon = getCategoryIcon(widget.categoryKey);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$symbol${formatLocalizedNumber(context, totalSpent)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryStatItem(
                label: 'COUNT',
                value: '$count',
                colorScheme: colorScheme,
              ),
              _SummaryStatItem(
                label: 'AVERAGE',
                value: '$symbol${formatLocalizedNumber(context, avg)}',
                colorScheme: colorScheme,
              ),
              _SummaryStatItem(
                label: 'TOP MERCHANT',
                value: topMerchant != null ? topMerchant.key : '-',
                colorScheme: colorScheme,
                crossAxisAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendMiniChart(
      ColorScheme colorScheme, List<MonthTransactionGroup> monthGroups) {
    if (monthGroups.isEmpty) return const SizedBox.shrink();

    // Reverse to chronological order
    final chronologicalGroups = monthGroups.reversed.toList();

    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 40,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                minY: 0,
                barGroups: chronologicalGroups.asMap().entries.map((e) {
                  final val = e.value.total.abs();
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: getCategoryColor(widget.categoryKey),
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantSplitCard(ColorScheme colorScheme,
      List<MapEntry<String, double>> topMerchants, String symbol) {
    final top3 = topMerchants.take(3).toList();

    return Container(
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Merchants',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          if (top3.isEmpty)
            Expanded(
                child: Center(
                    child: Text('-',
                        style: TextStyle(color: colorScheme.mutedForeground))))
          else
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: top3.map((e) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.foreground,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '$symbol${formatLocalizedNumber(context, e.value)}',
                        style: TextStyle(
                            fontSize: 11, color: colorScheme.mutedForeground),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChips(ColorScheme colorScheme) {
    const filters = [
      DateRangeFilter.last7Days,
      DateRangeFilter.today,
      DateRangeFilter.yesterday,
      DateRangeFilter.thisWeek,
      DateRangeFilter.lastWeek,
      DateRangeFilter.thisMonth,
      DateRangeFilter.lastMonth,
      DateRangeFilter.last3Months,
      DateRangeFilter.last30Days,
      DateRangeFilter.thisYear,
      DateRangeFilter.allTime,
      DateRangeFilter.custom,
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        key: _dateFilterScrollViewKey,
        controller: _dateFilterScrollController,
        cacheExtent: 10000,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedDateFilter == filter;

          String label;
          if (filter == DateRangeFilter.custom &&
              _customStart != null &&
              _customEnd != null &&
              isSelected) {
            final fmt = DateFormat('MMM d');
            label = '${fmt.format(_customStart!)} – ${fmt.format(_customEnd!)}';
          } else {
            label = filter.getLabel(context);
          }

          return GestureDetector(
            key: _dateFilterChipKeys[filter],
            onTap: () async {
              if (filter == DateRangeFilter.custom) {
                final result = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDateRange: _customStart != null && _customEnd != null
                      ? DateTimeRange(start: _customStart!, end: _customEnd!)
                      : null,
                );
                if (result != null) {
                  setState(() {
                    _selectedDateFilter = DateRangeFilter.custom;
                    _customStart = result.start;
                    _customEnd = result.end;
                  });
                }
              } else {
                setState(() {
                  _selectedDateFilter = filter;
                  _customStart = null;
                  _customEnd = null;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : colorScheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.border.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.primaryForeground
                      : colorScheme.foreground,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Same helpers as transactions_page.dart
  Widget _buildMonthHeader(BuildContext context, MonthTransactionGroup group,
      ColorScheme colorScheme) {
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat('MMMM yyyy', locale).format(group.monthStart);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        dateLabel,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.mutedForeground,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, DayTransactionGroup group,
      ColorScheme colorScheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(group.date.year, group.date.month, group.date.day);
    String dateLabel;

    if (date == today) {
      dateLabel = context.l10n.today;
    } else if (date == yesterday) {
      dateLabel = context.l10n.yesterday;
    } else {
      final locale = Localizations.localeOf(context).toString();
      dateLabel = DateFormat('MMM d', locale).format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
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
        ],
      ),
    );
  }

  Widget _buildTransactionRow(
    BuildContext context,
    ExpenseEntry item,
    UserContact? contact,
    ColorScheme colorScheme, {
    required String currentUserId,
    required bool isFirst,
    required bool isLast,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(24) : Radius.zero,
      bottom: isLast ? const Radius.circular(24) : Radius.zero,
    );
    final shouldShadow = isFirst || isLast;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, isLast ? 16 : 0),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: radius,
        boxShadow:
            Theme.of(context).brightness == Brightness.dark || !shouldShadow
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
      child: buildExpenseTransactionTile(
        context: context,
        category: item.category ?? 'uncategorized',
        rawText: item.rawText,
        date: composeTransactionDisplayDateTime(
          transactionDate: item.date,
          createdAt: item.createdAt,
          preferredTimezone: contact?.preferredTimezone,
        ),
        amount: item.amount,
        currency: item.currency ?? 'USD',
        isIncome: (item.type ?? 'expense').toLowerCase() == 'income',
        showYouLabel: item.userId != null && item.userId == currentUserId,
        onTap: () {
          if (extractRecurringTransactionIdFromProjectedExpenseId(item.id) !=
              null) {
            return;
          }
          unawaited(
            showUnifiedTransactionSheet(
              context,
              existingExpense: item,
              contact: contact,
            ).then((_) => _refreshData()),
          );
        },
      ),
    );
  }
}

class _SummaryStatItem extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final CrossAxisAlignment crossAxisAlignment;

  const _SummaryStatItem({
    required this.label,
    required this.value,
    required this.colorScheme,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colorScheme.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyFilterDelegate({required this.child});

  @override
  double get minExtent => 52.0;

  @override
  double get maxExtent => 52.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) {
    return true;
  }
}
