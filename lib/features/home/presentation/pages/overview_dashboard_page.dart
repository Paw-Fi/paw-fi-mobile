import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/budget_dashboard_provider.dart';
import 'package:moneko/features/home/presentation/widgets/budget_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/main_page_top_padding.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/features/utils/datetime.dart';

class OverviewDashboardPage extends ConsumerWidget {
  const OverviewDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetDashboardProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: "Overview",
      ),
      body: Material(
        child: Container(
          color: colorScheme.appBackground,
          child: state.when(
            data: (data) {
              if (data.isLoading && data.allTransactions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final now = DateTime.now();
              final user = ref.watch(authProvider);
              final analytics = ref.watch(analyticsProvider);
              final displayCurrency =
                  ref.watch(homeFilterProvider).selectedCurrency ??
                      analytics.contact?.preferredCurrency ??
                      'USD';
              final startOfMonth = DateTime(now.year, now.month, 1);
              final endOfMonth =
                  DateTime(now.year, now.month + 1, 0, 23, 59, 59);

              final monthTransactions = data.allTransactions.where((tx) {
                return tx.entry.date.isAfter(
                        startOfMonth.subtract(const Duration(seconds: 1))) &&
                    tx.entry.date
                        .isBefore(endOfMonth.add(const Duration(seconds: 1)));
              }).toList(growable: false)
                ..sort((a, b) => b.entry.date.compareTo(a.entry.date));

              final expenseTransactions = monthTransactions
                  .where((tx) => tx.entry.type != 'income')
                  .toList(growable: false);
              final incomeTransactions = monthTransactions
                  .where((tx) => tx.entry.type == 'income')
                  .toList(growable: false);

              final splitGroupsByExpenseId = <String, ExpenseSplitGroup>{};
              final splitGroupsById = <String, ExpenseSplitGroup>{};
              for (final household in data.households) {
                final splitsAsync = ref.watch(
                  householdSplitsProvider(
                    HouseholdSplitsParams(householdId: household.id),
                  ),
                );
                final splits =
                    splitsAsync.valueOrNull ?? const <ExpenseSplitGroup>[];
                for (final split in splits) {
                  splitGroupsByExpenseId[split.expenseId] = split;
                  splitGroupsById[split.id] = split;
                }
              }

              double resolveSplitLineAmount(ExpenseSplitGroup group) {
                final lines = group.splitLines;
                if (lines == null || lines.isEmpty) return 0.0;
                ExpenseSplitLine? line;
                for (final l in lines) {
                  if (l.userId == user.uid) {
                    line = l;
                    break;
                  }
                }
                if (line == null) return 0.0;

                switch (group.splitType) {
                  case SplitType.amount:
                    return (line.amountCents ?? 0) / 100.0;
                  case SplitType.percentage:
                    return ((line.percentage ?? 0) / 100) *
                        (group.totalAmountCents / 100.0);
                  case SplitType.shares:
                    final totalShares = lines.fold<int>(
                      0,
                      (sum, l) => sum + (l.shares ?? 0),
                    );
                    if (totalShares <= 0 || line.shares == null) return 0.0;
                    return (group.totalAmountCents / 100.0) *
                        (line.shares! / totalShares);
                  case SplitType.equal:
                    return (group.totalAmountCents / 100.0) / lines.length;
                }
              }

              double resolveExpenseAmount(ConsolidatedTransaction tx) {
                final currency = tx.entry.currency ?? 'USD';
                double rawAmount = 0.0;

                if (user.uid.isEmpty) {
                  rawAmount = tx.entry.amountCents / 100.0;
                } else {
                  final householdId = tx.entry.householdId;
                  if (householdId == null || householdId.isEmpty) {
                    rawAmount = tx.entry.amountCents / 100.0;
                  } else {
                    final splitGroup = splitGroupsByExpenseId[tx.entry.id] ??
                        (tx.entry.splitGroupId != null
                            ? splitGroupsById[tx.entry.splitGroupId!]
                            : null);

                    if (splitGroup != null) {
                      rawAmount = resolveSplitLineAmount(splitGroup);
                    } else {
                      final sharedMembers = tx.entry.sharedMemberIds;
                      if (sharedMembers != null && sharedMembers.isNotEmpty) {
                        if (sharedMembers.contains(user.uid)) {
                          rawAmount = (tx.entry.amountCents / 100.0) /
                              sharedMembers.length;
                        } else {
                          rawAmount = 0.0;
                        }
                      } else {
                        rawAmount = tx.entry.amountCents / 100.0;
                      }
                    }
                  }
                }
                return CurrencyRates.convert(
                    rawAmount, currency, displayCurrency);
              }

              double resolveAmount(ConsolidatedTransaction tx) {
                if (tx.entry.type == 'income') {
                  final currency = tx.entry.currency ?? 'USD';
                  final raw = tx.entry.amountCents / 100.0;
                  return CurrencyRates.convert(raw, currency, displayCurrency);
                }
                return resolveExpenseAmount(tx);
              }

              final totalIncome = incomeTransactions.fold<double>(
                  0.0, (sum, tx) => sum + resolveAmount(tx));
              final totalExpense = expenseTransactions.fold<double>(
                0.0,
                (sum, tx) => sum + resolveExpenseAmount(tx),
              );
              final netFlow = totalIncome - totalExpense;
              final daysInRange =
                  endOfMonth.difference(startOfMonth).inDays + 1;
              final avgDaily =
                  daysInRange > 0 ? totalExpense / daysInRange : totalExpense;

              final activeSpaces = <String>{};
              final activeCurrencies = <String>{};
              for (final tx in monthTransactions) {
                activeSpaces.add(tx.accountId ?? 'personal');
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
              for (final tx in expenseTransactions) {
                final category = tx.entry.category ?? 'uncategorized';
                categoryTotals[category] =
                    (categoryTotals[category] ?? 0) + resolveExpenseAmount(tx);
              }

              final topCategoryEntry = categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final hasExpenses = totalExpense > 0;
              final topCategory =
                  topCategoryEntry.isNotEmpty ? topCategoryEntry.first : null;
              final topCategoryName = topCategory != null
                  ? getCategoryTranslation(context, topCategory.key)
                  : 'No expenses';
              final topCategoryPercent = topCategory != null && totalExpense > 0
                  ? (topCategory.value / totalExpense) * 100
                  : 0.0;

              final accountChartData = _buildAccountChartData(
                now: now,
                households: data.households,
                transactions: monthTransactions,
                amountResolver: resolveAmount,
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

              // Calculate household totals for space cards
              final householdTotals = <String, Map<String, dynamic>>{};
              for (final h in data.households) {
                householdTotals[h.id] = {
                  'income': 0.0,
                  'expense': 0.0,
                  'name': h.name,
                  'currency': displayCurrency,
                };
              }
              // Add personal space
              householdTotals['personal'] = {
                'income': 0.0,
                'expense': 0.0,
                'name': 'Personal',
                'currency': displayCurrency,
              };

              for (final tx in monthTransactions) {
                final spaceId = tx.entry.householdId ?? 'personal';
                final stats = householdTotals[spaceId];
                if (stats != null) {
                  if (tx.entry.type == 'income') {
                    stats['income'] =
                        (stats['income'] as double) + resolveAmount(tx);
                  } else {
                    stats['expense'] =
                        (stats['expense'] as double) + resolveExpenseAmount(tx);
                  }
                }
              }

              return RefreshIndicator(
                onRefresh: () async {
                  if (user.uid.isEmpty) return;
                  await ref.read(analyticsProvider.notifier).loadData(user.uid);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      EdgeInsets.only(bottom: 40, top: getTopPadding(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Display Currency',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message:
                                      'All amounts on this page are roughly converted to the selected currency.',
                                  triggerMode: TooltipTriggerMode.tap,
                                  waitDuration: Duration.zero,
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                            currencyPill,
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Spaces Carousel (Accounts)
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: householdTotals.length,
                          itemBuilder: (context, index) {
                            final key = householdTotals.keys.elementAt(index);
                            final stats = householdTotals[key]!;
                            return DashboardSpaceCard(
                              spaceName: stats['name'] as String,
                              income: stats['income'] as double,
                              expense: stats['expense'] as double,
                              currency: stats['currency'] as String,
                              onTap: () => openDetail(
                                '${stats['name']} Overview',
                                _SpaceDetail(
                                  spaceId: key,
                                  spaceName: stats['name'] as String,
                                  transactions: monthTransactions
                                      .where((tx) =>
                                          (tx.entry.householdId ??
                                              'personal') ==
                                          key)
                                      .toList(),
                                  amountResolver: resolveAmount,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Month Summary Group
                      _DashboardGroup(
                        title: '${DateFormat.MMMM().format(now)} ${now.year}',
                        children: [
                          _DashboardTile(
                            icon: Icons.grid_view_rounded,
                            label: 'Active Accounts',
                            value: '${activeSpaces.length}',
                            onTap: () => openDetail(
                              'Activity',
                              _ActivityDetail(
                                accounts: activeSpaces.length,
                                currencies: activeCurrencies.length,
                                transactions: monthTransactions.length,
                              ),
                            ),
                          ),
                          const _Divider(),
                          _DashboardTile(
                            icon: Icons.receipt_long_rounded,
                            label: 'Transactions',
                            value: '${monthTransactions.length}',
                            onTap: () => openDetail(
                              'Activity',
                              _ActivityDetail(
                                accounts: activeSpaces.length,
                                currencies: activeCurrencies.length,
                                transactions: monthTransactions.length,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Financial Overview Group
                      _DashboardGroup(
                        title: 'Financial Overview',
                        children: [
                          _DashboardTile(
                            icon: Icons.arrow_downward_rounded,
                            iconColor: colorScheme.success,
                            label: 'Total Income',
                            value: formatMoney(totalIncome),
                            valueColor: colorScheme.success,
                            onTap: () => openDetail(
                              'Income',
                              _MetricDetail(
                                title: 'Total Income',
                                value: totalIncome,
                                subtitle: 'Income this month',
                                transactions: incomeTransactions,
                                showCategories: false,
                              ),
                            ),
                          ),
                          const _Divider(),
                          _DashboardTile(
                            icon: Icons.arrow_upward_rounded,
                            iconColor: colorScheme.error,
                            label: 'Total Spent',
                            value: formatMoney(totalExpense),
                            valueColor: colorScheme.error,
                            onTap: () => openDetail(
                              'Spent',
                              _MetricDetail(
                                title: 'Total Spent',
                                value: totalExpense,
                                subtitle: 'Expenses this month',
                                transactions: expenseTransactions,
                                showCategories: true,
                                amountResolver: resolveExpenseAmount,
                              ),
                            ),
                          ),
                          const _Divider(),
                          _DashboardTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Net Flow',
                            value: formatMoney(netFlow),
                            valueColor: netFlow >= 0
                                ? colorScheme.success
                                : colorScheme.error,
                            onTap: () => openDetail(
                              'Net Flow',
                              _NetFlowDetail(
                                income: totalIncome,
                                expense: totalExpense,
                                net: netFlow,
                              ),
                            ),
                          ),
                          const _Divider(),
                          _DashboardTile(
                            icon: Icons.calendar_today_rounded,
                            label: 'Daily Average',
                            value: formatMoney(avgDaily),
                            onTap: () => openDetail(
                              'Daily Average',
                              _AverageDetail(
                                avgDaily: avgDaily,
                                daysTracked: now.day,
                                totalExpense: totalExpense,
                                transactions: expenseTransactions,
                                amountResolver: resolveExpenseAmount,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Spending Breakdown Pie Chart
                      if (hasExpenses)
                        _DashboardGroup(
                          title: 'Spending Breakdown',
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: DashboardPieChart(
                                transactions: expenseTransactions,
                                amountResolver: resolveExpenseAmount,
                              ),
                            ),
                          ],
                        ),

                      // Trends Chart Group
                      _DashboardGroup(
                        title: 'Spending Trend',
                        children: [
                          InkWell(
                            onTap: () => openDetail(
                              'Spending Trend',
                              _TrendDetail(
                                transactions: expenseTransactions,
                                amountResolver: resolveExpenseAmount,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: DashboardTrendChart(
                                transactions: expenseTransactions,
                                amountResolver: resolveExpenseAmount,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Insights Group
                      _DashboardGroup(
                        title: 'Top Insight',
                        children: [
                          _DashboardTile(
                            customIcon: Icon(
                              topCategory != null
                                  ? getCategoryIcon(topCategory.key)
                                  : Icons.lightbulb_outline_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            label: topCategoryName,
                            value: hasExpenses
                                ? formatMoney(topCategory?.value ?? 0)
                                : '-',
                            subtitle: hasExpenses
                                ? '${topCategoryPercent.toStringAsFixed(0)}% of spend'
                                : null,
                            onTap: () => openDetail(
                              'Insight',
                              _InsightDetail(
                                categoryName: topCategoryName,
                                categoryId: topCategory?.key,
                                percent: topCategoryPercent,
                                amount: topCategory?.value ?? 0,
                                transactions: expenseTransactions,
                                amountResolver: resolveExpenseAmount,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Accounts Charts Group
                      _DashboardGroup(
                        title: 'Accounts Analysis',
                        children: [
                          _DashboardTile(
                            icon: Icons.pie_chart_rounded,
                            label: 'Spend by Account',
                            showChevron: true,
                            onTap: () => openDetail(
                              'Account Spend',
                              _AccountsDetail(
                                households: data.households,
                                transactions: monthTransactions,
                                chartData: accountChartData,
                                amountResolver: resolveAmount,
                              ),
                            ),
                          ),
                          const _Divider(),
                          if (accountChartData.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No account activity yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child:
                                  AccountSpendListChart(data: accountChartData),
                            ),
                        ],
                      ),

                      // Recent Transactions Group
                      _DashboardGroup(
                        title: 'Recent Activity',
                        children: [
                          _DashboardTile(
                            icon: Icons.list_rounded,
                            label: 'View All Transactions',
                            onTap: () => openDetail(
                              'Transactions',
                              _TransactionsDetail(
                                transactions: monthTransactions,
                                amountResolver: resolveAmount,
                              ),
                            ),
                          ),
                          if (monthTransactions.isNotEmpty) ...[
                            const _Divider(),
                            // Show first 3 transactions as simplified list items
                            ...monthTransactions.take(3).map((tx) {
                              final isIncome = tx.entry.type == 'income';
                              final amount = resolveAmount(tx);
                              final displayDateTime = combineLocalDateWithLocalTime(
                                date: tx.entry.date,
                                timeSource: tx.entry.createdAt,
                              );
                              final currency = ref.watch(homeFilterProvider).selectedCurrency ?? 'USD';
                              
                              return Column(
                                children: [
                                  buildExpenseTransactionTile(
                                    context: context,
                                    category: tx.entry.category,
                                    rawText: tx.entry.rawText,
                                    date: displayDateTime,
                                    amount: amount,
                                    currency: currency,
                                    isIncome: isIncome,
                                    onTap: () {
                                      // TODO: Navigate to transaction details
                                    },
                                    trailingWidget: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
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
                                  if (tx != monthTransactions.take(3).last)
                                    const _Divider(indent: 56),
                                ],
                              );
                            }),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            error: (err, stack) => Center(child: Text('Error: $err')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

// Mimics _SettingsGroup from SettingsPage
class _DashboardGroup extends StatelessWidget {
  const _DashboardGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: -0.2,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: colorScheme.homeCardShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  const _Divider({this.indent = 56});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.grey.withValues(alpha: 0.2),
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

  const _MetricDetail({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.transactions,
    required this.showCategories,
    this.amountResolver,
    this.accountLabelResolver,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: 'Summary',
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
            child: Text('TOP CATEGORIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: -0.2,
                )),
          ),
          DashboardCategoryList(
            transactions: transactions,
            amountResolver: amountResolver,
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text('TRANSACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: -0.2,
              )),
        ),
        DashboardTransactionsList(
          transactions: transactions,
          amountResolver: amountResolver,
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

  const _NetFlowDetail({
    required this.income,
    required this.expense,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: 'Net Flow Breakdown',
          children: [
            _DashboardTile(
              label: 'Total Income',
              value: currencyFormatter.format(income),
              valueColor: colorScheme.success,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: 'Total Expense',
              value: currencyFormatter.format(expense),
              valueColor: colorScheme.error,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: 'Net Result',
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

  const _AverageDetail({
    required this.avgDaily,
    required this.daysTracked,
    required this.totalExpense,
    required this.transactions,
    this.amountResolver,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: 'Statistics',
          children: [
            _DashboardTile(
              label: 'Average Daily Spend',
              value: currencyFormatter.format(avgDaily),
              subtitle: '$daysTracked days tracked',
              showChevron: false,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _DashboardGroup(
          title: 'Trend',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DashboardTrendChart(
                transactions: transactions,
                amountResolver: amountResolver,
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

  const _TrendDetail({
    required this.transactions,
    this.amountResolver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: 'Chart',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DashboardTrendChart(
                transactions: transactions,
                amountResolver: amountResolver,
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

  const _AccountsDetail({
    required this.transactions,
    required this.households,
    required this.chartData,
    this.amountResolver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: 'Charts',
          children: [
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AccountSpendListChart(data: chartData),
              ),
            ),
            const _Divider(indent: 0),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AccountIncomeExpenseChart(data: chartData),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text('ACCOUNTS LIST',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: -0.2,
              )),
        ),
        DashboardAccountsSection(
          transactions: transactions,
          households: households,
          amountResolver: amountResolver,
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

  const _InsightDetail({
    required this.categoryName,
    required this.categoryId,
    required this.percent,
    required this.amount,
    required this.transactions,
    this.amountResolver,
    this.accountLabelResolver,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = categoryId == null
        ? transactions
        : transactions
            .where((tx) => (tx.entry.category ?? 'uncategorized') == categoryId)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text('TRANSACTIONS IN $categoryName'.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: -0.2,
              )),
        ),
        DashboardTransactionsList(
          transactions: filtered,
          amountResolver: amountResolver,
          accountLabelResolver: accountLabelResolver,
        ),
      ],
    );
  }
}

class _TransactionsDetail extends StatelessWidget {
  final List<ConsolidatedTransaction> transactions;
  final double Function(ConsolidatedTransaction tx)? amountResolver;
  final String Function(ConsolidatedTransaction tx)? accountLabelResolver;

  const _TransactionsDetail({
    required this.transactions,
    this.amountResolver,
    this.accountLabelResolver,
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
          title: 'Details',
          children: [
            _DashboardTile(
                label: 'Total Accounts',
                value: '$accounts',
                showChevron: false),
            const _Divider(),
            _DashboardTile(
                label: 'Currencies', value: '$currencies', showChevron: false),
            const _Divider(),
            _DashboardTile(
                label: 'Total Transactions',
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
  final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
  final accounts = <String, _AccountAccumulator>{
    'personal': _AccountAccumulator(
      id: 'personal',
      name: 'Personal',
      income: 0,
      expense: 0,
      dailyExpenses: List<double>.filled(daysInMonth, 0.0),
    ),
  };

  for (final household in households) {
    accounts[household.id] = _AccountAccumulator(
      id: household.id,
      name: household.name,
      income: 0,
      expense: 0,
      dailyExpenses: List<double>.filled(daysInMonth, 0.0),
    );
  }

  for (final tx in transactions) {
    final key = tx.accountId ?? 'personal';
    final account = accounts[key];
    if (account == null) continue;
    final dayIndex = (tx.entry.date.day - 1).clamp(0, daysInMonth - 1);

    if (tx.entry.type == 'income') {
      account.income += amountResolver(tx);
    } else {
      final expenseAmount = amountResolver(tx);
      account.expense += expenseAmount;
      account.dailyExpenses[dayIndex] += expenseAmount;
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

  const _SpaceDetail({
    required this.spaceId,
    required this.spaceName,
    required this.transactions,
    this.amountResolver,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.simpleCurrency(decimalDigits: 0);

    final incomeTx = transactions.where((tx) => tx.entry.type == 'income');
    final expenseTx = transactions.where((tx) => tx.entry.type != 'income');

    final totalIncome = incomeTx.fold<double>(0.0, (sum, tx) {
      final amt = amountResolver?.call(tx) ?? (tx.entry.amountCents / 100.0);
      return sum + amt;
    });
    final totalExpense = expenseTx.fold<double>(0.0, (sum, tx) {
      final amt = amountResolver?.call(tx) ?? (tx.entry.amountCents / 100.0);
      return sum + amt;
    });

    final net = totalIncome - totalExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _DashboardGroup(
          title: 'Summary',
          children: [
            _DashboardTile(
              label: 'Income',
              value: currencyFormatter.format(totalIncome),
              valueColor: colorScheme.success,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: 'Expense',
              value: currencyFormatter.format(totalExpense),
              valueColor: colorScheme.error,
              showChevron: false,
            ),
            const _Divider(),
            _DashboardTile(
              label: 'Net',
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
            child: Text('SPENDING BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text('TRANSACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: -0.2,
              )),
        ),
        DashboardTransactionsList(
          transactions: transactions,
          amountResolver: amountResolver,
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
