import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_models.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/transaction_details_sheet_router.dart';

class WalletDetailsPage extends HookConsumerWidget {
  const WalletDetailsPage({
    super.key,
    required this.wallet,
  });

  final WalletEntity wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.watch(walletActionsProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final selectedCurrencyFilters = ref.watch(
      homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
    );
    final shouldConvertCurrencies = (selectedCurrencyFilters?.length ?? 0) > 1;
    final rateTable = ref.watch(currencyRateTableProvider).valueOrNull ??
        const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: CurrencyRates.rates,
          isStale: true,
        );
    final currentUserId = ref.watch(authProvider.select((state) => state.uid));
    final preferredTimezone = ref
        .watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
    final userNow = effectiveNow(preferredTimezone: preferredTimezone);
    final providerAccount = ref.watch(walletByIdProvider(wallet.id));
    final serverAccount = ref.watch(serverWalletByIdProvider(wallet.id));
    final latestDisplayedAccountState = useState<WalletEntity>(wallet);

    useEffect(() {
      if (providerAccount != null) {
        debugPrint(
          '[AccountDetails] providerAccount accountId=${providerAccount.id} name=${providerAccount.name} color=${providerAccount.color} opening=${providerAccount.openingBalanceCents} current=${providerAccount.currentBalanceCents}',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final latestServerAccount =
              ref.read(serverWalletByIdProvider(wallet.id));
          if (latestServerAccount == null) {
            return;
          }
          actions.reconcileOptimisticAccountWithServer(latestServerAccount);
        });
        latestDisplayedAccountState.value = providerAccount;
      } else {
        final cached = latestDisplayedAccountState.value;
        debugPrint(
          '[AccountDetails] providerAccount=null fallbackToCached accountId=${cached.id} name=${cached.name} color=${cached.color} opening=${cached.openingBalanceCents} current=${cached.currentBalanceCents}',
        );
      }
      return null;
    }, [providerAccount, serverAccount]);

    final latestWallet = providerAccount ?? latestDisplayedAccountState.value;
    final householdScope = ref.watch(householdScopeProvider);
    final scopedAccounts =
        ref.watch(scopedWalletsProvider).valueOrNull ?? const <WalletEntity>[];
    final defaultAccountId = _resolveDefaultAccountId(scopedAccounts);
    final isDefaultResolvedAccount = latestWallet.id == defaultAccountId;

    final effectiveHouseholdId = _resolveScopedHouseholdId(householdScope);
    final currentMonthStart = DateTime(userNow.year, userNow.month);
    final detailsScopeQuery = WalletsScopeQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: selectedCurrencyCode,
      selectedCurrencies: selectedCurrencyFilters,
      currentMonthStart: currentMonthStart,
    );
    final detailsMonthQuery = WalletsMonthQuery(
      scope: detailsScopeQuery,
      monthStart: currentMonthStart,
    );
    final detailsMonthSnapshotAsync =
        ref.watch(walletsMonthSnapshotProvider(detailsMonthQuery));
    final walletFeedQuery = TransactionsFeedQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: selectedCurrencyCode,
      selectedCurrencies: selectedCurrencyFilters,
      selectedCategory: null,
      selectedAccountId: latestWallet.id,
      selectedCategories: null,
      includeUnassignedAccount: isDefaultResolvedAccount,
      selectedType: 'all',
      searchQuery: '',
      startDate: null,
      endDate: null,
      pageSize: 200,
    );
    final walletFeedState =
        ref.watch(transactionsFeedProvider(walletFeedQuery));

    final monthStart = DateTime(userNow.year, userNow.month, 1);
    final monthEnd = DateTime(userNow.year, userNow.month + 1, 0);
    final monthFeedQuery = walletFeedQuery.copyWith(
      startDate: monthStart,
      endDate: monthEnd,
    );
    final monthFeedState = ref.watch(transactionsFeedProvider(monthFeedQuery));
    final monthAllItemsAsync = shouldConvertCurrencies
        ? ref.watch(transactionsFeedAllItemsProvider(monthFeedQuery))
        : null;
    final recurringTransactionsState =
        ref.watch(recurringTransactionsProvider(effectiveHouseholdId));
    final recurringTransactions = recurringTransactionsState.data.valueOrNull ??
        const <RecurringTransaction>[];

    useEffect(() {
      if (recurringTransactionsState.hasLoadedOnce) {
        return null;
      }

      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(effectiveHouseholdId).notifier)
            .loadRecurringTransactions(currentUserId);
      });
      return null;
    }, [
      recurringTransactionsState.hasLoadedOnce,
      effectiveHouseholdId,
      currentUserId,
    ]);

    useEffect(() {
      if (walletFeedState.error != null) {
        debugPrint(
          '[WalletDetailsPage][transactionsFeedProvider] accountId=${latestWallet.id} userId=$currentUserId householdId=$effectiveHouseholdId currency=$selectedCurrencyCode includeUnassignedAccount=$isDefaultResolvedAccount error=${walletFeedState.error} rpcCandidates=get_user_transactions_page_v1,get_user_transactions_summary_v1',
        );
      }

      if (monthFeedState.error != null) {
        debugPrint(
          '[WalletDetailsPage][monthFeedState] accountId=${latestWallet.id} userId=$currentUserId householdId=$effectiveHouseholdId currency=$selectedCurrencyCode startDate=${monthStart.toIso8601String()} endDate=${monthEnd.toIso8601String()} includeUnassignedAccount=$isDefaultResolvedAccount error=${monthFeedState.error} rpcCandidates=get_user_transactions_page_v1,get_user_transactions_summary_v1',
        );
      }
      return null;
    }, [
      walletFeedState.error,
      monthFeedState.error,
      latestWallet.id,
      currentUserId,
      effectiveHouseholdId,
      selectedCurrencyCode,
      isDefaultResolvedAccount,
      monthStart,
      monthEnd,
    ]);

    final scopedExpenses = walletFeedState.items;
    final recurringTransactionsById = {
      for (final transaction in recurringTransactions)
        transaction.id: transaction,
    };
    // CRITICAL: wallet recurring rows must stay bound to account_id when
    // present. Falling back to the default wallet is only correct for legacy
    // unassigned recurring rows.
    // STRICT REQUIREMENT: if this mapping is loosened, recurring transactions
    // start showing under the wrong wallet or vanish from the intended one.
    final walletRecurringTransactions =
        recurringTransactions.where((transaction) {
      final accountId = transaction.accountId?.trim();
      if (accountId != null && accountId.isNotEmpty) {
        return accountId == latestWallet.id;
      }
      return isDefaultResolvedAccount;
    }).toList(growable: false);
    final projectedRecurringRangeStart = _resolveWalletProjectedRangeStart(
      feedTransactions: scopedExpenses,
      recurringTransactions: walletRecurringTransactions,
      fallbackMonthStart: currentMonthStart,
    );
    final projectedRecurringExpenses = walletRecurringTransactions.isEmpty
        ? const <ExpenseEntry>[]
        : _projectWalletRecurringExpenses(
            recurringTransactions: walletRecurringTransactions,
            actualExpenses: scopedExpenses,
            rangeStart: projectedRecurringRangeStart,
            rangeEnd: userNow,
            selectedCurrency: selectedCurrencyCode,
            selectedCurrencies: selectedCurrencyFilters,
            wallet: latestWallet,
          );
    // CRITICAL: keep the wallet detail list aligned with the recurring-aware
    // wallet balances.
    // STRICT REQUIREMENT: do not render only the raw feed rows here, or the
    // wallet page/balance can include recurring transactions while the details
    // screen silently drops their tiles again.
    final visibleTransactions = _mergeWalletDetailTransactions(
      feedTransactions: scopedExpenses,
      projectedTransactions: projectedRecurringExpenses,
    );
    final visibleTransactionsById = {
      for (final transaction in visibleTransactions)
        transaction.id: transaction,
    };
    final displayVisibleTransactions = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            visibleTransactions,
            targetCurrency: selectedCurrencyCode,
            rates: rateTable,
          )
        : visibleTransactions;
    final projectedMonthRecurringExpenses = walletRecurringTransactions.isEmpty
        ? const <ExpenseEntry>[]
        : _projectWalletRecurringExpenses(
            recurringTransactions: walletRecurringTransactions,
            actualExpenses: monthFeedState.items,
            rangeStart: monthStart,
            rangeEnd: userNow,
            selectedCurrency: selectedCurrencyCode,
            selectedCurrencies: selectedCurrencyFilters,
            wallet: latestWallet,
          );
    final walletColor =
        parseWalletColor(latestWallet.color, colorScheme.primary);
    final gradientColors =
        AppTheme.pocketDetailsGradient(walletColor, colorScheme);
    final isBackgroundLight = gradientColors.first.computeLuminance() > 0.5;
    final textColor =
        isBackgroundLight ? AppTheme.lightForeground : AppTheme.darkForeground;
    final secondaryTextColor = textColor.withValues(alpha: 0.7);

    final snapshotBalanceCents =
        detailsMonthSnapshotAsync.valueOrNull?.walletBalances[latestWallet.id];
    final hasOptimisticBalance = serverAccount != null &&
        latestWallet.currentBalanceCents != serverAccount.currentBalanceCents;
    final currentBalanceCents = hasOptimisticBalance
        ? latestWallet.currentBalanceCents
        : snapshotBalanceCents ?? latestWallet.currentBalanceCents;
    // CRITICAL: the "this month" stat cards must include the same projected
    // recurring rows shown in the transaction list and wallet balance logic.
    // STRICT REQUIREMENT: do not switch these totals back to the raw monthFeed
    // summary, or wallet totals and visible recurring tiles will disagree.
    final monthActualExpenses = monthAllItemsAsync?.valueOrNull;
    final monthSummaryExpenses =
        shouldConvertCurrencies && monthActualExpenses != null
            ? [
                ...monthActualExpenses,
                ...dedupeProjectedRecurringExpenseEntries(
                  projectedExpenses: projectedMonthRecurringExpenses,
                  actualExpenses: monthActualExpenses,
                ),
              ]
            : projectedMonthRecurringExpenses;
    final monthSummary = shouldConvertCurrencies
        ? summarizeTransactionsInCurrency(
            monthSummaryExpenses,
            targetCurrency: selectedCurrencyCode,
            rates: rateTable,
          )
        : monthFeedState.summary
            .addingExpenses(projectedMonthRecurringExpenses);
    final totalIncome = monthSummary.incomeTotal;
    final totalSpent = monthSummary.expenseTotal;

    final net = totalIncome - totalSpent;

    Future<void> refreshWalletDetails() async {
      await ref
          .read(transactionsFeedProvider(walletFeedQuery).notifier)
          .refresh();
      await ref
          .read(transactionsFeedProvider(monthFeedQuery).notifier)
          .refresh();
      await ref
          .read(recurringTransactionsProvider(effectiveHouseholdId).notifier)
          .loadRecurringTransactions(
            currentUserId,
            forceRefresh: true,
          );
      // CRITICAL: recurring edits must refresh the recurring source list, not
      // only the generic feed.
      // STRICT REQUIREMENT: otherwise projected recurring tiles stay stale
      // after editing a recurring rule and users think the update failed.
      actions.refreshAccountData();
    }

    Future<void> handleTransactionTap(ExpenseEntry expense) async {
      final didChange = await showTransactionDetailsSheet(
        context,
        expense: expense,
        recurringTransactionsById: recurringTransactionsById,
        transferWallets: scopedAccounts,
      );
      if (didChange == true) {
        await refreshWalletDetails();
      }
    }

    Future<void> onEdit() async {
      final result =
          await showCreateEditWalletSheet(context, initial: latestWallet);
      if (result == null) return;
      if (!context.mounted) return;

      debugPrint(
        '[AccountDetails][Edit] save tapped accountId=${latestWallet.id} name=${result.name} icon=${result.icon} color=${result.color} opening=${result.openingBalanceCents} goal=${result.goalAmountCents} isDefault=${result.isDefault}',
      );

      final retargetedCurrentBalanceCents =
          retargetWalletBalanceForOpeningChange(
        previousOpeningBalanceCents: latestWallet.openingBalanceCents,
        nextOpeningBalanceCents: result.openingBalanceCents,
        currentBalanceCents: latestWallet.currentBalanceCents,
      );

      final optimisticAccount = _copyAccount(
        latestWallet,
        name: result.name,
        icon: result.icon,
        color: result.color,
        goalAmountCents: result.goalAmountCents,
        isDefault: result.isDefault,
        openingBalanceCents: result.openingBalanceCents,
        currentBalanceCents: retargetedCurrentBalanceCents,
      );

      actions.setOptimisticWallet(optimisticAccount);

      if (context.mounted) {
        AppToast.success(context, context.l10n.saveChanges);
      }

      try {
        await actions.updateAccount(
          walletId: latestWallet.id,
          name: result.name,
          icon: result.icon,
          color: result.color,
          openingBalanceCents: result.openingBalanceCents,
          goalAmountCents: result.goalAmountCents,
          includeGoalAmount: true,
          isDefault: result.isDefault,
          invalidate: false,
        );
        debugPrint(
            '[AccountDetails][Edit] refreshAccountData accountId=${latestWallet.id}');
        actions.refreshAccountData();
      } catch (error) {
        debugPrint(
            '[AccountDetails][Edit] error accountId=${latestWallet.id} error=$error');
        actions.clearOptimisticWallet(latestWallet.id);
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    Future<void> onArchive() async {
      final confirm = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.archiveThisWallet,
        description: context.l10n.archiveWalletDescription,
        confirmLabel: context.l10n.archive,
        cancelLabel: context.l10n.cancel,
      );

      if (confirm?.confirmed != true || !context.mounted) return;

      try {
        await actions.archiveAccount(latestWallet.id);
        if (!context.mounted) return;
        AppToast.success(context, context.l10n.walletArchived);
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    }

    Future<void> onTransfer() async {
      // Get all wallets for transfer selection
      final scopedAccounts =
          ref.read(scopedWalletsProvider).valueOrNull ?? const <WalletEntity>[];
      if (scopedAccounts.length < 2) {
        AppToast.info(context, context.l10n.needTwoWalletsForTransfer);
        return;
      }

      final result = await showWalletTransferSheet(
        context,
        wallets: scopedAccounts,
        defaultFromWalletId: latestWallet.id,
      );
      if (result == null) return;

      try {
        await actions.createTransfer(
          fromAccountId: result.fromAccountId,
          toAccountId: result.toAccountId,
          amountCents: result.amountCents,
          currency: selectedCurrencyCode,
          date: result.date,
          note: result.note,
        );
        if (context.mounted) {
          AppToast.success(context, context.l10n.save);
        }
        await refreshWalletDetails();
      } catch (error) {
        if (context.mounted) {
          AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
        }
      }
    }

    return Scaffold(
      backgroundColor: gradientColors.first,
      floatingActionButton: !latestWallet.isArchived
          ? Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: FloatingActionButton.extended(
                onPressed: onTransfer,
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                icon: const Icon(Icons.swap_horiz),
                label: Text(context.l10n.transfer),
              ),
            )
          : null,
      body: Stack(
        children: [
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
          AutoPaginatedScroll(
            hasMore: walletFeedState.hasMore,
            isLoading: walletFeedState.isLoading,
            isLoadingMore: walletFeedState.isLoadingMore,
            onLoadMore: () {
              ref
                  .read(transactionsFeedProvider(walletFeedQuery).notifier)
                  .loadMore();
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
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
                      onPressed: onEdit,
                    ),
                    if (!latestWallet.isSystem && !latestWallet.isArchived)
                      IconButton(
                        icon: Icon(Icons.archive_outlined, color: textColor),
                        onPressed: onArchive,
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.fadeTitle,
                    ],
                    background: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  resolveWalletIcon(latestWallet.icon),
                                  key: ValueKey(latestWallet.icon),
                                  color: textColor,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              latestWallet.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.balanceSummary,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _AnimatedAmountText(
                              value: currentBalanceCents / 100.0,
                              currencyCode: selectedCurrencyCode,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -1,
                              ),
                            ),
                            if (latestWallet.goalAmountCents != null) ...[
                              const SizedBox(height: 8),
                              _AnimatedAmountText(
                                value: latestWallet.goalAmountCents! / 100.0,
                                currencyCode: selectedCurrencyCode,
                                prefix: context.l10n.balanceSummary,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.l10n.keyInsights,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${context.l10n.thisMonth.toLowerCase()})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: context.l10n.totalIncome,
                                  amount: totalIncome,
                                  currencyCode: selectedCurrencyCode,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: context.l10n.totalSpent,
                                  amount: totalSpent,
                                  currencyCode: selectedCurrencyCode,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: context.l10n.net,
                                  amount: net,
                                  currencyCode: selectedCurrencyCode,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            context.l10n.recentTransactions,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (walletFeedState.isLoading &&
                              displayVisibleTransactions.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (walletFeedState.error != null &&
                              displayVisibleTransactions.isEmpty)
                            Center(
                              child: Text(
                                context.l10n.error(walletFeedState.error!),
                                style: TextStyle(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            )
                          else if (displayVisibleTransactions.isEmpty)
                            Center(
                              child: Text(
                                context.l10n.noTransactionsYet,
                                style: TextStyle(
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            )
                          else
                            GroupedTransactionsList(
                              transactions: displayVisibleTransactions,
                              currency: selectedCurrencyCode,
                              onTransactionTap: (expense) {
                                unawaited(handleTransactionTap(
                                  visibleTransactionsById[expense.id] ??
                                      expense,
                                ));
                              },
                            ),
                          PaginatedLoadMoreIndicator(
                            show: walletFeedState.isLoadingMore,
                          ),
                          const SizedBox(height: 40),
                        ],
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

int _compareExpensesDescending(ExpenseEntry left, ExpenseEntry right) {
  final dateCompare = right.date.compareTo(left.date);
  if (dateCompare != 0) {
    return dateCompare;
  }

  final createdAtCompare = right.createdAt.compareTo(left.createdAt);
  if (createdAtCompare != 0) {
    return createdAtCompare;
  }

  return right.id.compareTo(left.id);
}

DateTime _resolveWalletProjectedRangeStart({
  required List<ExpenseEntry> feedTransactions,
  required List<RecurringTransaction> recurringTransactions,
  required DateTime fallbackMonthStart,
}) {
  var earliest = DateTime(
    fallbackMonthStart.year,
    fallbackMonthStart.month,
    1,
  );

  for (final transaction in feedTransactions) {
    final txMonth = DateTime(transaction.date.year, transaction.date.month, 1);
    if (txMonth.isBefore(earliest)) {
      earliest = txMonth;
    }
  }

  for (final recurring in recurringTransactions) {
    final anchor = recurring.recurrenceRule?.anchorDate ?? recurring.date;
    final anchorMonth = DateTime(anchor.year, anchor.month, 1);
    if (anchorMonth.isBefore(earliest)) {
      earliest = anchorMonth;
    }
  }

  return earliest;
}

List<ExpenseEntry> _projectWalletRecurringExpenses({
  required List<RecurringTransaction> recurringTransactions,
  required List<ExpenseEntry> actualExpenses,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required String selectedCurrency,
  List<String>? selectedCurrencies,
  required WalletEntity wallet,
}) {
  // CRITICAL: wallet detail projections must be deduped against actual wallet
  // transactions before rendering.
  // STRICT REQUIREMENT: projected recurring rows are synthetic month tiles. If
  // a matching posted transaction already exists, keep the actual row and drop
  // the synthetic one to avoid duplicate wallet spend.
  return dedupeProjectedRecurringExpenseEntries(
    projectedExpenses: projectRecurringTransactionsAsExpenseEntries(
      recurringTransactions: recurringTransactions,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
    ).map((expense) {
      return expense.copyWith(
        accountId: wallet.id,
        accountName: wallet.name,
        accountIcon: wallet.icon,
        accountColor: wallet.color,
      );
    }).toList(growable: false),
    actualExpenses: actualExpenses,
  );
}

List<ExpenseEntry> _mergeWalletDetailTransactions({
  required List<ExpenseEntry> feedTransactions,
  required List<ExpenseEntry> projectedTransactions,
}) {
  // CRITICAL: this is the final merge that keeps wallet details aligned with
  // recurring-aware wallet math.
  // STRICT REQUIREMENT: do not render feedTransactions alone. That exact
  // simplification caused recurring wallet transactions to disappear from the
  // details list while balances still included them.
  final mergedById = <String, ExpenseEntry>{
    for (final transaction in projectedTransactions)
      transaction.id: transaction,
    for (final transaction in feedTransactions) transaction.id: transaction,
  };

  final merged = mergedById.values.toList(growable: false);
  merged.sort(_compareExpensesDescending);
  return merged;
}

WalletEntity _copyAccount(
  WalletEntity source, {
  String? name,
  String? icon,
  String? color,
  int? openingBalanceCents,
  int? goalAmountCents,
  bool? isDefault,
  int? currentBalanceCents,
}) {
  return WalletEntity(
    id: source.id,
    userId: source.userId,
    householdId: source.householdId,
    name: name ?? source.name,
    icon: icon ?? source.icon,
    color: color ?? source.color,
    openingBalanceCents: openingBalanceCents ?? source.openingBalanceCents,
    goalAmountCents: goalAmountCents,
    isDefault: isDefault ?? source.isDefault,
    isSystem: source.isSystem,
    isArchived: source.isArchived,
    currentBalanceCents: currentBalanceCents ?? source.currentBalanceCents,
  );
}

String? _resolveScopedHouseholdId(HouseholdScope scope) {
  switch (scope.activeAccountType) {
    case ActiveWalletType.personal:
      return null;
    case ActiveWalletType.portfolio:
      final householdId = scope.activeAccountHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return null;
      }
      return householdId;
    case ActiveWalletType.household:
      final householdId = scope.selectedHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        return null;
      }
      return householdId;
  }
}

String? _resolveDefaultAccountId(List<WalletEntity> wallets) {
  for (final wallet in wallets) {
    if (wallet.isDefault && !wallet.isArchived) {
      return wallet.id;
    }
  }
  for (final wallet in wallets) {
    if (wallet.isSystem &&
        wallet.name.trim().toLowerCase() == 'spending' &&
        !wallet.isArchived) {
      return wallet.id;
    }
  }
  return wallets.isNotEmpty ? wallets.first.id : null;
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.amount, required this.currencyCode});

  final String label;
  final double amount;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.pocketCardSurface,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 6),
          _AnimatedAmountText(
            value: amount,
            currencyCode: currencyCode,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.foreground,
              fontWeight: FontWeight.w700,
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
  final String prefix;

  const _AnimatedAmountText({
    required this.value,
    required this.currencyCode,
    required this.style,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        final formatted = _formatAmount(context, val, currencyCode);
        return Text(
          prefix.isEmpty ? formatted : '$prefix $formatted',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

String _formatAmount(BuildContext context, double amount, String currencyCode) {
  final symbol = resolveCurrencySymbol(currencyCode);
  final normalized = double.parse(formatAmount(amount));
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}
