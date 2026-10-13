import 'dart:async';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';
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
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/utils/transaction_display_datetime.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/home/presentation/utils/transaction_row_display_entry.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/home/presentation/utils/transactions_page_derived_data.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:moneko/shared/widgets/transaction_details_sheet_router.dart';

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
  _CategoryRenderCacheKey? _renderCacheKey;
  _CategoryRenderCacheResult? _cachedRenderResult;

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
    final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);

    DateTime? queryStartDate = _customStart;
    DateTime? queryEndDate = _customEnd;

    if (_selectedDateFilter != DateRangeFilter.custom &&
        _selectedDateFilter != DateRangeFilter.allTime) {
      final range = getDateRangeFromFilter(
        _selectedDateFilter,
        null,
        null,
        now: userNow,
        financialMonthStartDay: financialMonthStartDay,
      );
      queryStartDate = range['from'];
      queryEndDate = range['to'];
    } else if (_selectedDateFilter == DateRangeFilter.allTime) {
      queryStartDate = null;
      queryEndDate = null;
    }

    final categoryFilters = categoryFeedFilterValuesForKey(widget.categoryKey);

    return TransactionsFeedQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: filterState.selectedCurrency,
      selectedCurrencies: filterState.normalizedSelectedCurrencies,
      selectedCategory: null,
      selectedCategories: categoryFilters,
      selectedType: 'expense',
      searchQuery: '',
      startDate: queryStartDate,
      endDate: queryEndDate,
    );
  }

  Future<void> _refreshData() async {
    final query = _buildFeedQuery();
    await ref.read(transactionsFeedProvider(query).notifier).refresh();
    if (!mounted) return;
    ref.invalidate(transactionsFeedAllItemsProvider(query));
  }

  _CategoryRenderCacheResult _resolveRenderItems({
    required List<ExpenseEntry> displayExpenses,
    required List<MonthTransactionGroup> monthGroups,
  }) {
    final cacheKey = _CategoryRenderCacheKey(
      displayExpensesSignature: _expenseEntriesSignature(displayExpenses),
    );

    if (_cachedRenderResult != null && _renderCacheKey == cacheKey) {
      return _cachedRenderResult!;
    }

    final items = buildVisibleTransactionRenderItems(
      monthGroups: monthGroups,
      visibleExpenseCount: displayExpenses.length,
    );
    final result = _CategoryRenderCacheResult(
      items: items,
      indexByKey: buildTransactionRenderItemIndexByKey(items),
    );
    _renderCacheKey = cacheKey;
    _cachedRenderResult = result;
    return result;
  }

  int _expenseEntriesSignature(List<ExpenseEntry> expenses) {
    return transactionEntriesContentSignature(expenses);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryName = getCategoryTranslation(context, widget.categoryKey);
    final financialMonthStartDay = ref.watch(financialMonthStartDayProvider);

    final query = _buildFeedQuery();
    final feedState = ref.watch(transactionsFeedProvider(query));
    final isMultiCurrencySelection =
        (query.normalizedSelectedCurrencies?.length ?? 0) > 1;
    final rateTable = ref.watch(currencyRateTableProvider).valueOrNull ??
        const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: CurrencyRates.rates,
          isStale: true,
        );
    final convertedRollupSummary = isMultiCurrencySelection
        ? summarizeTransactionRollupsInCurrency(
            feedState.summary,
            targetCurrency: query.selectedCurrency ?? 'USD',
            rates: rateTable,
          )
        : null;
    final shouldLoadCompleteAggregateRows =
        isMultiCurrencySelection && convertedRollupSummary == null;
    final allItemsAsync = shouldLoadCompleteAggregateRows
        ? ref.watch(transactionsFeedAllItemsProvider(query))
        : null;
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
    final recurringTransactionsById = {
      for (final transaction in recurringTransactions)
        transaction.id: transaction,
    };
    final occurrenceResolution = ref.watch(
      recurringOccurrenceProjectionResolutionProvider(
        RecurringOccurrenceProjectionResolutionQuery(
          userId: currentUserId,
          householdId: recurringScopeHouseholdId,
          startDate: query.startDate ?? DateTime(2000),
          endDate: query.endDate ?? userNow,
        ),
      ),
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
    final categoryFilterSet = categoryFeedFilterValuesForKey(widget.categoryKey)
        .map((category) => category.trim().toLowerCase())
        .toSet();
    final projectedRecurringInCategory = projectedRecurring.where((expense) {
      if ((expense.type ?? 'expense').toLowerCase() == 'income') {
        return false;
      }
      final expenseCategory =
          (expense.category ?? 'uncategorized').trim().toLowerCase();
      if (!categoryFilterSet.contains(expenseCategory)) {
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
    final occurrenceSuppressionEntries =
        occurrenceResolution.suppressionEntries;

    final dedupedProjectedRecurringInCategory =
        dedupeProjectedRecurringExpenseEntries(
      projectedExpenses: projectedRecurringInCategory,
      actualExpenses: [
        ...feedState.items,
        ...occurrenceSuppressionEntries,
      ],
    );

    final expenses = [
      ...feedState.items,
      ...dedupedProjectedRecurringInCategory,
    ]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.createdAt.compareTo(a.createdAt);
      });
    final expensesById = {
      for (final expense in expenses) expense.id: expense,
    };
    final displayExpenses = isMultiCurrencySelection
        ? convertTransactionsToCurrency(
            expenses,
            targetCurrency: query.selectedCurrency ?? 'USD',
            rates: rateTable,
          )
        : expenses;

    final monthGroups = groupTransactionsByMonth(
      displayExpenses,
      financialMonthStartDay: financialMonthStartDay,
    );
    final renderResult = _resolveRenderItems(
      displayExpenses: displayExpenses,
      monthGroups: monthGroups,
    );
    final renderItems = renderResult.items;
    final renderItemIndexByKey = renderResult.indexByKey;

    final aggregateActualExpenses =
        allItemsAsync?.valueOrNull ?? const <ExpenseEntry>[];
    final aggregateExpenses = shouldLoadCompleteAggregateRows
        ? [
            ...aggregateActualExpenses,
            ...dedupeProjectedRecurringExpenseEntries(
              projectedExpenses: projectedRecurringInCategory,
              actualExpenses: [
                ...aggregateActualExpenses,
                ...occurrenceSuppressionEntries,
              ],
            ),
          ]
        : expenses;
    final aggregateSummary = isMultiCurrencySelection
        ? convertedRollupSummary == null
            ? summarizeTransactionsInCurrency(
                aggregateExpenses,
                targetCurrency: query.selectedCurrency ?? 'USD',
                rates: rateTable,
              )
            : addConvertedExpensesToSummary(
                convertedRollupSummary,
                dedupedProjectedRecurringInCategory,
                targetCurrency: query.selectedCurrency ?? 'USD',
                rates: rateTable,
              )
        : feedState.summary.addingExpenses(dedupedProjectedRecurringInCategory);
    final totalSpent = aggregateSummary.expenseTotal.abs();
    final count = aggregateSummary.transactionCount;
    final avg = count > 0 ? totalSpent / count : 0.0;

    // Top merchant
    final Map<String, double> merchantTally = {};
    final convertedAggregateExpenses = shouldLoadCompleteAggregateRows
        ? convertTransactionsToCurrency(
            aggregateExpenses,
            targetCurrency: query.selectedCurrency ?? 'USD',
            rates: rateTable,
          )
        : displayExpenses;
    for (final e in convertedAggregateExpenses) {
      final merchant = (e.merchant ?? e.rawText ?? '').trim();
      if (merchant.isNotEmpty) {
        merchantTally[merchant] =
            (merchantTally[merchant] ?? 0) + e.amount.abs();
      }
    }
    final aggregateMonthGroups = groupTransactionsByMonth(
      convertedAggregateExpenses,
      financialMonthStartDay: financialMonthStartDay,
    );

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
            key:
                PageStorageKey('category_details_scroll_${widget.categoryKey}'),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: colorScheme.surface,
                title: Text(
                  categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
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

              if (shouldLoadCompleteAggregateRows &&
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
                  (shouldLoadCompleteAggregateRows &&
                      allItemsAsync?.valueOrNull == null &&
                      (allItemsAsync?.isLoading ?? false)))
                const SliverFillRemaining(
                  child: AsyncDataSkeleton(rowCount: 5),
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
                if (expenses.isNotEmpty || feedState.isLoading)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final showSingleColumn = constraints.maxWidth < 360 ||
                              MediaQuery.textScalerOf(context).scale(14) > 17;
                          final trend = _buildTrendMiniChart(
                            colorScheme,
                            aggregateMonthGroups,
                            isLoading: feedState.isLoading,
                          );
                          final merchants = _buildMerchantSplitCard(
                              colorScheme, sortedMerchants, symbol);
                          if (showSingleColumn) {
                            return Column(
                              children: [
                                trend,
                                const SizedBox(height: 12),
                                merchants,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: trend),
                              const SizedBox(width: 12),
                              Expanded(child: merchants),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                // Ledger
                if (expenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: feedState.isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                context.l10n.noData,
                                style: TextStyle(
                                    color: colorScheme.mutedForeground),
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
                            context,
                            item.monthGroup!,
                            colorScheme,
                            key: ValueKey(item.key),
                          );
                        }
                        if (item.isDayHeader) {
                          return _buildDayHeader(
                            context,
                            item.dayGroup!,
                            colorScheme,
                            key: ValueKey(item.key),
                          );
                        }

                        final displayExpense =
                            resolveTransactionRowDisplayEntry(
                          item.expense!,
                          expensesById,
                        );
                        return _buildTransactionRow(
                          context,
                          displayExpense,
                          contact,
                          colorScheme,
                          key: ValueKey(item.key),
                          originalItem: displayExpense,
                          currentUserId: currentUserId,
                          recurringTransactionsById: recurringTransactionsById,
                          occurrenceResolution: occurrenceResolution,
                          isFirst: item.isFirst,
                          isLast: item.isLast,
                        );
                      },
                      childCount: renderItems.length,
                      findChildIndexCallback: (key) {
                        final valueKey = key;
                        if (valueKey is! ValueKey<String>) {
                          return null;
                        }
                        return renderItemIndexByKey[valueKey.value];
                      },
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
    final color = getCategoryColor(widget.categoryKey, context);
    final icon = buildCategoryIcon(widget.categoryKey, size: 24);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.homeCardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.homeCardBorder),
          boxShadow: colorScheme.groupedCardShadows,
        ),
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
                  child: icon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$symbol${formatLocalizedNumber(context, totalSpent)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WidgetTextStyles.roundedNumber(
                          Theme.of(context),
                          baseStyle: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(
                height: 1, color: colorScheme.outline.withValues(alpha: .2)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryStatItem(
                    label: 'COUNT',
                    value: '$count',
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryStatItem(
                    label: 'AVERAGE',
                    value: '$symbol${formatLocalizedNumber(context, avg)}',
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryStatItem(
                    label: 'TOP MERCHANT',
                    value: topMerchant?.key ?? '-',
                    colorScheme: colorScheme,
                    showFullValueOnLongPress: topMerchant != null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendMiniChart(
      ColorScheme colorScheme, List<MonthTransactionGroup> monthGroups,
      {required bool isLoading}) {
    if (monthGroups.isEmpty && !isLoading) return const SizedBox.shrink();

    var chronologicalGroups = monthGroups.reversed.toList();
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;

    if (isLoading && chronologicalGroups.isEmpty) {
      // Mock data for skeleton
      chronologicalGroups = List.generate(
        6,
        (i) => MonthTransactionGroup(
          monthStart: DateTime.now(),
          expenses: [],
          total: 100.0 * (i + 1),
        ),
      );
    }

    return Skeletonizer(
      enabled: isLoading,
      child: Container(
        height: 148.0 * textScale.clamp(1.0, 1.6).toDouble(),
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
              height: 76,
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
                          color: getCategoryColor(widget.categoryKey, context),
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
            if (monthGroups.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatTrendMonth(context, chronologicalGroups.first),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                  if (chronologicalGroups.length > 1)
                    Expanded(
                      child: Text(
                        _formatTrendMonth(context, chronologicalGroups.last),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantSplitCard(ColorScheme colorScheme,
      List<MapEntry<String, double>> topMerchants, String symbol) {
    final top3 = topMerchants.take(3).toList();
    final categoryColor = getCategoryColor(widget.categoryKey, context);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;

    return Container(
      height: 148.0 * textScale.clamp(1.0, 1.6).toDouble(),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                  final fraction = top3.first.value <= 0
                      ? 0.0
                      : (e.value / top3.first.value).clamp(0.0, 1.0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message: e.key,
                                child: Text(
                                  e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.foreground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '$symbol${formatLocalizedNumber(context, e.value)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 3,
                            color: categoryColor,
                            backgroundColor:
                                colorScheme.muted.withValues(alpha: .55),
                          ),
                        ),
                      ],
                    ),
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
      height: MediaQuery.textScalerOf(context).scale(16) > 20 ? 60 : 52,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primaryForeground
                        : colorScheme.foreground,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Same helpers as transactions_page.dart
  Widget _buildMonthHeader(
    BuildContext context,
    MonthTransactionGroup group,
    ColorScheme colorScheme, {
    Key? key,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat('MMMM yyyy', locale).format(group.monthStart);

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        dateLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.mutedForeground,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    DayTransactionGroup group,
    ColorScheme colorScheme, {
    Key? key,
  }) {
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
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    Key? key,
    required ExpenseEntry originalItem,
    required String currentUserId,
    required Map<String, RecurringTransaction> recurringTransactionsById,
    required RecurringOccurrenceProjectionResolution occurrenceResolution,
    required bool isFirst,
    required bool isLast,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(24) : Radius.zero,
      bottom: isLast ? const Radius.circular(24) : Radius.zero,
    );
    final shouldShadow = isFirst || isLast;

    return Container(
      key: key,
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
        expense: originalItem,
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
          if (extractRecurringTransactionIdFromProjectedExpenseId(
                originalItem.id,
              ) !=
              null) {
            return;
          }
          unawaited(
            showTransactionDetailsSheet(
              context,
              expense: originalItem,
              recurringTransactionsById: recurringTransactionsById,
              recurringOccurrence: occurrenceResolution
                  .occurrencesByActualTransactionId[originalItem.id],
              recurringIdForOccurrence: occurrenceResolution
                  .recurringIdsByActualTransactionId[originalItem.id],
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
  final bool showFullValueOnLongPress;

  const _SummaryStatItem({
    required this.label,
    required this.value,
    required this.colorScheme,
    this.showFullValueOnLongPress = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.foreground,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          if (showFullValueOnLongPress)
            Tooltip(message: value, child: valueText)
          else
            valueText,
        ],
      ),
    );
  }
}

String _formatTrendMonth(BuildContext context, MonthTransactionGroup group) =>
    DateFormat('MMM yy', Localizations.localeOf(context).toString())
        .format(group.monthStart);

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

class _CategoryRenderCacheKey {
  final int displayExpensesSignature;

  const _CategoryRenderCacheKey({
    required this.displayExpensesSignature,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _CategoryRenderCacheKey &&
        displayExpensesSignature == other.displayExpensesSignature;
  }

  @override
  int get hashCode => displayExpensesSignature;
}

class _CategoryRenderCacheResult {
  final List<TransactionRenderItem> items;
  final Map<String, int> indexByKey;

  const _CategoryRenderCacheResult({
    required this.items,
    required this.indexByKey,
  });
}
