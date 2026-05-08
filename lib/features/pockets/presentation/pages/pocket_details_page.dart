import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';

import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';
import 'package:moneko/shared/widgets/transaction_details_sheet_router.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

class PocketDetailsPage extends HookConsumerWidget {
  const PocketDetailsPage({
    super.key,
    required this.pocketId,
    required this.scopeParams,
  });

  final String pocketId;
  final PocketsScopeParams scopeParams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pocketsProvider(scopeParams));
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = ref.watch(authProvider.select((state) => state.uid));
    final recurringScopeHouseholdId =
        scopeParams.scope == PocketsScopeType.personal
            ? null
            : scopeParams.householdId;
    final shouldLoadRecurringTransactions =
        scopeParams.scope == PocketsScopeType.personal ||
            (recurringScopeHouseholdId?.trim().isNotEmpty == true);
    final recurringTransactionsState = shouldLoadRecurringTransactions
        ? ref.watch(recurringTransactionsProvider(recurringScopeHouseholdId))
        : RecurringTransactionsState(
            data: const AsyncValue.data(<RecurringTransaction>[]),
            hasLoadedOnce: true,
          );
    final recurringTransactions = recurringTransactionsState.data.valueOrNull ??
        const <RecurringTransaction>[];
    final recurringTransactionsById = {
      for (final transaction in recurringTransactions)
        transaction.id: transaction,
    };

    useEffect(() {
      if (!shouldLoadRecurringTransactions ||
          recurringTransactionsState.hasLoadedOnce) {
        return null;
      }

      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(recurringScopeHouseholdId)
                .notifier)
            .loadRecurringTransactions(currentUserId);
      });
      return null;
    }, [
      shouldLoadRecurringTransactions,
      recurringTransactionsState.hasLoadedOnce,
      recurringScopeHouseholdId,
      currentUserId,
    ]);

    // If state is loading (e.g., after invalidation), show loading indicator
    if (state.isLoading && state.editing.isEmpty && state.saved.isEmpty) {
      return StatusBarOverlayRegion(
          child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: context.l10n.loading),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),
        ),
      ));
    }

    // Try to find the pocket in editing or saved lists
    final pocket = _findPocket(state, pocketId);

    // If pocket not found, show error screen
    if (pocket == null) {
      return StatusBarOverlayRegion(
          child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(title: context.l10n.pocketNotFound),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.pocketNotFound,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.pocketNotFoundDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.goBack),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    final totalBudget = state.totalBudget;
    final limit = pocket.getLimit(totalBudget);
    final progress = pocket.getProgress(totalBudget);
    final effectiveCurrency = state.currency.trim().isNotEmpty
        ? state.currency.trim()
        : (scopeParams.currency?.trim().isNotEmpty == true
            ? scopeParams.currency!.trim()
            : pocket.currency);
    final detailScopeParams = PocketsScopeParams(
      scope: scopeParams.scope,
      householdId: scopeParams.householdId,
      periodMonth: state.periodMonth,
      currency: effectiveCurrency,
      isBootstrapCurrency: false,
      includeUpcomingRecurring: scopeParams.includeUpcomingRecurring,
    );
    final pocketDetailsParams = PocketTransactionsParams(
      pocketId: pocketId,
      scopeParams: detailScopeParams,
    );
    final detailsAsync = ref.watch(
      pocketDetailsProvider(pocketDetailsParams),
    );

    TransactionsFeedQuery buildFeedQuery(List<String> linkedCategories) {
      final periodMonth = detailScopeParams.periodMonth ?? DateTime.now();
      final monthStart = DateTime(periodMonth.year, periodMonth.month, 1);
      final monthEnd = DateTime(periodMonth.year, periodMonth.month + 1, 0);
      final feedHouseholdId =
          detailScopeParams.scope == PocketsScopeType.personal
              ? null
              : detailScopeParams.householdId;
      return TransactionsFeedQuery(
        userId: currentUserId,
        householdId: feedHouseholdId,
        selectedCurrency: effectiveCurrency,
        selectedCategory: null,
        selectedAccountId: null,
        selectedCategories: linkedCategories,
        selectedType: 'expense',
        searchQuery: '',
        startDate: monthStart,
        endDate: monthEnd,
      );
    }

    final detailsData = detailsAsync.valueOrNull;
    final activeFeedState = detailsData == null
        ? null
        : ref.watch(
            transactionsFeedProvider(
              buildFeedQuery(detailsData.linkedCategories),
            ),
          );

    Future<void> refreshPocketDetails(List<String> linkedCategories) async {
      final feedQuery = buildFeedQuery(linkedCategories);
      await ref.read(transactionsFeedProvider(feedQuery).notifier).refresh();
      ref.invalidate(pocketDetailsProvider(pocketDetailsParams));
    }

    Future<void> handleTransactionTap(
      ExpenseEntry expense,
      List<String> linkedCategories,
    ) async {
      final recurringId =
          extractRecurringTransactionIdFromProjectedExpenseId(expense.id);
      var effectiveRecurringTransactionsById = recurringTransactionsById;

      if (shouldLoadRecurringTransactions &&
          recurringId != null &&
          !effectiveRecurringTransactionsById.containsKey(recurringId)) {
        await ref
            .read(recurringTransactionsProvider(recurringScopeHouseholdId)
                .notifier)
            .loadRecurringTransactions(
              currentUserId,
              forceRefresh: true,
            );
        final refreshedTransactions = ref
                .read(recurringTransactionsProvider(recurringScopeHouseholdId))
                .data
                .valueOrNull ??
            const <RecurringTransaction>[];
        effectiveRecurringTransactionsById = {
          for (final transaction in refreshedTransactions)
            transaction.id: transaction,
        };
      }

      if (!context.mounted) return;
      final didChange = await showTransactionDetailsSheet(
        context,
        expense: expense,
        recurringTransactionsById: effectiveRecurringTransactionsById,
      );
      if (didChange == true) {
        await refreshPocketDetails(linkedCategories);
      }
    }

    // Calculate unallocated budget for the edit sheet based on the effective
    // limits shown in the UI (supports fixed allocations).
    final totalBudgetCents = (totalBudget * 100).round();
    final allocatedCents = state.editing.fold<int>(
      0,
      (sum, p) => sum + p.getLimitFromTotalBudgetCents(totalBudgetCents),
    );
    final unallocatedBudget = (totalBudgetCents - allocatedCents) / 100.0;

    final pocketColor = pocket.color != null
        ? Color(int.parse(pocket.color!.replaceAll('#', '0xff')))
        : colorScheme.primary;

    final gradientColors = _generateGradientColors(pocketColor, colorScheme);

    // Determine text color based on background luminance
    final isBackgroundLight = gradientColors.first.computeLuminance() > 0.5;
    final textColor =
        isBackgroundLight ? AppTheme.lightForeground : AppTheme.darkForeground;
    final secondaryTextColor = textColor.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: gradientColors.first,
      body: Stack(
        children: [
          // 1. Full-bleed Gradient Background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
              ),
            ),
          ),
          // 2. Scrollable Content
          AutoPaginatedScroll(
            hasMore: activeFeedState?.hasMore ?? false,
            isLoading: activeFeedState?.isLoading ?? false,
            isLoadingMore: activeFeedState?.isLoadingMore ?? false,
            onLoadMore: () {
              if (detailsData == null) {
                return;
              }
              final query = buildFeedQuery(detailsData.linkedCategories);
              ref.read(transactionsFeedProvider(query).notifier).loadMore();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar(
                  expandedHeight: 320,
                  pinned: true,
                  stretch: true,
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.edit, color: textColor),
                      onPressed: () {
                        final rootNavigator = Navigator.of(context);
                        // Combine both saved and editing pockets for complete rebalancing
                        final seenIds = <String>{};
                        final allPockets = <PocketEnvelope>[
                          ...state.editing.where((p) {
                            if (seenIds.contains(p.id)) return false;
                            seenIds.add(p.id);
                            return true;
                          }),
                          ...state.saved.where((p) {
                            if (seenIds.contains(p.id)) return false;
                            seenIds.add(p.id);
                            return true;
                          }),
                        ];

                        showModalBottomSheet(
                          context: context,
                          barrierColor:
                              colorScheme.scrim.withValues(alpha: 0.5),
                          enableDrag: false,
                          useSafeArea: true,
                          isScrollControlled: true,
                          builder: (sheetContext) => EditPocketEnvelopeSheet(
                            scopeParams: detailScopeParams,
                            existingEnvelope: pocket,
                            totalBudget: totalBudget,
                            unallocatedBudget: unallocatedBudget,
                            budgetId: state.budgetId,
                            allPockets: allPockets,
                            onDeleteCompleted: () {
                              rootNavigator.pop();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.fadeTitle,
                    ],
                    background: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            // Icon & Name
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (pocket.icon != null) ...[
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      getPocketIconData(pocket.icon),
                                      key: ValueKey(pocket.icon),
                                      size: 28,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Flexible(
                                  child: Text(
                                    pocket.name,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.monthlyBudget,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Big Amount (Remaining)
                            _AnimatedAmountText(
                              value: limit - pocket.spent,
                              currencyCode: effectiveCurrency,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Allocated
                            _AnimatedAmountText(
                              value: limit,
                              currencyCode: effectiveCurrency,
                              suffix: 'allocated',
                              style: TextStyle(
                                fontSize: 16,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Progress Bar
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  begin: progress.clamp(0.0, 1.0),
                                  end: progress.clamp(0.0, 1.0)),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, _) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: val,
                                    minHeight: 8,
                                    backgroundColor:
                                        textColor.withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.sheetBackground,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: detailsAsync.when(
                        data: (data) {
                          final feedQuery =
                              buildFeedQuery(data.linkedCategories);
                          final feedState =
                              ref.watch(transactionsFeedProvider(feedQuery));
                          final detailTransactions = data.transactions
                              .map(ExpenseEntry.fromJson)
                              .toList(growable: false);
                          final visibleTransactions =
                              _mergePocketDetailTransactions(
                            feedTransactions: feedState.items,
                            detailTransactions: detailTransactions,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.l10n.keyInsights,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 1. Stats Grid
                              _StatsGrid(
                                spent: pocket.spent,
                                dailyAverage: data.dailyAverage,
                                allowance: limit,
                                currency: effectiveCurrency,
                              ),
                              const SizedBox(height: 24),

                              // 3. Spending Breakdown
                              if (data.categorySpending.isNotEmpty) ...[
                                _SpendingBreakdownCard(
                                  categorySpending: data.categorySpending,
                                  currency: effectiveCurrency,
                                ),
                                const SizedBox(height: 24),
                              ],

                              // 4. Recent Transactions
                              if (feedState.isLoading &&
                                  visibleTransactions.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (feedState.error != null &&
                                  visibleTransactions.isEmpty)
                                Center(
                                  child: Text(
                                    context.l10n.error(feedState.error!),
                                  ),
                                )
                              else
                                GroupedTransactionsList(
                                  transactions: visibleTransactions,
                                  currency: effectiveCurrency,
                                  onTransactionTap: (expense) {
                                    unawaited(
                                      handleTransactionTap(
                                        expense,
                                        data.linkedCategories,
                                      ),
                                    );
                                  },
                                ),
                              PaginatedLoadMoreIndicator(
                                show: feedState.isLoadingMore,
                                topPadding: 8,
                              ),
                              // Add extra padding at bottom for scrolling
                              const SizedBox(height: 40),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, stack) => Center(
                          child: Text(context.l10n.error(err.toString())),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to find a pocket by ID in either editing or saved lists
PocketEnvelope? _findPocket(PocketsState state, String pocketId) {
  try {
    return state.editing.firstWhere((p) => p.id == pocketId);
  } catch (_) {
    try {
      return state.saved.firstWhere((p) => p.id == pocketId);
    } catch (_) {
      return null;
    }
  }
}

List<ExpenseEntry> _mergePocketDetailTransactions({
  required List<ExpenseEntry> feedTransactions,
  required List<ExpenseEntry> detailTransactions,
}) {
  // Pocket totals/details include projected recurring expenses for the current
  // month. Keep those rows visible here even though the generic transactions
  // feed only knows about persisted transaction rows.
  if (detailTransactions.isEmpty) {
    return feedTransactions;
  }
  if (feedTransactions.isEmpty) {
    return detailTransactions;
  }

  final mergedById = <String, ExpenseEntry>{
    for (final expense in feedTransactions) expense.id: expense,
  };

  // CRITICAL: keep projected/recurring rows from the pocket details provider
  // in the visible list.
  // STRICT REQUIREMENT: the generic transactions feed does not include the
  // same recurring-pocket projection logic as the pocket totals, so removing
  // this merge reintroduces missing recurring rows in pocket details.
  for (final expense in detailTransactions) {
    mergedById.putIfAbsent(expense.id, () => expense);
  }

  final merged = mergedById.values.toList(growable: false);
  merged.sort((left, right) {
    final dateCompare = right.date.compareTo(left.date);
    if (dateCompare != 0) return dateCompare;

    final createdCompare = right.createdAt.compareTo(left.createdAt);
    if (createdCompare != 0) return createdCompare;

    return right.id.compareTo(left.id);
  });
  return merged;
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.spent,
    required this.dailyAverage,
    required this.allowance,
    required this.currency,
  });

  final double spent;
  final double dailyAverage;
  final double allowance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: context.l10n.spentThisMonth,
            amount: spent,
            currencyCode: currency,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.l10n.avgDaily,
            amount: dailyAverage,
            currencyCode: currency,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: context.l10n.allowance,
            amount: allowance,
            currencyCode: currency,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    required this.currencyCode,
  });

  final String label;
  final double amount;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.pocketCardSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _AnimatedAmountText(
              value: amount,
              currencyCode: currencyCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedAmountText extends StatelessWidget {
  final double value;
  final String currencyCode;
  final TextStyle style;
  final String suffix;

  const _AnimatedAmountText({
    required this.value,
    required this.currencyCode,
    required this.style,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        final formatted = _formatLocalizedCurrency(context, val, currencyCode);
        return Text(
          suffix.isEmpty ? formatted : '$formatted $suffix',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _SpendingBreakdownCard extends StatelessWidget {
  const _SpendingBreakdownCard({
    required this.categorySpending,
    required this.currency,
  });

  final List<CategorySpend> categorySpending;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use a set of nice colors for the chart
    const colors = AppTheme.pocketChartPalette;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.pocketCardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.spendingBreakdown,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: categorySpending.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final color = colors[index % colors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              getCategoryTranslation(context, item.category),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.foreground,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(item.share * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 30,
                      sections: categorySpending.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final color = colors[index % colors.length];
                        return PieChartSectionData(
                          color: color,
                          value: item.amount,
                          title: '',
                          radius: 30,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

List<Color> _generateGradientColors(Color baseColor, ColorScheme scheme) {
  return AppTheme.pocketDetailsGradient(baseColor, scheme);
}
