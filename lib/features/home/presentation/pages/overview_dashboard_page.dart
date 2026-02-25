import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/utils/overview_share_resolver.dart';
import 'package:moneko/features/utils/main_page_top_padding.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/user_timezone.dart';

final overviewPeriodSelectionProvider =
    StateProvider.autoDispose<PeriodSelection>(
  (ref) => PeriodSelection.preset(DateRangeFilter.allTime),
);

class OverviewDashboardPage extends ConsumerWidget {
  const OverviewDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetDashboardProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.overview,
      ),
      body: Material(
        child: Container(
          color: colorScheme.appBackground,
          child: state.when(
            data: (data) {
              if (data.isLoading && data.allTransactions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final user = ref.watch(authProvider);
              final analytics = ref.watch(analyticsProvider);
              final preferredTimezone = analytics.contact?.preferredTimezone;
              final timezoneOffsetMinutes =
                  resolveUserTimezoneOffsetMinutes(preferredTimezone);
              final now = userNowFromOffsetMinutes(timezoneOffsetMinutes);
              final displayCurrency =
                  ref.watch(homeFilterProvider).selectedCurrency ??
                      analytics.contact?.preferredCurrency ??
                      'USD';
              final allTransactions = data.allTransactions;
              final selectedPeriod = ref.watch(overviewPeriodSelectionProvider);
              final periodDateRange = resolvePeriodDateRange(
                selectedPeriod,
                now: now,
              );
              final selectedFrom = DateTime(
                periodDateRange.start.year,
                periodDateRange.start.month,
                periodDateRange.start.day,
              );
              final selectedTo = DateTime(
                periodDateRange.end.year,
                periodDateRange.end.month,
                periodDateRange.end.day,
              );

              String selectedPeriodLabel() {
                switch (selectedPeriod.kind) {
                  case PeriodSelectionKind.preset:
                    return (selectedPeriod.preset ?? DateRangeFilter.allTime)
                        .getLabel(context);
                  case PeriodSelectionKind.month:
                    final month = selectedPeriod.month ?? now;
                    return DateFormat('MMMM yyyy').format(month);
                  case PeriodSelectionKind.custom:
                    final start = selectedPeriod.customStart;
                    final end = selectedPeriod.customEnd;
                    if (start == null || end == null) {
                      return context.l10n.customRange;
                    }
                    final sameYear = start.year == end.year;
                    final formatter = sameYear
                        ? DateFormat('MMM d')
                        : DateFormat('MMM d, yyyy');
                    return '${formatter.format(start)} - ${formatter.format(end)}';
                }
              }

              bool isInSelectedDateRange(ConsolidatedTransaction tx) {
                final txDate = DateTime(
                  tx.entry.date.year,
                  tx.entry.date.month,
                  tx.entry.date.day,
                );
                return !txDate.isBefore(selectedFrom) &&
                    !txDate.isAfter(selectedTo);
              }

              final currentPeriodLabel = selectedPeriodLabel();

              final splitGroupsByExpenseId = <String, ExpenseSplitGroup>{};
              final splitGroupsById = <String, ExpenseSplitGroup>{};
              final householdsWithPendingSplits = <String>{};
              for (final household in data.households) {
                final splitsAsync = ref.watch(
                  householdSplitsProvider(
                    HouseholdSplitsParams(householdId: household.id),
                  ),
                );
                if ((splitsAsync.isLoading || splitsAsync.hasError) &&
                    !splitsAsync.hasValue) {
                  householdsWithPendingSplits.add(household.id);
                }
                final splits =
                    splitsAsync.valueOrNull ?? const <ExpenseSplitGroup>[];
                for (final split in splits) {
                  splitGroupsByExpenseId[split.expenseId] = split;
                  splitGroupsById[split.id] = split;
                }
              }

              bool isIncomeTransaction(ConsolidatedTransaction tx) =>
                  isIncomeTransactionType(tx.entry.type);

              double resolveMyShareRawAmount(ConsolidatedTransaction tx) {
                final householdId = tx.entry.householdId?.trim();
                final splitGroupId = tx.entry.splitGroupId?.trim();
                final hasSplitGroupId =
                    splitGroupId != null && splitGroupId.isNotEmpty;
                final isHouseholdSplitPending = householdId != null &&
                    householdId.isNotEmpty &&
                    hasSplitGroupId &&
                    householdsWithPendingSplits.contains(householdId) &&
                    splitGroupsByExpenseId[tx.entry.id] == null &&
                    splitGroupsById[splitGroupId] == null;
                if (isHouseholdSplitPending) {
                  return 0.0;
                }

                return resolveUserShareRawAmountForOverview(
                  entry: tx.entry,
                  currentUserId: user.uid,
                  splitGroupsByExpenseId: splitGroupsByExpenseId,
                  splitGroupsById: splitGroupsById,
                );
              }

              double resolveExpenseAmount(ConsolidatedTransaction tx) {
                final currency = tx.entry.currency ?? 'USD';
                final rawAmount = resolveMyShareRawAmount(tx).abs();
                return CurrencyRates.convert(
                    rawAmount, currency, displayCurrency);
              }

              double resolveAmount(ConsolidatedTransaction tx) {
                if (isIncomeTransaction(tx)) {
                  final currency = tx.entry.currency ?? 'USD';
                  final raw = resolveMyShareRawAmount(tx);
                  return CurrencyRates.convert(raw, currency, displayCurrency);
                }
                return resolveExpenseAmount(tx);
              }

              const shareEpsilon = 0.000001;

              final resolvedAmountById = <String, double>{};
              final resolvedExpenseAmountById = <String, double>{};

              double resolveCachedAmount(ConsolidatedTransaction tx) {
                return resolvedAmountById.putIfAbsent(
                  tx.entry.id,
                  () => resolveAmount(tx),
                );
              }

              double resolveCachedExpenseAmount(ConsolidatedTransaction tx) {
                return resolvedExpenseAmountById.putIfAbsent(
                  tx.entry.id,
                  () => resolveExpenseAmount(tx),
                );
              }

              double resolveMyShareAmount(ConsolidatedTransaction tx) {
                return resolveCachedAmount(tx);
              }

              final myAllTransactions = allTransactions
                  .where((tx) => resolveMyShareAmount(tx).abs() > shareEpsilon)
                  .where(isInSelectedDateRange)
                  .toList(growable: false);
              final myIncomeTransactions = myAllTransactions
                  .where(isIncomeTransaction)
                  .toList(growable: false);
              final myExpenseTransactions = myAllTransactions
                  .where((tx) => !isIncomeTransaction(tx))
                  .toList(growable: false);
              final recentTransactions = myAllTransactions.take(10).toList();

              final allTimeTotalIncome = myIncomeTransactions.fold<double>(
                  0.0, (sum, tx) => sum + resolveCachedAmount(tx));
              final allTimeTotalExpense = myExpenseTransactions.fold<double>(
                0.0,
                (sum, tx) => sum + resolveCachedExpenseAmount(tx),
              );
              final allTimeNetFlow = allTimeTotalIncome - allTimeTotalExpense;
              DateTime? allTimeStart;
              DateTime? allTimeEnd;
              for (final tx in myExpenseTransactions) {
                final date = DateTime(
                    tx.entry.date.year, tx.entry.date.month, tx.entry.date.day);
                final start = allTimeStart;
                if (start == null || date.isBefore(start)) {
                  allTimeStart = date;
                }
                final end = allTimeEnd;
                if (end == null || date.isAfter(end)) {
                  allTimeEnd = date;
                }
              }
              final allTimeStartDate = allTimeStart == null
                  ? now
                  : DateTime(
                      allTimeStart.year, allTimeStart.month, allTimeStart.day);
              final allTimeEndDate = allTimeEnd == null
                  ? now
                  : DateTime(allTimeEnd.year, allTimeEnd.month, allTimeEnd.day);
              final allTimeDaysInRange = myExpenseTransactions.isEmpty
                  ? 0
                  : allTimeEndDate.difference(allTimeStartDate).inDays + 1;
              final allTimeAvgDaily = allTimeDaysInRange > 0
                  ? allTimeTotalExpense / allTimeDaysInRange
                  : allTimeTotalExpense;

              String resolveSpaceId(ConsolidatedTransaction tx) {
                final householdId = tx.entry.householdId;
                if (householdId == null || householdId.isEmpty) {
                  return 'personal';
                }
                return householdId;
              }

              String normalizeCategoryId(String? categoryId) {
                final trimmed = categoryId?.trim();
                final normalized = (trimmed == null || trimmed.isEmpty)
                    ? 'uncategorized'
                    : trimmed;
                return normalizeCategory(normalized);
              }

              final activeSpaces = <String>{};
              final activeCurrencies = <String>{};
              for (final tx in myAllTransactions) {
                activeSpaces.add(resolveSpaceId(tx));
                final currency = tx.entry.currency;
                if (currency != null && currency.trim().isNotEmpty) {
                  activeCurrencies.add(currency.toUpperCase());
                }
              }

              final currencyFormatter = NumberFormat.simpleCurrency(
                  name: displayCurrency, decimalDigits: 0);

              String formatMoney(double value) {
                return currencyFormatter.format(value);
              }

              final categoryTotals = <String, double>{};
              for (final tx in myExpenseTransactions) {
                final categoryId = normalizeCategoryId(tx.entry.category);
                categoryTotals[categoryId] = (categoryTotals[categoryId] ?? 0) +
                    resolveCachedExpenseAmount(tx);
              }

              final topCategoryEntry = categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final hasExpenses = allTimeTotalExpense > 0;
              final topCategory =
                  topCategoryEntry.isNotEmpty ? topCategoryEntry.first : null;
              final topCategoryName = topCategory != null
                  ? getCategoryTranslation(context, topCategory.key)
                  : context.l10n.noExpensesYet;
              final topCategoryPercent =
                  topCategory != null && allTimeTotalExpense > 0
                      ? (topCategory.value / allTimeTotalExpense) * 100
                      : 0.0;

              final accountChartData = _buildAccountChartData(
                now: now,
                households: data.households,
                transactions: myAllTransactions,
                amountResolver: resolveCachedAmount,
              );

              void openDetail(String title, Widget child) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _DashboardDetailPage(
                      title: title,
                      child: child,
                    ),
                  ),
                );
              }

              Future<void> handleCurrencyChange() async {
                await showCurrencySelectorModal(context, ref);
                if (user.uid.isEmpty) return;
                ref.read(analyticsProvider.notifier).refresh(user.uid);

                final currentViewMode = ref.read(viewModeProvider);
                final currentSelectedHousehold =
                    ref.read(selectedHouseholdProvider);
                final householdId = currentViewMode.mode == ViewMode.household
                    ? currentSelectedHousehold.householdId
                    : null;

                ref
                    .read(recurringTransactionsProvider(householdId).notifier)
                    .refresh(user.uid);
                ref.invalidate(pocketsProvider);
              }

              Future<void> handleDateRangeChange() async {
                const dateRangeOptions = [
                  DateRangeFilter.today,
                  DateRangeFilter.yesterday,
                  DateRangeFilter.thisWeek,
                  DateRangeFilter.lastWeek,
                  DateRangeFilter.last7Days,
                  DateRangeFilter.thisMonth,
                  DateRangeFilter.lastMonth,
                  DateRangeFilter.last30Days,
                  DateRangeFilter.thisYear,
                  DateRangeFilter.allTime,
                  DateRangeFilter.custom,
                ];

                final selectedFilter =
                    await showModalBottomSheet<DateRangeFilter>(
                  context: context,
                  backgroundColor: colorScheme.sheetBackground,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (sheetContext) {
                    return SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              context.l10n.selectDateRange,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          ...dateRangeOptions.map((filter) {
                            final isSelected = selectedPeriod.kind ==
                                    PeriodSelectionKind.preset &&
                                selectedPeriod.preset == filter;
                            final isCustomSelected =
                                filter == DateRangeFilter.custom &&
                                    selectedPeriod.kind ==
                                        PeriodSelectionKind.custom;
                            return ListTile(
                              title: Text(filter.getLabel(context)),
                              trailing: (isSelected || isCustomSelected)
                                  ? Icon(
                                      Icons.check,
                                      color: colorScheme.primary,
                                      size: 18,
                                    )
                                  : null,
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(filter),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );

                if (selectedFilter == null) return;
                if (!context.mounted) return;

                if (selectedFilter == DateRangeFilter.custom) {
                  final initialRange = DateTimeRange(
                    start: selectedPeriod.customStart ?? selectedFrom,
                    end: selectedPeriod.customEnd ?? selectedTo,
                  );
                  final pickedRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000, 1, 1),
                    lastDate: DateTime(now.year, now.month, now.day),
                    initialDateRange: initialRange,
                  );
                  if (pickedRange == null) return;

                  ref.read(overviewPeriodSelectionProvider.notifier).state =
                      PeriodSelection.custom(
                    pickedRange.start,
                    pickedRange.end,
                  );
                  return;
                }

                ref.read(overviewPeriodSelectionProvider.notifier).state =
                    PeriodSelection.preset(selectedFilter);
              }

              final currencyPill = GestureDetector(
                onTap: handleCurrencyChange,
                child: Container(
                  height: 36,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.cardSurface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayCurrency,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colorScheme.mutedForeground,
                      ),
                    ],
                  ),
                ),
              );

              final dateRangePill = GestureDetector(
                onTap: handleDateRangeChange,
                child: Container(
                  height: 36,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.cardSurface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentPeriodLabel,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: colorScheme.mutedForeground,
                      ),
                    ],
                  ),
                ),
              );

              // Calculate household totals for space cards
              final householdTotals = <String, Map<String, dynamic>>{};
              // Add personal space first
              householdTotals['personal'] = {
                'income': 0.0,
                'expense': 0.0,
                'name': context.l10n.personal,
                'currency': displayCurrency,
                'coverImageUrl': user.photoUrl,
              };
              // Then add households
              for (final h in data.households) {
                householdTotals[h.id] = {
                  'income': 0.0,
                  'expense': 0.0,
                  'name': h.name,
                  'currency': displayCurrency,
                  'coverImageUrl': h.coverImageUrl,
                };
              }

              for (final tx in myAllTransactions) {
                final spaceId = resolveSpaceId(tx);
                final stats = householdTotals[spaceId];
                if (stats != null) {
                  if (isIncomeTransaction(tx)) {
                    stats['income'] =
                        (stats['income'] as double) + resolveCachedAmount(tx);
                  } else {
                    stats['expense'] = (stats['expense'] as double) +
                        resolveCachedExpenseAmount(tx);
                  }
                }
              }

              final transactionsBySpace =
                  <String, List<ConsolidatedTransaction>>{};
              for (final tx in myAllTransactions) {
                final spaceId = resolveSpaceId(tx);
                (transactionsBySpace[spaceId] ??= <ConsolidatedTransaction>[])
                    .add(tx);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  if (user.uid.isEmpty) return;
                  await ref.read(analyticsProvider.notifier).loadData(user.uid);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                      bottom: 40, top: getTopPadding(context) + 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: dateRangePill),
                            const SizedBox(width: 16),
                            currencyPill,
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hero Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _DashboardHeroCard(
                          netFlow: allTimeNetFlow,
                          income: allTimeTotalIncome,
                          expense: allTimeTotalExpense,
                          currencyCode: displayCurrency,
                          onTap: () => openDetail(
                            context.l10n.netFlow,
                            _NetFlowDetail(
                              income: allTimeTotalIncome,
                              expense: allTimeTotalExpense,
                              net: allTimeNetFlow,
                              currencyCode: displayCurrency,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Spaces / Accounts
                      _SectionHeader(
                        title: context.l10n.accounts,
                        actionLabel: context.l10n.activity,
                        onAction: () => openDetail(
                          context.l10n.activity,
                          _ActivityDetail(
                            accounts: activeSpaces.length,
                            currencies: activeCurrencies.length,
                            transactions: myAllTransactions.length,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        clipBehavior: Clip.none,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(
                            householdTotals.length,
                            (index) {
                              final key = householdTotals.keys.elementAt(index);
                              final stats = householdTotals[key]!;
                              final spaceTransactions =
                                  transactionsBySpace[key] ??
                                      const <ConsolidatedTransaction>[];
                              return DashboardSpaceCard(
                                spaceName: stats['name'] as String,
                                income: stats['income'] as double,
                                expense: stats['expense'] as double,
                                currency: stats['currency'] as String,
                                coverImageUrl:
                                    stats['coverImageUrl'] as String?,
                                onTap: () => openDetail(
                                  '${stats['name']} Overview',
                                  _SpaceDetail(
                                    spaceId: key,
                                    spaceName: stats['name'] as String,
                                    transactions: spaceTransactions,
                                    amountResolver: resolveCachedAmount,
                                    currencyCode: displayCurrency,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Insights
                      _SectionHeader(title: context.l10n.topInsight),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _InsightCard(
                          categoryName: topCategoryName,
                          categoryId: topCategory?.key,
                          percent: topCategoryPercent,
                          amount: topCategory?.value ?? 0,
                          hasExpenses: hasExpenses,
                          currencyCode: displayCurrency,
                          onTap: () => openDetail(
                            context.l10n.insight,
                            _InsightDetail(
                              categoryName: topCategoryName,
                              categoryId: topCategory?.key,
                              percent: topCategoryPercent,
                              amount: topCategory?.value ?? 0,
                              transactions: myExpenseTransactions,
                              amountResolver: resolveCachedExpenseAmount,
                              currencyCode: displayCurrency,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Spending Trend
                      _SectionHeader(
                        title: context.l10n.spendingTrend,
                        actionLabel: context.l10n.dailyAverage,
                        onAction: () => openDetail(
                          context.l10n.dailyAverage,
                          _AverageDetail(
                            avgDaily: allTimeAvgDaily,
                            daysTracked: allTimeDaysInRange,
                            totalExpense: allTimeTotalExpense,
                            transactions: myExpenseTransactions,
                            amountResolver: resolveCachedExpenseAmount,
                            currencyCode: displayCurrency,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: InkWell(
                          onTap: () => openDetail(
                            context.l10n.spendingTrend,
                            _TrendDetail(
                              transactions: myExpenseTransactions,
                              amountResolver: resolveCachedExpenseAmount,
                              currencyCode: displayCurrency,
                            ),
                          ),
                          child: _ChartCard(
                            child: DashboardTrendChart(
                              transactions: myExpenseTransactions,
                              amountResolver: resolveCachedExpenseAmount,
                              currencyCode: displayCurrency,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Spending Breakdown
                      if (hasExpenses) ...[
                        _SectionHeader(
                          title: context.l10n.spendingBreakdown,
                          actionLabel: context.l10n.spent,
                          onAction: () => openDetail(
                            context.l10n.spent,
                            _MetricDetail(
                              title: context.l10n.totalSpent,
                              value: allTimeTotalExpense,
                              subtitle: currentPeriodLabel,
                              transactions: myExpenseTransactions,
                              showCategories: true,
                              amountResolver: resolveCachedExpenseAmount,
                              currencyCode: displayCurrency,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _ChartCard(
                            child: DashboardPieChart(
                              transactions: myExpenseTransactions,
                              amountResolver: resolveCachedExpenseAmount,
                              currencyCode: displayCurrency,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Accounts Analysis
                      _SectionHeader(
                        title: context.l10n.accountsAnalysis,
                        actionLabel: context.l10n.accountSpend,
                        onAction: () => openDetail(
                          context.l10n.accountSpend,
                          _AccountsDetail(
                            households: data.households,
                            transactions: myAllTransactions,
                            chartData: accountChartData,
                            amountResolver: resolveCachedAmount,
                            currencyCode: displayCurrency,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _ChartCard(
                          child: accountChartData.isEmpty
                              ? Center(
                                  child: Text(
                                    context.l10n.noAccountActivity,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: 200,
                                  child: AccountSpendListChart(
                                    data: accountChartData,
                                    currencyCode: displayCurrency,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Recent Activity
                      _SectionHeader(
                        title: context.l10n.recentActivity,
                        actionLabel: context.l10n.viewAllTransactions,
                        onAction: () => openDetail(
                          context.l10n.transactions,
                          _TransactionsDetail(
                            transactions: myAllTransactions,
                            amountResolver: resolveCachedAmount,
                            currencyCode: displayCurrency,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (recentTransactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ...recentTransactions.take(3).map((tx) {
                                  final isIncome = isIncomeTransaction(tx);
                                  final amount = resolveCachedAmount(tx);
                                  final displayDateTime =
                                      combineUserDateWithUserTime(
                                    date: tx.entry.date,
                                    timeSource: tx.entry.createdAt,
                                    offsetMinutes: timezoneOffsetMinutes,
                                  );
                                  final currency = displayCurrency;
                                  final categoryId =
                                      normalizeCategoryId(tx.entry.category);

                                  return Column(
                                    children: [
                                      buildExpenseTransactionTile(
                                        context: context,
                                        category: categoryId,
                                        rawText: tx.entry.rawText,
                                        date: displayDateTime,
                                        amount: amount,
                                        currency: currency,
                                        isIncome: isIncome,
                                        onTap: () {},
                                        trailingWidget: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            tx.accountLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (tx != recentTransactions.take(3).last)
                                        const SizedBox(height: 16),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
            error: (err, stack) =>
                Center(child: Text(context.l10n.errorLoadingDashboard)),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

// Mimics _SettingsGroup from SettingsPage

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;

  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DashboardHeroCard extends StatelessWidget {
  final double netFlow;
  final double income;
  final double expense;
  final String currencyCode;
  final VoidCallback onTap;

  const _DashboardHeroCard({
    required this.netFlow,
    required this.income,
    required this.expense,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter =
        NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    final isPositive = netFlow >= 0;
    final netColor = isPositive ? colorScheme.success : colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.netFlow,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(netFlow),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: netColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.analytics_rounded, size: 24),
                onPressed: onTap,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.south_west_rounded,
                  iconColor: colorScheme.success,
                  label: context.l10n.income,
                  amount: formatter.format(income),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatPill(
                  icon: Icons.north_east_rounded,
                  iconColor: colorScheme.error,
                  label: context.l10n.expense,
                  amount: formatter.format(expense),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String amount;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String categoryName;
  final String? categoryId;
  final double percent;
  final double amount;
  final bool hasExpenses;
  final String currencyCode;
  final VoidCallback onTap;

  const _InsightCard({
    required this.categoryName,
    required this.categoryId,
    required this.percent,
    required this.amount,
    required this.hasExpenses,
    required this.currencyCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formatter =
        NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    final icon = categoryId != null
        ? getCategoryIcon(categoryId!)
        : Icons.lightbulb_outline_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.9),
            colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Beautiful overlay graphic
              Positioned(
                right: -40,
                bottom: -40,
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(
                    icon,
                    size: 180,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasExpenses
                          ? '${context.l10n.topInsight.toUpperCase()} ON\n${categoryName.toUpperCase()}'
                          : context.l10n.noExpensesYet.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.0,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasExpenses)
                      Text(
                        '${(percent * 100).toStringAsFixed(1)}% of your expenses',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatter.format(amount),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardGroup extends StatelessWidget {
  const _DashboardGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: 1.0,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// Mimics _SettingsTile from SettingsPage
class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    this.icon,
    this.customIcon,
    this.iconColor,
    required this.label,
    this.value,
    this.valueColor,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  final IconData? icon;
  final Widget? customIcon;
  final Color? iconColor;
  final String label;
  final String? value;
  final Color? valueColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              if (icon != null || customIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: customIcon ??
                      Icon(
                        icon,
                        size: 20,
                        color: iconColor ?? colorScheme.onSurface,
                      ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Text(
                  value!,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? colorScheme.mutedForeground,
                    fontWeight: valueColor != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
              if (showChevron && onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final double indent;
  const _Divider({this.indent = 76});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: colorScheme.border.withValues(alpha: 0.2),
      ),
    );
  }
}

class _DashboardDetailPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _DashboardDetailPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        useNativeToolbar: false,
        appBar: AppBar(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          centerTitle: true,
          backgroundColor: colorScheme.appBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      body: Container(
        color: colorScheme.appBackground,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: child,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// The detail widgets below can remain largely the same structurally,
// but we should ideally wrap their content in _DashboardGroup as well
// to maintain consistency deep in the navigation stack.
// -----------------------------------------------------------------------------

class _MetricDetail extends StatelessWidget {
  final String title;
  final double value;
  final String subtitle;
  final List<ConsolidatedTransaction> transactions;
  final bool showCategories;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String Function(ConsolidatedTransaction tx)? accountLabelResolver;
  final String currencyCode;

  const _MetricDetail({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.transactions,
    required this.showCategories,
    this.amountResolver,
    this.accountLabelResolver,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter =
        NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: context.l10n.summary,
          children: [
            _DashboardTile(
              label: title,
              value: currencyFormatter.format(value),
              subtitle: subtitle,
              showChevron: false,
            ),
          ],
        ),
        if (showCategories) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(context.l10n.topCategories,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  letterSpacing: -0.2,
                )),
          ),
          DashboardCategoryList(
            transactions: transactions,
            amountResolver: amountResolver,
            currencyCode: currencyCode,
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(context.l10n.transactions,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: -0.2,
              )),
        ),
        DashboardTransactionsList(
          transactions: transactions,
          amountResolver: amountResolver,
          currency: currencyCode,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _NetFlowDetail extends StatelessWidget {
  final double income;
  final double expense;
  final double net;
  final String currencyCode;

  const _NetFlowDetail({
    required this.income,
    required this.expense,
    required this.net,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: context.l10n.netFlowBreakdown,
          children: [
            _DashboardTile(
              label: context.l10n.totalIncome,
              value: currencyFormatter.format(income),
              valueColor: colorScheme.success,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: context.l10n.totalExpense,
              value: currencyFormatter.format(expense),
              valueColor: colorScheme.error,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: context.l10n.netResult,
              value: currencyFormatter.format(net),
              valueColor: net >= 0 ? colorScheme.success : colorScheme.error,
              showChevron: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _AverageDetail extends StatelessWidget {
  final double avgDaily;
  final int daysTracked;
  final double totalExpense;
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String currencyCode;

  const _AverageDetail({
    required this.avgDaily,
    required this.daysTracked,
    required this.totalExpense,
    required this.transactions,
    this.amountResolver,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: context.l10n.statistics,
          children: [
            _DashboardTile(
              label: context.l10n.averageDailySpend,
              value: currencyFormatter.format(avgDaily),
              subtitle: '${daysTracked} ${context.l10n.daysTracked}',
              showChevron: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _DashboardGroup(
          title: context.l10n.trend,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DashboardTrendChart(
                transactions: transactions,
                amountResolver: amountResolver,
                currencyCode: currencyCode,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendDetail extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String currencyCode;

  const _TrendDetail({
    required this.transactions,
    this.amountResolver,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: context.l10n.chart,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DashboardTrendChart(
                transactions: transactions,
                amountResolver: amountResolver,
                currencyCode: currencyCode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Use existing DailyTotalsCard logic but wrapped in our style?
        // For now, let's just assume we want the chart mostly.
      ],
    );
  }
}

class _AccountsDetail extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final List<Household> households;
  final List<AccountChartData> chartData;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String currencyCode;

  const _AccountsDetail({
    required this.transactions,
    required this.households,
    required this.chartData,
    this.amountResolver,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: context.l10n.charts,
          children: [
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AccountSpendListChart(
                  data: chartData,
                  currencyCode: currencyCode,
                ),
              ),
            ),
            const _Divider(indent: 0),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AccountIncomeExpenseChart(
                  data: chartData,
                  currencyCode: currencyCode,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(context.l10n.accountsList,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: -0.2,
              )),
        ),
        DashboardAccountsSection(
          transactions: transactions,
          households: households,
          amountResolver: amountResolver,
          currencyCode: currencyCode,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _InsightDetail extends StatelessWidget {
  final String categoryName;
  final String? categoryId;
  final double percent;
  final double amount;
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String Function(ConsolidatedTransaction tx)? accountLabelResolver;
  final String currencyCode;

  const _InsightDetail({
    required this.categoryName,
    required this.categoryId,
    required this.percent,
    required this.amount,
    required this.transactions,
    this.amountResolver,
    this.accountLabelResolver,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String normalizeCategoryId(String? categoryId) {
      final trimmed = categoryId?.trim();
      final normalized =
          (trimmed == null || trimmed.isEmpty) ? 'uncategorized' : trimmed;
      return normalizeCategory(normalized);
    }

    final filtered = categoryId == null
        ? transactions
        : transactions
            .where((tx) =>
                normalizeCategoryId(tx.entry.category) ==
                normalizeCategoryId(categoryId))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
              context.l10n.transactionsInCategory +
                  ' ${categoryName.toUpperCase()}'.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: -0.2,
              )),
        ),
        DashboardTransactionsList(
          transactions: filtered,
          amountResolver: amountResolver,
          accountLabelResolver: accountLabelResolver,
          currency: currencyCode,
        ),
      ],
    );
  }
}

class _TransactionsDetail extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String Function(ConsolidatedTransaction tx)? accountLabelResolver;
  final String currencyCode;

  const _TransactionsDetail({
    required this.transactions,
    this.amountResolver,
    this.accountLabelResolver,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        DashboardTransactionsList(
          transactions: transactions,
          amountResolver: amountResolver,
          currency: currencyCode,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ActivityDetail extends StatelessWidget {
  final int accounts;
  final int currencies;
  final int transactions;

  const _ActivityDetail({
    required this.accounts,
    required this.currencies,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: context.l10n.details,
          children: [
            _DashboardTile(
                label: context.l10n.totalAccounts,
                value: '$accounts',
                showChevron: false),
            const _Divider(),
            _DashboardTile(
                label: context.l10n.currencies,
                value: '$currencies',
                showChevron: false),
            const _Divider(),
            _DashboardTile(
                label: context.l10n.totalTransactions,
                value: '$transactions',
                showChevron: false),
          ],
        ),
      ],
    );
  }
}

class _AccountAccumulator {
  final String id;
  final String name;
  double income;
  double expense;
  // Monthly expense series for trend charts.
  final List<double> dailyExpenses;

  _AccountAccumulator({
    required this.id,
    required this.name,
    required this.income,
    required this.expense,
    required this.dailyExpenses,
  });
}

List<AccountChartData> _buildAccountChartData({
  required DateTime now,
  required List<Household> households,
  required List<ConsolidatedTransaction> transactions,
  required double Function(ConsolidatedTransaction tx) amountResolver,
}) {
  DateTime transactionUserDate(ConsolidatedTransaction tx) {
    return DateTime(tx.entry.date.year, tx.entry.date.month, tx.entry.date.day);
  }

  DateTime resolveStartMonth(List<ConsolidatedTransaction> txs) {
    if (txs.isEmpty) return DateTime(now.year, now.month, 1);
    DateTime minDate = transactionUserDate(txs.first);
    for (final tx in txs) {
      final txDate = transactionUserDate(tx);
      if (txDate.isBefore(minDate)) {
        minDate = txDate;
      }
    }
    return DateTime(minDate.year, minDate.month, 1);
  }

  DateTime resolveEndMonth(List<ConsolidatedTransaction> txs) {
    if (txs.isEmpty) return DateTime(now.year, now.month, 1);
    DateTime maxDate = transactionUserDate(txs.first);
    for (final tx in txs) {
      final txDate = transactionUserDate(tx);
      if (txDate.isAfter(maxDate)) {
        maxDate = txDate;
      }
    }
    return DateTime(maxDate.year, maxDate.month, 1);
  }

  const maxChartMonths = 6;
  var startMonth = resolveStartMonth(transactions);
  final endMonth = resolveEndMonth(transactions);
  var monthsCount = (endMonth.year - startMonth.year) * 12 +
      endMonth.month -
      startMonth.month +
      1;
  if (monthsCount > maxChartMonths) {
    startMonth = DateTime(
      endMonth.year,
      endMonth.month - (maxChartMonths - 1),
      1,
    );
    monthsCount = maxChartMonths;
  }
  final accounts = <String, _AccountAccumulator>{
    'personal': _AccountAccumulator(
      id: 'personal',
      name: 'Personal',
      income: 0,
      expense: 0,
      dailyExpenses: List<double>.filled(monthsCount, 0.0),
    ),
  };

  for (final household in households) {
    accounts[household.id] = _AccountAccumulator(
      id: household.id,
      name: household.name,
      income: 0,
      expense: 0,
      dailyExpenses: List<double>.filled(monthsCount, 0.0),
    );
  }

  for (final tx in transactions) {
    final key = tx.accountId ?? 'personal';
    final account = accounts[key];
    if (account == null) continue;
    final txDate = transactionUserDate(tx);
    final monthIndex =
        (txDate.year - startMonth.year) * 12 + txDate.month - startMonth.month;
    if (monthIndex < 0 || monthIndex >= monthsCount) continue;

    if (normalizeTransactionType(tx.entry.type) == 'income') {
      account.income += amountResolver(tx);
    } else {
      final expenseAmount = amountResolver(tx).abs();
      account.expense += expenseAmount;
      account.dailyExpenses[monthIndex] += expenseAmount;
    }
  }

  final ordered = <AccountChartData>[];
  final personal = accounts['personal'];
  if (personal != null) {
    ordered.add(AccountChartData(
      id: personal.id,
      name: personal.name,
      expense: personal.expense,
      income: personal.income,
      dailyExpenses: personal.dailyExpenses,
    ));
  }

  for (final household in households) {
    final acc = accounts[household.id];
    if (acc == null) continue;
    ordered.add(AccountChartData(
      id: acc.id,
      name: acc.name,
      expense: acc.expense,
      income: acc.income,
      dailyExpenses: acc.dailyExpenses,
    ));
  }

  return ordered;
}

class _SpaceDetail extends StatelessWidget {
  final String spaceId;
  final String spaceName;
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String currencyCode;

  const _SpaceDetail({
    required this.spaceId,
    required this.spaceName,
    required this.transactions,
    this.amountResolver,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter =
        NumberFormat.simpleCurrency(name: currencyCode, decimalDigits: 0);

    final incomeTx = transactions
        .where((tx) => normalizeTransactionType(tx.entry.type) == 'income');
    final expenseTx = transactions
        .where((tx) => normalizeTransactionType(tx.entry.type) != 'income');

    final totalIncome = incomeTx.fold<double>(0.0, (sum, tx) {
      final amt = amountResolver?.call(tx) ?? (tx.entry.amountCents / 100.0);
      return sum + amt;
    });
    final totalExpense = expenseTx.fold<double>(0.0, (sum, tx) {
      final amt = amountResolver?.call(tx) ?? (tx.entry.amountCents / 100.0);
      return sum + amt.abs();
    });

    final net = totalIncome - totalExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: context.l10n.summary,
          children: [
            _DashboardTile(
              label: context.l10n.income,
              value: currencyFormatter.format(totalIncome),
              valueColor: colorScheme.success,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: context.l10n.expense,
              value: currencyFormatter.format(totalExpense),
              valueColor: colorScheme.error,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: context.l10n.net,
              value: currencyFormatter.format(net),
              valueColor: net >= 0 ? colorScheme.success : colorScheme.error,
              showChevron: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (expenseTx.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(context.l10n.spendingBreakdown,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                  letterSpacing: -0.2,
                )),
          ),
          _DashboardGroup(
            title: '',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DashboardPieChart(
                  transactions: expenseTx.toList(),
                  amountResolver: amountResolver,
                  currencyCode: currencyCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(context.l10n.transactions,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: -0.2,
              )),
        ),
        DashboardTransactionsList(
          transactions: transactions,
          amountResolver: amountResolver,
          currency: currencyCode,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
