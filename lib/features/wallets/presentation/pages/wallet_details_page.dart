import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/plaid/pages/plaid_sync_walkthrough_page.dart';
import 'package:moneko/core/plaid/plaid_countries.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/bank_account.dart';
import 'package:moneko/features/home/presentation/models/bank_connection.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/utils/wallet_snapshot_math.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_transfer_sheet.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/bank_accounts_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/grouped_transactions_list.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/moneko_overflow_menu_button.dart';
import 'package:moneko/shared/widgets/transaction_details_sheet_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletDetailsPage extends HookConsumerWidget {
  const WalletDetailsPage({
    super.key,
    required this.wallet,
  });

  final WalletEntity wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final scrollController = useScrollController();
    final actions = ref.watch(walletActionsProvider);
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
    final walletCurrencyCode = latestWallet.currency;
    final householdScope = ref.watch(householdScopeProvider);
    final walletsScopeQuery = ref.watch(walletsScopeQueryProvider);
    final financialMonthStartDay = walletsScopeQuery.financialMonthStartDay;
    final effectiveHouseholdId = _resolveScopedHouseholdId(householdScope);
    final bankConnectionsAsync = ref.watch(bankConnectionsProvider);
    final bankAccountsAsync = ref.watch(bankAccountsProvider);
    final shouldShowBankSyncStatus = isPlaidSupportedTimezone(
      preferredTimezone,
    );
    final isManualSyncingState = useState<bool>(false);
    final plaidConnections =
        (bankConnectionsAsync.valueOrNull ?? const <BankConnection>[])
            .where(
              (connection) =>
                  connection.provider?.toLowerCase().trim() == 'plaid',
            )
            .toList(growable: false);
    final scopedPlaidConnections = plaidConnections
        .where(
          (connection) =>
              _isConnectionInWalletsScope(connection, householdScope),
        )
        .toList(growable: false);
    final linkedBankAccountId = latestWallet.linkedBankAccountId?.trim();
    final hasLinkedBankAccount =
        linkedBankAccountId != null && linkedBankAccountId.isNotEmpty;
    final linkedBankAccount = hasLinkedBankAccount
        ? _findLinkedBankAccount(
            bankAccountsAsync.valueOrNull ?? const <BankAccount>[],
            linkedBankAccountId,
          )
        : null;
    final linkedBankConnectionId = linkedBankAccount?.bankConnectionId?.trim();
    final walletPlaidConnections =
        linkedBankConnectionId == null || linkedBankConnectionId.isEmpty
            ? const <BankConnection>[]
            : scopedPlaidConnections
                .where((connection) => connection.id == linkedBankConnectionId)
                .toList(growable: false);
    final hasPlaidConnections = walletPlaidConnections.isNotEmpty;
    final hasPendingPlaidRemoval = walletPlaidConnections.any(
      (connection) => connection.isPendingRemoval,
    );
    final scopedPlaidActionConnections = walletPlaidConnections
        .where(
          (connection) => connection.requiresUserAction,
        )
        .toList(growable: false);
    final removablePlaidConnections = walletPlaidConnections
        .where((connection) => !connection.isPendingRemoval)
        .toList(growable: false);
    final manualSyncCandidates = walletPlaidConnections
        .where(
          (connection) => connection.canRequestManualRefresh,
        )
        .toList(growable: false);
    final nowUtc = DateTime.now().toUtc();
    final latestSuccessfulSyncAt =
        _latestSuccessfulSyncAt(walletPlaidConnections);
    final bankSyncStatusLabel = !hasLinkedBankAccount
        ? null
        : bankAccountsAsync.isLoading && !bankAccountsAsync.hasValue
            ? context.l10n.checkingBankSync
            : _bankSyncStatusLabel(
                context: context,
                nowUtc: nowUtc,
                bankConnectionsAsync: bankConnectionsAsync,
                hasScopedPlaidConnections: hasPlaidConnections,
                hasPendingRemoval: hasPendingPlaidRemoval,
                actionConnections: scopedPlaidActionConnections,
                latestSuccessfulSyncAt: latestSuccessfulSyncAt,
              );
    final currencyScopedAccounts = ref
            .watch(walletsByCurrencyProvider(WalletsCurrencyQuery(
              householdId: effectiveHouseholdId,
              currency: walletCurrencyCode,
            )))
            .valueOrNull ??
        const <WalletEntity>[];
    final currentMonthStart = financialCycleStartForDate(
      userNow,
      startDay: financialMonthStartDay,
    );
    final walletFeedQuery = TransactionsFeedQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: walletCurrencyCode,
      selectedCurrencies: <String>[walletCurrencyCode],
      selectedCategory: null,
      selectedAccountId: latestWallet.id,
      selectedCategories: null,
      includeUnassignedAccount: false,
      selectedType: 'all',
      searchQuery: '',
      startDate: null,
      endDate: null,
      pageSize: 200,
    );
    final walletFeedState =
        ref.watch(transactionsFeedProvider(walletFeedQuery));

    final monthStart = currentMonthStart;
    final monthEnd = nextFinancialCycleStart(
      monthStart,
      startDay: financialMonthStartDay,
    ).subtract(const Duration(days: 1));
    final monthFeedQuery = walletFeedQuery.copyWith(
      startDate: monthStart,
      endDate: monthEnd,
    );
    final monthFeedState = ref.watch(transactionsFeedProvider(monthFeedQuery));
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
          '[WalletDetailsPage][transactionsFeedProvider] accountId=${latestWallet.id} userId=$currentUserId householdId=$effectiveHouseholdId currency=$walletCurrencyCode includeUnassignedAccount=false error=${walletFeedState.error} rpcCandidates=get_user_transactions_page_v1,get_user_transactions_summary_v1',
        );
      }

      if (monthFeedState.error != null) {
        debugPrint(
          '[WalletDetailsPage][monthFeedState] accountId=${latestWallet.id} userId=$currentUserId householdId=$effectiveHouseholdId currency=$walletCurrencyCode startDate=${monthStart.toIso8601String()} endDate=${monthEnd.toIso8601String()} includeUnassignedAccount=false error=${monthFeedState.error} rpcCandidates=get_user_transactions_page_v1,get_user_transactions_summary_v1',
        );
      }
      return null;
    }, [
      walletFeedState.error,
      monthFeedState.error,
      latestWallet.id,
      currentUserId,
      effectiveHouseholdId,
      walletCurrencyCode,
      monthStart,
      monthEnd,
    ]);

    final scopedExpenses = walletFeedState.items;
    final recurringTransactionsById = {
      for (final transaction in recurringTransactions)
        transaction.id: transaction,
    };
    // Wallet details are strict row-level views: only rows explicitly bound to
    // this wallet may appear here.
    final walletRecurringTransactions =
        recurringTransactions.where((transaction) {
      final accountId = transaction.accountId?.trim();
      return accountId != null &&
          accountId.isNotEmpty &&
          accountId == latestWallet.id;
    }).toList(growable: false);
    final projectedRecurringRangeStart = _resolveWalletProjectedRangeStart(
      feedTransactions: scopedExpenses,
      recurringTransactions: walletRecurringTransactions,
      fallbackMonthStart: currentMonthStart,
      financialMonthStartDay: financialMonthStartDay,
    );
    final projectedRecurringExpenses = walletRecurringTransactions.isEmpty
        ? const <ExpenseEntry>[]
        : _projectWalletRecurringExpenses(
            recurringTransactions: walletRecurringTransactions,
            actualExpenses: scopedExpenses,
            rangeStart: projectedRecurringRangeStart,
            rangeEnd: userNow,
            selectedCurrency: walletCurrencyCode,
            selectedCurrencies: <String>[walletCurrencyCode],
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
    final displayVisibleTransactions = visibleTransactions;
    final visibleTransactionsSignature =
        groupedTransactionEntriesSignature(displayVisibleTransactions);
    final visibleTransactionsById = useMemoized(
      () => {
        for (final transaction in visibleTransactions)
          transaction.id: transaction,
      },
      [visibleTransactionsSignature],
    );
    final visibleListItems = useMemoized(
      () => buildGroupedTransactionRenderItems(
        displayVisibleTransactions,
        financialMonthStartDay: financialMonthStartDay,
      ),
      [visibleTransactionsSignature, financialMonthStartDay],
    );
    final visibleListItemIndexByKey = useMemoized(
      () => buildGroupedTransactionRenderItemIndexByKey(visibleListItems),
      [visibleListItems],
    );
    final projectedMonthRecurringExpenses = walletRecurringTransactions.isEmpty
        ? const <ExpenseEntry>[]
        : _projectWalletRecurringExpenses(
            recurringTransactions: walletRecurringTransactions,
            actualExpenses: monthFeedState.items,
            rangeStart: monthStart,
            rangeEnd: userNow,
            selectedCurrency: walletCurrencyCode,
            selectedCurrencies: <String>[walletCurrencyCode],
            wallet: latestWallet,
          );
    final walletColor =
        parseWalletColor(latestWallet.color, colorScheme.primary);
    final gradientColors =
        AppTheme.pocketDetailsGradient(walletColor, colorScheme);

    // Determine text color based on background luminance
    final isBackgroundLight = gradientColors.first.computeLuminance() > 0.5;
    final textColor =
        isBackgroundLight ? AppTheme.lightForeground : AppTheme.darkForeground;
    final secondaryTextColor = textColor.withValues(alpha: 0.7);

    final currentBalanceCents = latestWallet.currentBalanceCents;
    // CRITICAL: the "this month" stat cards must include the same projected
    // recurring rows shown in the transaction list and wallet balance logic.
    // STRICT REQUIREMENT: do not switch these totals back to the raw monthFeed
    // summary, or wallet totals and visible recurring tiles will disagree.
    final monthSummary =
        monthFeedState.summary.addingExpenses(projectedMonthRecurringExpenses);
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

    Future<void> refreshWalletsAfterPlaidFlow() async {
      ref.invalidate(bankConnectionsProvider);
      ref.invalidate(bankAccountsProvider);
      await Future.wait([
        ref.read(scopedWalletsProvider.notifier).refreshFromNetwork(),
        ref
            .read(walletsPageStateProvider(walletsScopeQuery).notifier)
            .refresh(),
        refreshWalletDetails(),
      ]);
    }

    Future<void> onReviewBankAction() async {
      final selectedConnection = await _selectPlaidActionConnection(
        context,
        scopedPlaidActionConnections,
      );
      if (selectedConnection == null || !context.mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaidSyncWalkthroughPage(
            targetHouseholdId: _resolveScopedHouseholdId(householdScope),
            connectionId: selectedConnection.id,
            flowReason: selectedConnection.relinkState,
          ),
        ),
      );
      if (!context.mounted) {
        return;
      }
      await refreshWalletsAfterPlaidFlow();
    }

    Future<void> onDisconnectBank() async {
      final selectedConnection = await _selectDisconnectBankConnection(
        context,
        removablePlaidConnections,
      );
      if (selectedConnection == null || !context.mounted) {
        return;
      }

      final confirmation = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.disconnectBankQuestion,
        description: context.l10n.disconnectBankDescription,
        confirmLabel: context.l10n.disconnect,
        cancelLabel: context.l10n.cancel,
        isDestructive: true,
      );
      if (confirmation?.confirmed != true || !context.mounted) {
        return;
      }

      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.disconnectingBank,
      );

      try {
        final response = await supabase.functions.invoke(
          'plaid-item-control',
          body: {
            'action': 'remove_item',
            'connectionId': selectedConnection.id,
            'reason': 'user_disconnect',
          },
        );

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        final responseData = response.data;
        final payload =
            responseData is Map<String, dynamic> ? responseData : null;
        if (response.status >= 400) {
          if (!context.mounted) {
            return;
          }
          AppToast.error(
            context,
            payload?['error']?.toString() ??
                context.l10n.couldNotDisconnectThisBankRightNow,
          );
          return;
        }

        await refreshWalletsAfterPlaidFlow();

        if (!context.mounted) {
          return;
        }
        final status = payload?['status']?.toString().trim();
        if (status == 'pending_removal') {
          final message = payload?['message']?.toString().trim();
          AppToast.info(
            context,
            message != null && message.isNotEmpty
                ? message
                : context.l10n.bankDisconnectQueuedDescription,
          );
        } else {
          AppToast.success(
            context,
            context.l10n.bankDisconnectedSyncsDisabled,
          );
        }
      } catch (error, stackTrace) {
        final debugId = _functionErrorDebugId(error);
        debugPrint(
          '[wallets] Plaid disconnect failed '
          'connectionId=${selectedConnection.id} '
          'debugId=${debugId ?? '<none>'} '
          'error=$error\n$stackTrace',
        );
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          AppToast.error(
            context,
            ErrorHandler.getUserFriendlyMessage(error),
          );
        }
      }
    }

    Future<void> onManualBankSync() async {
      if (bankConnectionsAsync.isLoading && !bankConnectionsAsync.hasValue) {
        AppToast.info(
          context,
          context.l10n.checkingBankConnectionStatusTryAgain,
        );
        return;
      }

      if (!hasPlaidConnections) {
        await MonekoAlertDialog.show(
          context: context,
          title: context.l10n.bankConnectionUnavailable,
          description: context.l10n.walletNotLinkedToActiveBankConnection,
          confirmLabel: context.l10n.gotIt,
          showCancelButton: false,
        );
        return;
      }

      if (hasPendingPlaidRemoval) {
        await MonekoAlertDialog.show(
          context: context,
          title: context.l10n.disconnectPending,
          description: context.l10n.bankAlreadyQueuedForPlaidRemoval,
          confirmLabel: context.l10n.gotIt,
          showCancelButton: false,
        );
        return;
      }

      if (manualSyncCandidates.isEmpty) {
        await MonekoAlertDialog.show(
          context: context,
          title: context.l10n.syncUnavailable,
          description: context.l10n.bankNeedsAttentionBeforeSync,
          confirmLabel: context.l10n.gotIt,
          showCancelButton: false,
        );
        return;
      }

      final selectedConnection = await _selectManualSyncBankConnection(
        context,
        manualSyncCandidates,
        DateTime.now().toUtc(),
      );
      if (selectedConnection == null || !context.mounted) {
        return;
      }

      final nowForCooldown = DateTime.now().toUtc();
      final remaining = _manualSyncRemaining(
        selectedConnection,
        nowForCooldown,
      );
      if (remaining != null) {
        await MonekoAlertDialog.show(
          context: context,
          title: context.l10n.syncUnavailable,
          description: context.l10n.youCannotSyncMoreThanOncePerDay(
            _formatDurationCompact(context, remaining),
          ),
          confirmLabel: context.l10n.gotIt,
          showCancelButton: false,
        );
        return;
      }

      isManualSyncingState.value = true;
      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.requestingBankRefresh,
      );

      try {
        final response = await supabase.functions.invoke(
          'plaid-item-control',
          body: {
            'action': 'request_refresh',
            'connectionId': selectedConnection.id,
          },
        );
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        final payload = response.data as Map<String, dynamic>?;
        if (response.status >= 400) {
          if (!context.mounted) {
            return;
          }
          final reason = payload?['reason']?.toString();
          if (reason == 'cooldown_active') {
            await MonekoAlertDialog.show(
              context: context,
              title: context.l10n.syncUnavailable,
              description: context.l10n.cannotRequestAnotherPlaidRefreshYet,
              confirmLabel: context.l10n.gotIt,
              showCancelButton: false,
            );
            return;
          }
          if (reason == 'trial_blocked') {
            await MonekoAlertDialog.show(
              context: context,
              title: context.l10n.refreshUnavailable,
              description: context.l10n.manualPlaidRefreshPaidUsersOnly,
              confirmLabel: context.l10n.gotIt,
              showCancelButton: false,
            );
            return;
          }
          AppToast.error(
            context,
            payload?['error']?.toString() ??
                context.l10n.couldNotSyncThisBankRightNow,
          );
          return;
        }

        await refreshWalletsAfterPlaidFlow();

        if (!context.mounted) {
          return;
        }
        AppToast.success(
          context,
          context.l10n.refreshRequestedPlaidWillNotify,
        );
      } catch (error) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          AppToast.error(
            context,
            ErrorHandler.getUserFriendlyMessage(error),
          );
        }
      } finally {
        isManualSyncingState.value = false;
      }
    }

    Future<void> handleTransactionTap(ExpenseEntry expense) async {
      final didChange = await showTransactionDetailsSheet(
        context,
        expense: expense,
        recurringTransactionsById: recurringTransactionsById,
        transferWallets: currencyScopedAccounts,
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
        '[AccountDetails][Edit] save tapped accountId=${latestWallet.id} name=${result.name} icon=${result.icon} color=${result.color} logo=${result.logoUrl} opening=${result.openingBalanceCents} goal=${result.goalAmountCents} isDefault=${result.isDefault}',
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
        logoUrl: result.logoUrl,
        currency: latestWallet.currency,
        goalAmountCents: result.goalAmountCents,
        isDefault: result.isDefault,
        openingBalanceCents: result.openingBalanceCents,
        currentBalanceCents: retargetedCurrentBalanceCents,
      );

      actions.setOptimisticWallet(optimisticAccount);

      try {
        await actions.updateAccount(
          walletId: latestWallet.id,
          name: result.name,
          icon: result.icon,
          color: result.color,
          logoUrl: result.logoUrl,
          includeLogoUrl: true,
          openingBalanceCents: result.openingBalanceCents,
          goalAmountCents: result.goalAmountCents,
          includeGoalAmount: true,
          isDefault: result.isDefault,
          invalidate: false,
        );
        if (context.mounted) {
          AppToast.success(context, context.l10n.saveChanges);
        }
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

      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.paywallProcessing,
      );

      try {
        await actions.archiveAccount(latestWallet.id);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (!context.mounted) return;
        AppToast.success(context, context.l10n.walletArchived);
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    }

    Future<void> onDeleteWallet() async {
      final confirm = await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.deleteWalletTitle,
        description: context.l10n.deleteWalletDescription,
        confirmLabel: context.l10n.delete,
        cancelLabel: context.l10n.cancel,
        isDestructive: true,
      );

      if (confirm?.confirmed != true || !context.mounted) return;

      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.deletingWallet,
      );

      try {
        await actions.deleteAccount(latestWallet.id);
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (!context.mounted) return;
        AppToast.success(context, context.l10n.walletDeleted);
        Navigator.of(context).pop(true);
      } catch (error) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        AppToast.error(
          context,
          ErrorHandler.getUserFriendlyMessage(error),
        );
      }
    }

    Future<void> onTransfer() async {
      // Get all wallets for transfer selection
      final scopedAccounts =
          ref.read(scopedWalletsProvider).valueOrNull ?? const <WalletEntity>[];
      final transferWallets = scopedAccounts
          .where((wallet) => wallet.currency == latestWallet.currency)
          .toList(growable: false);
      if (transferWallets.length < 2) {
        AppToast.info(context, context.l10n.needTwoWalletsForTransfer);
        return;
      }

      final result = await showWalletTransferSheet(
        context,
        wallets: transferWallets,
        defaultFromWalletId: latestWallet.id,
      );
      if (result == null) return;

      try {
        await actions.createTransfer(
          fromAccountId: result.fromAccountId,
          toAccountId: result.toAccountId,
          amountCents: result.amountCents,
          currency: result.currency,
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

    final walletMenuItems = <AdaptivePopupMenuEntry>[
      AdaptivePopupMenuItem<String>(
        label: context.l10n.edit,
        icon: PlatformInfo.isIOS26OrHigher() ? 'pencil' : Icons.edit,
        value: 'edit',
      ),
      if (!latestWallet.isSystem && !latestWallet.isArchived)
        AdaptivePopupMenuItem<String>(
          label: context.l10n.archive,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'archivebox'
              : Icons.archive_outlined,
          value: 'archive',
        ),
      if (!latestWallet.isSystem)
        AdaptivePopupMenuItem<String>(
          label: context.l10n.delete,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'trash'
              : Icons.delete_outline_rounded,
          value: 'delete',
        ),
      if (scopedPlaidActionConnections.isNotEmpty)
        AdaptivePopupMenuItem<String>(
          label: scopedPlaidActionConnections.every(
            (connection) => connection.hasNewAccountsAvailable,
          )
              ? context.l10n.reviewBankUpdates
              : context.l10n.reconnectBank,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'arrow.clockwise'
              : Icons.refresh_rounded,
          value: 'review_bank',
        ),
      if (removablePlaidConnections.isNotEmpty)
        AdaptivePopupMenuItem<String>(
          label: context.l10n.disconnectBank,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'xmark.circle'
              : Icons.link_off_rounded,
          value: 'disconnect_bank',
        ),
      if (bankSyncStatusLabel != null)
        AdaptivePopupMenuItem<String>(
          label: context.l10n.syncBank,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'arrow.triangle.2.circlepath'
              : Icons.sync_rounded,
          value: 'sync_bank',
        ),
    ];

    void handleWalletMenuSelected(
      int _,
      AdaptivePopupMenuItem<String> item,
    ) {
      switch (item.value) {
        case 'edit':
          unawaited(onEdit());
          break;
        case 'archive':
          unawaited(onArchive());
          break;
        case 'delete':
          unawaited(onDeleteWallet());
          break;
        case 'review_bank':
          unawaited(onReviewBankAction());
          break;
        case 'disconnect_bank':
          unawaited(onDisconnectBank());
          break;
        case 'sync_bank':
          unawaited(onManualBankSync());
          break;
      }
    }

    final walletOverflowMenu = MonekoOverflowMenuButton<String>(
      items: walletMenuItems,
      onSelected: handleWalletMenuSelected,
      tint: textColor,
      buttonStyle: PopupButtonStyle.plain,
    );

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
              controller: scrollController,
              key: PageStorageKey('wallet_details_scroll_${latestWallet.id}'),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  expandedHeight:
                      shouldShowBankSyncStatus && bankSyncStatusLabel != null
                          ? 332
                          : 300,
                  pinned: true,
                  stretch: true,
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    walletOverflowMenu,
                    const SizedBox(width: 8),
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
                            WalletLogoAvatar(
                              logoUrl: latestWallet.logoUrl,
                              icon: resolveWalletIcon(latestWallet.icon),
                              baseColor: walletColor,
                              size: 56,
                              iconSize: 26,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              latestWallet.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.balanceSummary,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _AnimatedAmountText(
                              value: currentBalanceCents / 100.0,
                              currencyCode: walletCurrencyCode,
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                letterSpacing: -1.5,
                              ),
                            ),
                            if (latestWallet.goalAmountCents != null) ...[
                              const SizedBox(height: 8),
                              _AnimatedAmountText(
                                value: latestWallet.goalAmountCents! / 100.0,
                                currencyCode: walletCurrencyCode,
                                prefix: context.l10n.balanceSummary,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (shouldShowBankSyncStatus &&
                                bankSyncStatusLabel != null) ...[
                              const SizedBox(height: 12),
                              _WalletBankSyncStatusText(
                                label: bankSyncStatusLabel,
                                onSync: isManualSyncingState.value
                                    ? null
                                    : onManualBankSync,
                                textColor: secondaryTextColor,
                              ),
                            ],
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.l10n.keyInsights,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${context.l10n.thisMonth.toLowerCase()})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
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
                                currencyCode: walletCurrencyCode,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                label: context.l10n.totalSpent,
                                amount: totalSpent,
                                currencyCode: walletCurrencyCode,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _StatCard(
                          label: context.l10n.net,
                          amount: net,
                          currencyCode: walletCurrencyCode,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          context.l10n.recentTransactions,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (walletFeedState.isLoading &&
                    displayVisibleTransactions.isEmpty)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  )
                else if (walletFeedState.error != null &&
                    displayVisibleTransactions.isEmpty)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.l10n.error(walletFeedState.error!),
                            style: TextStyle(
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (displayVisibleTransactions.isEmpty)
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colorScheme.sheetBackground,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 64, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 32,
                                color: colorScheme.mutedForeground
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.noTransactionsYet,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.mutedForeground,
                                ),
                              ),
                            ],
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
                    currency: walletCurrencyCode,
                    preferredTimezone: preferredTimezone,
                    backgroundColor: colorScheme.sheetBackground,
                    showCurrencyFlag: false,
                    onTransactionTap: (expense) {
                      unawaited(handleTransactionTap(
                        visibleTransactionsById[expense.id] ?? expense,
                      ));
                    },
                  ),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: colorScheme.sheetBackground,
                    child: PaginatedLoadMoreIndicator(
                      show: walletFeedState.isLoadingMore,
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
  required int financialMonthStartDay,
}) {
  var earliest = financialCycleStartForDate(
    fallbackMonthStart,
    startDay: financialMonthStartDay,
  );

  for (final transaction in feedTransactions) {
    final txCycleStart = financialCycleStartForDate(
      transaction.date,
      startDay: financialMonthStartDay,
    );
    if (txCycleStart.isBefore(earliest)) {
      earliest = txCycleStart;
    }
  }

  for (final recurring in recurringTransactions) {
    final anchor = recurring.recurrenceRule?.anchorDate ?? recurring.date;
    final anchorCycleStart = financialCycleStartForDate(
      anchor,
      startDay: financialMonthStartDay,
    );
    if (anchorCycleStart.isBefore(earliest)) {
      earliest = anchorCycleStart;
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
  String? logoUrl,
  String? currency,
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
    logoUrl: logoUrl,
    currency: currency ?? source.currency,
    openingBalanceCents: openingBalanceCents ?? source.openingBalanceCents,
    goalAmountCents: goalAmountCents,
    isDefault: isDefault ?? source.isDefault,
    isSystem: source.isSystem,
    isArchived: source.isArchived,
    currentBalanceCents: currentBalanceCents ?? source.currentBalanceCents,
    linkedBankAccountId: source.linkedBankAccountId,
  );
}

BankAccount? _findLinkedBankAccount(
  List<BankAccount> bankAccounts,
  String linkedBankAccountId,
) {
  for (final bankAccount in bankAccounts) {
    if (bankAccount.id == linkedBankAccountId) {
      return bankAccount;
    }
  }
  return null;
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

bool _isConnectionInWalletsScope(
  BankConnection connection,
  HouseholdScope scope,
) {
  final scopeHouseholdId = _resolveScopedHouseholdId(scope);
  if (scopeHouseholdId == null) {
    return connection.householdId == null || connection.householdId!.isEmpty;
  }

  return connection.householdId == scopeHouseholdId;
}

Future<BankConnection?> _selectPlaidActionConnection(
  BuildContext context,
  List<BankConnection> connections,
) async {
  if (connections.isEmpty) {
    return null;
  }

  if (connections.length == 1) {
    return connections.first;
  }

  return showModalBottomSheet<BankConnection>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.sheetBackground,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.chooseBankToReview,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.openBankConnectionNeedsAttention,
                style: TextStyle(color: colorScheme.mutedForeground),
              ),
              const SizedBox(height: 16),
              for (final connection in connections)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.account_balance_rounded,
                    color: colorScheme.primary,
                  ),
                  title: Text(_bankConnectionDisplayName(context, connection)),
                  subtitle: Text(_bankConnectionActionDescription(
                    context,
                    connection,
                  )),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(connection),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<BankConnection?> _selectDisconnectBankConnection(
  BuildContext context,
  List<BankConnection> connections,
) async {
  if (connections.isEmpty) {
    return null;
  }

  if (connections.length == 1) {
    return connections.first;
  }

  return showModalBottomSheet<BankConnection>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.sheetBackground,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.chooseBankToDisconnect,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.disconnectingRemovesPlaidAccess,
                style: TextStyle(color: colorScheme.mutedForeground),
              ),
              const SizedBox(height: 16),
              for (final connection in connections)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.link_off_rounded,
                    color: colorScheme.destructive,
                  ),
                  title: Text(_bankConnectionDisplayName(context, connection)),
                  subtitle: Text(context.l10n.disconnectPlaidAccess),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(connection),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<BankConnection?> _selectManualSyncBankConnection(
  BuildContext context,
  List<BankConnection> connections,
  DateTime nowUtc,
) async {
  if (connections.isEmpty) {
    AppToast.info(
      context,
      context.l10n.noConnectedBankAvailableForManualSync,
    );
    return null;
  }

  if (connections.length == 1) {
    return connections.first;
  }

  return showModalBottomSheet<BankConnection>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.sheetBackground,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.chooseBankToSync,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.manualSyncPullsLatestTransactions,
                style: TextStyle(color: colorScheme.mutedForeground),
              ),
              const SizedBox(height: 16),
              for (final connection in connections)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.account_balance_rounded,
                    color: colorScheme.primary,
                  ),
                  title: Text(_bankConnectionDisplayName(context, connection)),
                  subtitle: Text(
                    _manualSyncRemaining(connection, nowUtc) == null
                        ? context.l10n.syncNowAvailable
                        : context.l10n.availableInDuration(
                            _formatDurationCompact(
                              context,
                              _manualSyncRemaining(connection, nowUtc)!,
                            ),
                          ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(connection),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Duration? _manualSyncRemaining(BankConnection connection, DateTime nowUtc) {
  final nextEligibleAt = connection.nextManualRefreshEligibleAt?.toUtc() ??
      connection.lastSuccessfulSyncAt?.toUtc().add(const Duration(hours: 24));
  if (nextEligibleAt == null) {
    return null;
  }

  if (!nextEligibleAt.isAfter(nowUtc)) {
    return null;
  }

  return nextEligibleAt.difference(nowUtc);
}

DateTime? _latestSuccessfulSyncAt(List<BankConnection> connections) {
  DateTime? latest;
  for (final connection in connections) {
    final value = connection.lastSuccessfulSyncAt;
    if (value == null) {
      continue;
    }
    if (latest == null || value.isAfter(latest)) {
      latest = value;
    }
  }
  return latest;
}

String _formatRelativeTimeAgo(
  BuildContext context,
  DateTime nowUtc,
  DateTime timestamp,
) {
  final difference = nowUtc.difference(timestamp.toUtc());
  if (difference.inMinutes < 1) {
    return context.l10n.justNow;
  }
  if (difference.inHours < 1) {
    return context.l10n.minutesShort(difference.inMinutes.toString());
  }
  if (difference.inDays < 1) {
    return context.l10n.hoursShort(difference.inHours.toString());
  }
  return context.l10n.daysShort(difference.inDays.toString());
}

String _formatLastSyncLabel(
  BuildContext context,
  DateTime nowUtc,
  DateTime timestamp,
) {
  final relative = _formatRelativeTimeAgo(context, nowUtc, timestamp);
  if (relative == context.l10n.justNow) {
    return context.l10n.lastSyncJustNow;
  }
  return context.l10n.lastSyncAgo(relative);
}

String? _bankSyncStatusLabel({
  required BuildContext context,
  required DateTime nowUtc,
  required AsyncValue<List<BankConnection>> bankConnectionsAsync,
  required bool hasScopedPlaidConnections,
  required bool hasPendingRemoval,
  required List<BankConnection> actionConnections,
  required DateTime? latestSuccessfulSyncAt,
}) {
  if (bankConnectionsAsync.isLoading && !bankConnectionsAsync.hasValue) {
    return context.l10n.checkingBankSync;
  }
  if (bankConnectionsAsync.hasError && !bankConnectionsAsync.hasValue) {
    return context.l10n.bankSyncStatusUnavailable;
  }
  if (!hasScopedPlaidConnections) {
    return context.l10n.bankConnectionUnavailable;
  }
  if (hasPendingRemoval) {
    return context.l10n.bankDisconnectPending;
  }
  if (actionConnections.isNotEmpty) {
    if (actionConnections
        .every((connection) => connection.hasNewAccountsAvailable)) {
      return context.l10n.bankUpdatesAvailable;
    }
    return context.l10n.bankNeedsAttention;
  }
  if (latestSuccessfulSyncAt == null) {
    return context.l10n.bankConnectedInitialSyncPending;
  }
  return _formatLastSyncLabel(context, nowUtc, latestSuccessfulSyncAt);
}

String _bankConnectionDisplayName(
  BuildContext context,
  BankConnection connection,
) {
  return connection.displayNameOr(context.l10n.bankConnection);
}

String _bankConnectionActionDescription(
  BuildContext context,
  BankConnection connection,
) {
  return connection.actionDescription(
    newAccountsAvailable: context.l10n.newBankAccountsAvailableToReview,
    needsRepair: context.l10n.bankNeedsRepairBeforeSyncing,
  );
}

String? _functionErrorDebugId(Object error) {
  if (error is! FunctionException) {
    return null;
  }

  final details = error.details;
  if (details is! Map) {
    return null;
  }

  final debugId = details['debugId']?.toString().trim();
  return debugId == null || debugId.isEmpty ? null : debugId;
}

String _formatDurationCompact(BuildContext context, Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes <= 0) {
    return context.l10n.lessThanOneMinuteShort;
  }

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours <= 0) {
    return context.l10n.minutesShort(minutes.toString());
  }
  if (minutes == 0) {
    return context.l10n.hoursShort(hours.toString());
  }
  return context.l10n.hoursMinutesShort(
    hours.toString(),
    minutes.toString(),
  );
}

class _WalletBankSyncStatusText extends StatelessWidget {
  const _WalletBankSyncStatusText({
    required this.label,
    required this.onSync,
    required this.textColor,
  });

  final String label;
  final VoidCallback? onSync;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onSync != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSync,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _AnimatedAmountText(
              value: amount,
              currencyCode: currencyCode,
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
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
