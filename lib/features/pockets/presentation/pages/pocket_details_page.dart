import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_rollover_breakdown.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';

import 'package:moneko/features/pockets/presentation/state/pocket_details_provider.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/pockets/presentation/widgets/edit_pocket_envelope_sheet.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';
import 'package:moneko/shared/widgets/transaction_details_sheet_router.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';

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
    final scrollController = useScrollController();
    final currentUserId = ref.watch(authProvider.select((state) => state.uid));
    final List<WalletEntity> scopedWallets =
        ref.watch(scopedWalletsProvider).valueOrNull ?? const <WalletEntity>[];
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
        body: const AsyncDataSkeleton(rowCount: 6),
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
    final effectiveCurrency = pocket.currency.trim().isNotEmpty
        ? pocket.currency.trim()
        : (state.currency.trim().isNotEmpty
            ? state.currency.trim()
            : (scopeParams.currency?.trim().isNotEmpty == true
                ? scopeParams.currency!.trim()
                : 'USD'));
    final detailScopeParams = PocketsScopeParams(
      scope: scopeParams.scope,
      householdId: scopeParams.householdId,
      periodMonth: state.periodMonth,
      currency: effectiveCurrency,
      selectedCurrencies: scopeParams.normalizedSelectedCurrencies,
      financialMonthStartDay: scopeParams.normalizedFinancialMonthStartDay,
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
      final monthStart = financialCycleStartForDate(
        periodMonth,
        startDay: detailScopeParams.normalizedFinancialMonthStartDay,
      );
      final monthEnd = nextFinancialCycleStart(
        monthStart,
        startDay: detailScopeParams.normalizedFinancialMonthStartDay,
      ).subtract(const Duration(days: 1));
      final feedHouseholdId =
          detailScopeParams.scope == PocketsScopeType.personal
              ? null
              : detailScopeParams.householdId;
      return TransactionsFeedQuery(
        userId: currentUserId,
        householdId: feedHouseholdId,
        selectedCurrency: effectiveCurrency,
        selectedCurrencies: detailScopeParams.normalizedSelectedCurrencies,
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
    final detailTransactions = useMemoized(
      () {
        final data = detailsData;
        if (data == null) {
          return const <ExpenseEntry>[];
        }
        return data.transactions.map(ExpenseEntry.fromJson).toList(
              growable: false,
            );
      },
      [detailsData],
    );
    final aggregateDetailTransactions = useMemoized(
      () {
        final data = detailsData;
        if (data == null) {
          return const <ExpenseEntry>[];
        }
        return data.aggregateTransactions.map(ExpenseEntry.fromJson).toList(
              growable: false,
            );
      },
      [detailsData],
    );
    final feedTransactions = activeFeedState?.items ?? const <ExpenseEntry>[];
    final feedTransactionsSignature =
        groupedTransactionEntriesSignature(feedTransactions);
    final detailTransactionsSignature =
        groupedTransactionEntriesSignature(detailTransactions);
    final visibleTransactions = useMemoized(
      () => _mergePocketDetailTransactions(
        feedTransactions: feedTransactions,
        detailTransactions: detailTransactions,
      ),
      [feedTransactionsSignature, detailTransactionsSignature],
    );
    final visibleTransactionsSignature =
        groupedTransactionEntriesSignature(visibleTransactions);
    final visibleTransactionsById = useMemoized(
      () => {
        for (final transaction in visibleTransactions)
          transaction.id: transaction,
      },
      [visibleTransactionsSignature],
    );
    final aggregateTransactionsSignature =
        groupedTransactionEntriesSignature(aggregateDetailTransactions);
    final aggregateTransactionsById = useMemoized(
      () => {
        for (final transaction in aggregateDetailTransactions)
          transaction.id: transaction,
      },
      [aggregateTransactionsSignature],
    );
    final displayVisibleTransactions = useMemoized(
      () {
        if (aggregateTransactionsById.isEmpty) {
          return visibleTransactions;
        }
        return visibleTransactions
            .map((transaction) =>
                aggregateTransactionsById[transaction.id] ?? transaction)
            .toList(growable: false);
      },
      [visibleTransactionsSignature, aggregateTransactionsSignature],
    );
    final displayVisibleTransactionsSignature =
        groupedTransactionEntriesSignature(displayVisibleTransactions);
    final financialMonthStartDay =
        detailScopeParams.normalizedFinancialMonthStartDay;
    final visibleListItems = useMemoized(
      () => buildGroupedTransactionRenderItems(
        displayVisibleTransactions,
        financialMonthStartDay: financialMonthStartDay,
      ),
      [displayVisibleTransactionsSignature, financialMonthStartDay],
    );
    final visibleListItemIndexByKey = useMemoized(
      () => buildGroupedTransactionRenderItemIndexByKey(visibleListItems),
      [visibleListItems],
    );
    final shouldShowCurrencyFlag =
        (detailScopeParams.normalizedSelectedCurrencies?.length ?? 0) > 1;

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
        transferWallets: scopedWallets,
      );
      if (didChange == true) {
        await refreshPocketDetails(linkedCategories);
      }
    }

    Future<void> handleTransactionDelete(
      ExpenseEntry expense,
      List<String> linkedCategories,
    ) async {
      WalletTransfer? transfer;
      if (isWalletTransferExpenseEntry(expense)) {
        transfer = await loadWalletTransferForExpense(context, expense.id);
        if (!context.mounted) return;
        if (transfer == null) {
          AppToast.error(context, context.l10n.failedToLoad);
          return;
        }
      }
      final confirmation = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.delete,
        description: context.l10n.confirmDeleteExpense,
        confirmLabel: context.l10n.delete,
        isDestructive: true,
      );
      if (confirmation?.confirmed != true) return;
      if (!context.mounted) return;

      AppToast.success(context, context.l10n.transactionDeleted);
      if (transfer != null) {
        try {
          await ref.read(walletActionsProvider).deleteTransfer(transfer);
          if (context.mounted) {
            await refreshPocketDetails(linkedCategories);
          }
        } catch (error) {
          if (context.mounted) {
            AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
          }
        }
        return;
      }
      final deleted = await ref
          .read(transactionEditProvider.notifier)
          .deleteExpensesOptimistically([expense]);
      if (!context.mounted) return;
      if (!deleted) {
        AppToast.error(
          context,
          ErrorHandler.getUserFriendlyMessage(
            ref.read(transactionEditProvider).error,
            context: BackendErrorContext.deleteExpense,
          ),
        );
        return;
      }
      await refreshPocketDetails(linkedCategories);
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
              controller: scrollController,
              key: PageStorageKey('pocket_details_scroll_$pocketId'),
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

                        EditPocketEnvelopeSheet.show(
                          context: context,
                          scopeParams: scopeParams,
                          existingEnvelope: pocket,
                          totalBudget: totalBudget,
                          unallocatedBudget: unallocatedBudget,
                          budgetId: state.budgetId,
                          allPockets: allPockets,
                          onDeleteCompleted: () {
                            rootNavigator.pop();
                          },
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
                                if (pocket.icon != null ||
                                    pocket.logoUrl != null) ...[
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: Builder(
                                      key: ValueKey(
                                          pocket.logoUrl ?? pocket.icon),
                                      builder: (context) {
                                        final trimmedLogoUrl =
                                            pocket.logoUrl?.trim();
                                        final iconData = pocket.icon != null
                                            ? getPocketIconData(pocket.icon)
                                            : null;
                                        final cacheSize = (28 *
                                                MediaQuery.of(context)
                                                    .devicePixelRatio)
                                            .round();

                                        if (trimmedLogoUrl != null &&
                                            trimmedLogoUrl.isNotEmpty) {
                                          return SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: ClipOval(
                                              child: Image.network(
                                                trimmedLogoUrl,
                                                fit: BoxFit.contain,
                                                cacheWidth: cacheSize,
                                                cacheHeight: cacheSize,
                                                errorBuilder: (_, __, ___) =>
                                                    iconData != null
                                                        ? Icon(
                                                            iconData,
                                                            size: 28,
                                                            color: textColor,
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
                                              ),
                                            ),
                                          );
                                        }

                                        if (iconData != null) {
                                          return Icon(
                                            iconData,
                                            size: 28,
                                            color: textColor,
                                          );
                                        }

                                        return const SizedBox.shrink();
                                      },
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
                              context.l10n.pocketRolloverRemainingLabel,
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
                              suffix: context
                                  .l10n.pocketRolloverAvailableBudgetLabel,
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
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.sheetBackground,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: detailsData == null
                        ? const SizedBox(height: 24)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.l10n.keyInsights,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (pocket.rolloverEnabled) ...[
                                _RolloverSummaryButton(
                                  pocket: pocket,
                                  currency: effectiveCurrency,
                                  detailsData: detailsData,
                                ),
                              ],
                              _StatsGrid(
                                spent: pocket.spent,
                                dailyAverage: detailsData.dailyAverage,
                                allowance: limit,
                                currency: effectiveCurrency,
                              ),
                              if (detailsData.categorySpending.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                _SpendingBreakdownCard(
                                  categorySpending:
                                      detailsData.categorySpending,
                                  currency: effectiveCurrency,
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
                if (detailsData == null && detailsAsync.isLoading)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  )
                else if (detailsData == null && detailsAsync.hasError)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.l10n.error(
                              detailsAsync.error.toString(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        child: Text(
                          context.l10n.recentTransactions,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if ((activeFeedState?.isLoading ?? false) &&
                      displayVisibleTransactions.isEmpty)
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: colorScheme.sheetBackground,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                    )
                  else if (activeFeedState?.error != null &&
                      displayVisibleTransactions.isEmpty)
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: colorScheme.sheetBackground,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              context.l10n.error(activeFeedState!.error!),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverGroupedTransactionsList(
                      items: visibleListItems,
                      itemIndexByKey: visibleListItemIndexByKey,
                      rowDisplayTransactionsById: visibleTransactionsById,
                      currency: effectiveCurrency,
                      backgroundColor: colorScheme.sheetBackground,
                      showCurrencyFlag: shouldShowCurrencyFlag,
                      onTransactionTap: (expense) {
                        unawaited(
                          handleTransactionTap(
                            visibleTransactionsById[expense.id] ?? expense,
                            detailsData!.linkedCategories,
                          ),
                        );
                      },
                      onTransactionDelete: (expense) => unawaited(
                        handleTransactionDelete(
                          visibleTransactionsById[expense.id] ?? expense,
                          detailsData!.linkedCategories,
                        ),
                      ),
                      canDeleteTransaction: (expense) =>
                          extractRecurringTransactionIdFromProjectedExpenseId(
                            expense.id,
                          ) ==
                          null,
                    ),
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: PaginatedLoadMoreIndicator(
                        show: activeFeedState?.isLoadingMore ?? false,
                        topPadding: 8,
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: const SizedBox(height: 40),
                    ),
                  ),
                ],
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

String _formatSignedLocalizedCurrencyCents(
  BuildContext context,
  int cents,
  String currency,
) {
  final sign = cents < 0 ? '-' : '+';
  return '$sign${_formatLocalizedCurrency(context, cents.abs() / 100.0, currency)}';
}

bool shouldShowPocketRolloverActivity(
  PocketEnvelope pocket,
  PocketRolloverBreakdown? breakdown,
) {
  final rolloverAdjustmentCents =
      pocket.rolloverFromPreviousCents + pocket.openingRolloverCents;
  final preview = breakdown?.nextMonthPreview;

  return pocket.rolloverEnabled ||
      rolloverAdjustmentCents != 0 ||
      breakdown?.hasDetailedContributions == true ||
      breakdown?.explanationRows.isNotEmpty == true ||
      breakdown?.warnings.isNotEmpty == true ||
      breakdown?.totalIncomingRolloverCents != 0 ||
      breakdown?.openingRolloverCents != 0 ||
      breakdown?.currentRolloverTotalCents != 0 ||
      preview?.hasCapAdjustment == true ||
      preview?.hasDroppedNegative == true;
}

class _RolloverSummaryButton extends StatelessWidget {
  const _RolloverSummaryButton({
    required this.pocket,
    required this.currency,
    required this.detailsData,
  });

  final PocketEnvelope pocket;
  final String currency;
  final PocketDetailsData? detailsData;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rolloverAdjustmentCents =
        pocket.rolloverFromPreviousCents + pocket.openingRolloverCents;

    if (!shouldShowPocketRolloverActivity(
      pocket,
      detailsData?.rolloverBreakdown,
    )) {
      return const SizedBox.shrink();
    }

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: colorScheme.surface,
            builder: (context) => _RolloverDetailsSheet(
              pocket: pocket,
              currency: currency,
              detailsData: detailsData,
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.pocketRolloverBreakdownTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatSignedLocalizedCurrencyCents(
                  context,
                  rolloverAdjustmentCents,
                  currency,
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: rolloverAdjustmentCents < 0
                      ? colorScheme.error
                      : colorScheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolloverDetailsSheet extends StatelessWidget {
  const _RolloverDetailsSheet({
    required this.pocket,
    required this.currency,
    required this.detailsData,
  });

  final PocketEnvelope pocket;
  final String currency;
  final PocketDetailsData? detailsData;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 24),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.sheetHandle,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.pocketRolloverBreakdownTitle,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _BudgetBreakdownCard(
                        pocket: pocket,
                        currency: currency,
                      ),
                      if (shouldShowPocketRolloverActivity(
                        pocket,
                        detailsData?.rolloverBreakdown,
                      )) ...[
                        const SizedBox(height: 16),
                        if (detailsData?.rolloverBreakdown != null)
                          RolloverContributionCard(
                            breakdown: detailsData!.rolloverBreakdown!,
                            currency: currency,
                          )
                        else
                          _RolloverActivityCard(
                            pocket: pocket,
                            currency: currency,
                          ),
                      ],
                      const SizedBox(height: 16),
                      _NextRolloverPreviewCard(
                        pocket: pocket,
                        currency: currency,
                        breakdown: detailsData?.rolloverBreakdown,
                      ),
                      if (detailsData != null &&
                          detailsData!.rolloverHistory.length > 1) ...[
                        const SizedBox(height: 16),
                        _RolloverHistoryCard(
                          history: detailsData!.rolloverHistory,
                          currency: currency,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BudgetBreakdownCard extends StatelessWidget {
  const _BudgetBreakdownCard({
    required this.pocket,
    required this.currency,
  });

  final PocketEnvelope pocket;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rolloverAdjustmentCents =
        pocket.rolloverFromPreviousCents + pocket.openingRolloverCents;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.pocketRolloverAvailableBudgetLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatLocalizedCurrency(
              context,
              pocket.availableBudget,
              currency,
            ),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: context.l10n.pocketRolloverBaseBudgetLabel,
                value: _formatLocalizedCurrency(
                  context,
                  pocket.baseBudget,
                  currency,
                ),
                valueColor: colorScheme.foreground,
              ),
              _StatItem(
                label: context.l10n.pocketRolloverLabel,
                value: _formatSignedLocalizedCurrencyCents(
                  context,
                  rolloverAdjustmentCents,
                  currency,
                ),
                valueColor: rolloverAdjustmentCents < 0
                    ? colorScheme.error
                    : colorScheme.success,
                crossAxisAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: colorScheme.border.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: context.l10n.pocketRolloverSpentLabel,
                value:
                    _formatLocalizedCurrency(context, pocket.spent, currency),
                valueColor: colorScheme.foreground,
              ),
              _StatItem(
                label: context.l10n.pocketRolloverRemainingLabel,
                value: _formatLocalizedCurrency(
                  context,
                  pocket.remaining,
                  currency,
                ),
                valueColor: pocket.remainingCents < 0
                    ? colorScheme.error
                    : colorScheme.foreground,
                crossAxisAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RolloverActivityCard extends StatelessWidget {
  const _RolloverActivityCard({
    required this.pocket,
    required this.currency,
  });

  final PocketEnvelope pocket;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = <Widget>[
      if (pocket.rolloverFromPreviousCents != 0)
        _ActivityRow(
          label: context.l10n.pocketRolloverCarryOverFromPreviousMonthLabel,
          valueCents: pocket.rolloverFromPreviousCents,
          currency: currency,
          valueColor: pocket.rolloverFromPreviousCents < 0
              ? colorScheme.error
              : colorScheme.success,
        ),
      if (pocket.openingRolloverCents != 0)
        _ActivityRow(
          label: context.l10n.pocketRolloverOpeningLabel,
          valueCents: pocket.openingRolloverCents,
          currency: currency,
          valueColor: pocket.openingRolloverCents < 0
              ? colorScheme.error
              : colorScheme.success,
        ),
    ];

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_repeat_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.pocketRolloverActivityTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  height: 1,
                  color: colorScheme.border.withValues(alpha: 0.5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class RolloverContributionCard extends StatelessWidget {
  const RolloverContributionCard({
    super.key,
    required this.breakdown,
    required this.currency,
  });

  final PocketRolloverBreakdown breakdown;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = breakdown.explanationRows;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey(rows.length),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.sheetElementBackground,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.pocketRolloverContributionTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _formatSignedLocalizedCurrencyCents(
                context,
                breakdown.currentRolloverTotalCents,
                currency,
              ),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: breakdown.currentRolloverTotalCents < 0
                    ? colorScheme.error
                    : colorScheme.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.pocketRolloverContributionDescription,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 32),
            if (rows.isEmpty)
              Text(
                context.l10n.pocketRolloverContributionEmpty,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                ),
              )
            else
              for (int i = 0; i < rows.length; i++) ...[
                _RolloverContributionRow(
                  contribution: rows[i],
                  currency: currency,
                ),
                if (i < rows.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Container(
                      height: 1,
                      color: colorScheme.border.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            if (breakdown.warnings.isNotEmpty) ...[
              const SizedBox(height: 24),
              _RolloverWarningBanner(warning: breakdown.warnings.first),
            ],
          ],
        ),
      ),
    );
  }
}

class _RolloverContributionRow extends StatelessWidget {
  const _RolloverContributionRow({
    required this.contribution,
    required this.currency,
  });

  final PocketRolloverContribution contribution;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isNegative = contribution.amountCents < 0;
    final icon = switch (contribution.sourceType) {
      'opening' => Icons.flag_rounded,
      'cap_adjustment' => Icons.compress_rounded,
      'negative_dropped' => Icons.block_rounded,
      'month_deficit' => Icons.trending_down_rounded,
      'reset' => Icons.restart_alt_rounded,
      _ => Icons.add_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isNegative ? colorScheme.error : colorScheme.success)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isNegative ? colorScheme.error : colorScheme.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _contributionLabel(context, contribution),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              if (contribution.reason?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  contribution.reason!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          _formatSignedLocalizedCurrencyCents(
            context,
            contribution.amountCents,
            currency,
          ),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isNegative ? colorScheme.error : colorScheme.success,
          ),
        ),
      ],
    );
  }
}

class _RolloverWarningBanner extends StatelessWidget {
  const _RolloverWarningBanner({required this.warning});

  final PocketRolloverWarning warning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.warningSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warning.message.isEmpty
                  ? context.l10n.pocketRolloverMissingMonthWarning
                  : warning.message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextRolloverPreviewCard extends StatelessWidget {
  const _NextRolloverPreviewCard({
    required this.pocket,
    required this.currency,
    this.breakdown,
  });

  final PocketEnvelope pocket;
  final String currency;
  final PocketRolloverBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = breakdown?.nextMonthPreview;
    final rawCarryCents = preview?.rawCarryCents ?? pocket.remainingCents;
    final nextCarryCents = preview?.carryCents ??
        (rawCarryCents < 0 && !pocket.rolloverNegative
            ? 0
            : (pocket.rolloverCapCents != null && rawCarryCents > 0
                ? rawCarryCents.clamp(0, pocket.rolloverCapCents!).toInt()
                : rawCarryCents));
    final wasCapped = preview?.hasCapAdjustment == true ||
        (pocket.rolloverCapCents != null &&
            rawCarryCents > pocket.rolloverCapCents!);

    final description = preview?.hasDroppedNegative == true ||
            (rawCarryCents < 0 && !pocket.rolloverNegative)
        ? context.l10n.pocketRolloverNegativeNotCarriedDescription
        : wasCapped
            ? context.l10n.pocketRolloverCapLimitedDescription
            : nextCarryCents == 0
                ? context.l10n.pocketRolloverNoCarryExpectedDescription
                : context.l10n.pocketRolloverNextMonthDescription;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.pocketRolloverNextMonthTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatSignedLocalizedCurrencyCents(
              context,
              nextCarryCents,
              currency,
            ),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color:
                  nextCarryCents < 0 ? colorScheme.error : colorScheme.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _RolloverHistoryCard extends StatelessWidget {
  const _RolloverHistoryCard({
    required this.history,
    required this.currency,
  });

  final List<PocketRolloverHistoryMonth> history;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleHistory =
        history.length > 6 ? history.sublist(history.length - 6) : history;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.pocketRolloverHistoryTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _RolloverHistoryChart(
            history: visibleHistory,
            currency: currency,
          ),
        ],
      ),
    );
  }
}

class _RolloverHistoryChart extends StatelessWidget {
  const _RolloverHistoryChart({
    required this.history,
    required this.currency,
  });

  final List<PocketRolloverHistoryMonth> history;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (history.isEmpty) return const SizedBox.shrink();

    double maxY = 0;
    for (final month in history) {
      final available = (month.baseBudgetCents +
              month.rolloverFromPreviousCents +
              month.openingRolloverCents) /
          100.0;
      final spent = month.spentCents / 100.0;
      if (available > maxY) maxY = available;
      if (spent > maxY) maxY = spent;
    }
    if (maxY == 0) maxY = 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.1,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 2,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: colorScheme.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= history.length) {
                        return const SizedBox.shrink();
                      }
                      final date = history[index].periodMonth;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _formatShortMonthLabel(context, date).substring(0, 3),
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => colorScheme.surface,
                  tooltipBorder:
                      BorderSide(color: colorScheme.border, width: 1),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final month = history[groupIndex];
                    final rolloverCents = month.rolloverFromPreviousCents +
                        month.openingRolloverCents;

                    final baseFormatted = _formatLocalizedCurrency(
                        context, month.baseBudgetCents / 100.0, currency);
                    final rolloverFormatted =
                        _formatSignedLocalizedCurrencyCents(
                            context, rolloverCents, currency);
                    final spentFormatted = _formatLocalizedCurrency(
                        context, month.spentCents / 100.0, currency);
                    final remainingFormatted = _formatLocalizedCurrency(
                        context, month.remainingCents.abs() / 100.0, currency);

                    final summary = context.l10n
                        .pocketRolloverHistorySummary(
                          baseFormatted,
                          rolloverFormatted,
                          spentFormatted,
                        )
                        .replaceAll(' - ', '\n');

                    return BarTooltipItem(
                      '${_formatMonthLabel(context, month.periodMonth)}\n',
                      TextStyle(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.left,
                      children: [
                        const TextSpan(text: '\n'),
                        TextSpan(
                          text: '$summary\n',
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const TextSpan(
                          text: '\n',
                          style: TextStyle(fontSize: 4),
                        ),
                        TextSpan(
                          text: month.remainingCents < 0
                              ? '= -$remainingFormatted'
                              : '= $remainingFormatted',
                          style: TextStyle(
                            color: month.remainingCents < 0
                                ? colorScheme.error
                                : colorScheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: List.generate(history.length, (index) {
                final month = history[index];
                final available = (month.baseBudgetCents +
                        month.rolloverFromPreviousCents +
                        month.openingRolloverCents) /
                    100.0;
                final spent = month.spentCents / 100.0;

                final safeAvailable = available < 0 ? 0.0 : available;
                final safeSpent = spent < 0 ? 0.0 : spent;

                final isOverspent = safeSpent > safeAvailable;
                final toY = isOverspent ? safeSpent : safeAvailable;

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: toY,
                      width: 24,
                      borderRadius: BorderRadius.circular(6),
                      color: colorScheme.surface.withValues(alpha: 0.0),
                      rodStackItems: [
                        if (!isOverspent && safeSpent > 0)
                          BarChartRodStackItem(
                              0, safeSpent, colorScheme.primary),
                        if (!isOverspent && safeAvailable > safeSpent)
                          BarChartRodStackItem(safeSpent, safeAvailable,
                              colorScheme.border.withValues(alpha: 0.3)),
                        if (isOverspent && safeAvailable > 0)
                          BarChartRodStackItem(0, safeAvailable,
                              colorScheme.border.withValues(alpha: 0.3)),
                        if (isOverspent && safeSpent > safeAvailable)
                          BarChartRodStackItem(
                              safeAvailable, safeSpent, colorScheme.error),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ChartLegendItem(
              color: colorScheme.border.withValues(alpha: 0.3),
              label: context.l10n.pocketRolloverAvailableBudgetLabel,
            ),
            const SizedBox(width: 16),
            _ChartLegendItem(
              color: colorScheme.primary,
              label: context.l10n.pocketRolloverSpentLabel,
            ),
            const SizedBox(width: 16),
            _ChartLegendItem(
              color: colorScheme.error,
              label: context.l10n.pocketRolloverMonthOverspend(''),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.replaceAll(RegExp(r'[()]'), '').trim(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

String _formatMonthLabel(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMonthYear(date);
}

String _formatShortMonthLabel(BuildContext context, DateTime date) {
  final label = MaterialLocalizations.of(context).formatMonthYear(date);
  final parts = label.split(' ');
  return parts.isEmpty ? label : parts.first;
}

String _contributionLabel(
  BuildContext context,
  PocketRolloverContribution contribution,
) {
  final month = contribution.sourcePeriodMonth == null
      ? ''
      : _formatShortMonthLabel(context, contribution.sourcePeriodMonth!);
  return switch (contribution.sourceType) {
    'opening' => context.l10n.pocketRolloverOpeningLabel,
    'month_deficit' => context.l10n.pocketRolloverMonthOverspend(month),
    'cap_adjustment' => context.l10n.pocketRolloverCapAdjustmentLabel,
    'negative_dropped' => context.l10n.pocketRolloverNegativeDroppedLabel,
    'reset' => context.l10n.pocketRolloverResetLabel,
    _ => context.l10n.pocketRolloverMonthLeftover(month),
  };
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColor ?? colorScheme.foreground,
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.label,
    required this.valueCents,
    required this.currency,
    required this.valueColor,
  });

  final String label;
  final int valueCents;
  final String currency;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.foreground,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          _formatSignedLocalizedCurrencyCents(
            context,
            valueCents,
            currency,
          ),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
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
            label: context.l10n.monthlySpend,
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
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _AnimatedAmountText(
              value: amount,
              currencyCode: currencyCode,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.spendingBreakdown,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              getCategoryTranslation(context, item.category),
                              style: TextStyle(
                                fontSize: 14,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 36,
                      sections: categorySpending.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final color = colors[index % colors.length];
                        return PieChartSectionData(
                          color: color,
                          value: item.amount,
                          title: '',
                          radius: 16,
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
