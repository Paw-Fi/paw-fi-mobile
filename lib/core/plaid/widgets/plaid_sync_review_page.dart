import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/plaid/models/bank_sync_review_session.dart';
import 'package:moneko/core/plaid/models/synced_transaction.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_connections_provider.dart';
import 'package:moneko/features/home/presentation/state/bank_sync_result_provider.dart';
import 'package:moneko/features/home/presentation/state/currency_transaction_counts_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/import/presentation/widgets/import_category_apply_helper.dart';
import 'package:moneko/features/import/presentation/widgets/import_edit_row_sheet.dart';
import 'package:moneko/features/import/presentation/widgets/persisted_transaction_editing_helper.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/presentation/widgets/create_edit_wallet_sheet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_stack_card.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/shimmering_text.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlaidSyncReviewPage extends ConsumerStatefulWidget {
  const PlaidSyncReviewPage({
    super.key,
    required this.session,
  });

  final BankSyncReviewSession session;

  @override
  ConsumerState<PlaidSyncReviewPage> createState() =>
      _PlaidSyncReviewPageState();
}

class _PlaidSyncReviewPageState extends ConsumerState<PlaidSyncReviewPage> {
  static const Duration _syncPollInterval = Duration(seconds: 2);
  static const Duration _syncWaitTimeout = Duration(seconds: 45);

  late List<BankSyncReviewAccount> _accounts;
  late String _selectedBankAccountId;
  List<SyncedTransaction> _transactions = const [];
  PlaidSyncStatus? _syncStatus;
  bool _isPreparing = true;
  bool _isUpdatingWallet = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _accounts = widget.session.accounts;
    _selectedBankAccountId =
        _accounts.isEmpty ? '' : _accounts.first.bankAccountId;
    // _prepareReview reads localized strings via context.l10n, so it must
    // start after the first frame instead of during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_prepareReview());
    });
  }

  BankSyncReviewAccount? get _selectedAccount {
    for (final account in _accounts) {
      if (account.bankAccountId == _selectedBankAccountId) {
        return account;
      }
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  List<SyncedTransaction> get _selectedTransactions {
    final selected = _selectedAccount;
    if (selected == null) {
      return const [];
    }

    return _transactions
        .where((tx) => tx.expense.bankAccountId == selected.bankAccountId)
        .toList(growable: false);
  }

  bool get _isTransactionsStillSyncing {
    if (_isPreparing || widget.session.provider != 'plaid') {
      return false;
    }

    return _syncStatus?.initialUpdateComplete == false;
  }

  bool get _canCompleteReview {
    return _canDismissReview && !_isTransactionsStillSyncing;
  }

  bool get _canDismissReview {
    return !_isPreparing && !_isUpdatingWallet && _errorMessage == null;
  }

  int _displayBalanceCentsForAccount(BankSyncReviewAccount account) {
    final syncedDeltaCents = _transactions
        .where((item) => item.expense.bankAccountId == account.bankAccountId)
        .fold<int>(0, (sum, item) {
      final type = (item.expense.type ?? 'expense').toLowerCase();
      final signedAmount = type == 'income'
          ? item.expense.amountCents
          : -item.expense.amountCents;
      return sum + signedAmount;
    });

    return account.openingBalanceCents + syncedDeltaCents;
  }

  Future<void> _prepareReview() async {
    if (!mounted) return;
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      await _ensureLinkedWallets();
      final result = await _awaitBackendSyncAndLoadTransactions();
      final resolvedCurrency = _resolveCurrencyCode(result.transactions);

      ref.read(bankSyncResultProvider.notifier).state = BankSyncResult(
        currencyCode: resolvedCurrency,
      );
      try {
        await _refreshAfterSync();
      } catch (error) {
        if (mounted) {
          AppToast.error(context, error.toString());
        }
      }

      if (!mounted) return;
      setState(() {
        _transactions = result.transactions;
        _syncStatus = result.syncStatus;
        _isPreparing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _ensureLinkedWallets() async {
    final client = Supabase.instance.client;
    final l10n = context.l10n;
    final updatedAccounts = <BankSyncReviewAccount>[];

    for (final account in _accounts) {
      if (account.hasLinkedWallet) {
        updatedAccounts.add(account);
        continue;
      }

      final response = await client.functions.invoke(
        'save-wallet',
        body: {
          'name': account.walletName,
          'icon': account.walletIcon,
          'color': account.walletColor,
          'openingBalanceCents': account.openingBalanceCents,
          'goalAmountCents': account.goalAmountCents,
          'isDefault': account.isDefault,
          'linkedBankAccountId': account.bankAccountId,
          if (widget.session.targetHouseholdId != null)
            'householdId': widget.session.targetHouseholdId,
        },
      );

      final payload = response.data as Map<String, dynamic>?;
      if (response.status >= 400 ||
          payload == null ||
          payload['success'] != true) {
        final message =
            payload?['error']?.toString() ?? l10n.failedToCreateLinkedWallet;
        throw Exception(message);
      }

      final walletData = payload['data'] as Map<String, dynamic>?;
      final updatedAccount = account.copyWith(
        walletId: walletData?['id'] as String?,
        walletName: (walletData?['name'] as String?)?.trim(),
        walletIcon: (walletData?['icon'] as String?)?.trim(),
        walletColor: (walletData?['color'] as String?)?.trim(),
        goalAmountCents: (walletData?['goal_amount_cents'] as num?)?.round(),
        openingBalanceCents:
            (walletData?['opening_balance_cents'] as num?)?.round(),
        isDefault: walletData?['is_default'] == true,
      );
      updatedAccounts.add(updatedAccount);
      _accounts = List<BankSyncReviewAccount>.from(updatedAccounts)
        ..addAll(_accounts.skip(updatedAccounts.length));
    }

    _accounts = updatedAccounts;
  }

  Future<ParsedSyncedTransactions>
      _awaitBackendSyncAndLoadTransactions() async {
    final deadline = DateTime.now().add(_syncWaitTimeout);
    final reconnectMessage = context.l10n.thisBankNeedsToBeReconnected;
    PlaidSyncStatus? latestSyncStatus;
    var attemptedDirectPlaidFetch = false;

    while (DateTime.now().isBefore(deadline)) {
      final snapshot = await _fetchConnectionSyncSnapshot();
      latestSyncStatus = snapshot.syncStatus ?? latestSyncStatus;

      if (snapshot.requiresReconnect) {
        throw Exception(reconnectMessage);
      }

      final transactions = await _loadSyncedTransactionsFromDatabase();
      final isStillWaitingForPlaidImport =
          transactions.isEmpty && _isPlaidStillImporting(snapshot.syncStatus);
      if (transactions.isNotEmpty) {
        return ParsedSyncedTransactions(
          transactions: transactions,
          syncStatus: latestSyncStatus,
        );
      }

      if (widget.session.provider == 'plaid' && !attemptedDirectPlaidFetch) {
        attemptedDirectPlaidFetch = true;
        final directResult = await _loadTransactionsFromPlaidSyncFunction();
        latestSyncStatus = directResult.syncStatus ?? latestSyncStatus;

        if (directResult.requiresReconnect) {
          throw Exception(reconnectMessage);
        }

        if (directResult.transactions.isNotEmpty) {
          return ParsedSyncedTransactions(
            transactions: directResult.transactions,
            syncStatus: latestSyncStatus,
          );
        }
      }

      if (snapshot.lastSuccessfulSyncAt != null &&
          !isStillWaitingForPlaidImport) {
        return ParsedSyncedTransactions(
          transactions: const [],
          syncStatus: latestSyncStatus,
        );
      }

      await Future<void>.delayed(_syncPollInterval);
    }

    final fallbackTransactions = await _loadSyncedTransactionsFromDatabase();
    if (fallbackTransactions.isNotEmpty || widget.session.provider != 'plaid') {
      return ParsedSyncedTransactions(
        transactions: fallbackTransactions,
        syncStatus: latestSyncStatus,
      );
    }

    final directResult = await _loadTransactionsFromPlaidSyncFunction();
    return ParsedSyncedTransactions(
      transactions: directResult.transactions,
      syncStatus: directResult.syncStatus ?? latestSyncStatus,
    );
  }

  Future<void> _refreshAfterSync() async {
    final user = ref.read(authProvider);
    if (user.uid.isEmpty) return;

    ref.invalidate(bankConnectionsProvider);
    ref.read(walletActionsProvider).refreshAccountData();
    ref.invalidate(currencyTransactionCountsProvider);
    ref.invalidate(pocketsProvider);
    if (widget.session.targetHouseholdId != null) {
      ref.invalidate(userHouseholdsProvider(user.uid));
      ref.invalidate(householdExpensesProvider);
      ref.invalidate(householdSplitsProvider);
      ref.invalidate(householdBudgetsProvider);
      ref.invalidate(householdMembersProvider);
    }
    await ref
        .read(recurringTransactionsProvider(widget.session.targetHouseholdId)
            .notifier)
        .refresh(user.uid);
    await ref.read(analyticsProvider.notifier).loadData(
          user.uid,
          forceReload: true,
        );
  }

  Future<void> _editSelectedWallet() async {
    final selected = _selectedAccount;
    if (selected == null || !selected.hasLinkedWallet) {
      return;
    }

    final user = ref.read(authProvider);
    final result = await showCreateEditWalletSheet(
      context,
      initial: WalletEntity(
        id: selected.walletId!,
        userId: user.uid,
        householdId: widget.session.targetHouseholdId,
        name: selected.walletName,
        icon: selected.walletIcon,
        color: selected.walletColor,
        openingBalanceCents: selected.openingBalanceCents,
        goalAmountCents: selected.goalAmountCents,
        isDefault: selected.isDefault,
        isSystem: false,
        isArchived: false,
        currentBalanceCents: 0,
      ),
    );

    if (result == null) return;

    setState(() => _isUpdatingWallet = true);
    try {
      await ref.read(walletActionsProvider).updateAccount(
            walletId: selected.walletId!,
            name: result.name,
            icon: result.icon,
            color: result.color,
            openingBalanceCents: result.openingBalanceCents,
            goalAmountCents: result.goalAmountCents,
            includeGoalAmount: true,
            isDefault: result.isDefault,
          );

      if (!mounted) return;
      setState(() {
        _accounts = _accounts.map((account) {
          if (account.bankAccountId != selected.bankAccountId) {
            return account;
          }

          return account.copyWith(
            walletName: result.name,
            walletIcon: result.icon,
            walletColor: result.color,
            openingBalanceCents: result.openingBalanceCents,
            goalAmountCents: result.goalAmountCents,
            isDefault: result.isDefault,
          );
        }).toList(growable: false);
        _isUpdatingWallet = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingWallet = false);
      AppToast.error(context, error.toString());
    }
  }

  Future<void> _deleteTransaction(SyncedTransaction transaction) async {
    final user = ref.read(authProvider);
    final l10n = context.l10n;
    final response = await Supabase.instance.client.functions.invoke(
      'delete-expense',
      body: {
        'userId': user.uid,
        'expenseIds': transaction.expense.id,
      },
    );

    final payload = response.data as Map<String, dynamic>?;
    final success = response.status < 400 &&
        (payload?['success'] == true || payload == null);
    if (!success) {
      final message =
          payload?['error']?.toString() ?? l10n.failedToDeleteTransaction;
      if (!mounted) return;
      AppToast.error(context, message);
      return;
    }

    if (!mounted) return;
    setState(() {
      _transactions = _transactions
          .where((item) => item.expense.id != transaction.expense.id)
          .toList(growable: false);
    });
  }

  Future<void> _editTransaction(SyncedTransaction transaction) async {
    bool isSaving = false;
    final sheetKey = GlobalKey<EditRowSheetState>();
    final originalCategory =
        normalizeEditableCategory(transaction.expense.category);

    final result = await MonekoBottomSheet.show<dynamic>(
      context: context,
      isScrollControlled: true,
      title: context.l10n.importEditRowTitle,
      onClose: () {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      onConfirm: () async {
        if (isSaving) return;
        isSaving = true;
        try {
          await sheetKey.currentState?.save();
        } catch (error) {
          isSaving = false;
          if (!mounted) return;
          AppToast.error(context, error.toString());
        }
      },
      builder: (sheetContext) {
        return EditRowSheet(
          key: sheetKey,
          row: buildImportParsedRowFromExpense(
            expense: transaction.expense,
            index: _transactions.indexWhere(
              (item) => item.expense.id == transaction.expense.id,
            ),
          ),
          showTypeToggle: false,
          onSave: (updatedRow) async {
            isSaving = true;
            final updatedExpense = await updatePersistedExpenseFromImportRow(
              expense: transaction.expense,
              row: updatedRow,
            );
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop(updatedExpense);
            }
          },
        );
      },
    );

    if (result == 'delete') {
      await _deleteTransaction(transaction);
      return;
    }

    if (result is! ExpenseEntry || !mounted) {
      return;
    }

    setState(() {
      _transactions = _transactions.map((item) {
        if (item.expense.id != transaction.expense.id) {
          return item;
        }

        return SyncedTransaction(
          expense: result,
          isRecurring: result.isRecurring,
          recurrenceRule: item.recurrenceRule,
        );
      }).toList(growable: false);
    });

    final newCategory = normalizeEditableCategory(result.category);
    if (newCategory.toLowerCase() != originalCategory.toLowerCase() &&
        mounted) {
      await _maybeApplyCategoryToAll(
        originalCategory: originalCategory,
        newCategory: newCategory,
      );
    }
  }

  Future<void> _maybeApplyCategoryToAll({
    required String originalCategory,
    required String newCategory,
  }) async {
    final normalizedOriginal = originalCategory.trim().toLowerCase();

    final matchingTransactions = _transactions.where((t) {
      final txCategory =
          normalizeEditableCategory(t.expense.category).toLowerCase();
      return txCategory == normalizedOriginal;
    }).toList();

    final shouldApply = await confirmApplyCategoryToAll(
      context: context,
      matchingCount: matchingTransactions.length,
      originalCategory: originalCategory,
      newCategory: newCategory,
    );

    if (shouldApply && mounted) {
      await _applyCategoryToAllTransactions(matchingTransactions, newCategory);
    }
  }

  Future<void> _applyCategoryToAllTransactions(
    List<SyncedTransaction> transactions,
    String newCategory,
  ) async {
    try {
      final batchResult = await updatePersistedExpensesInChunks(
        expenses:
            transactions.map((transaction) => transaction.expense).toList(),
        buildRow: (expense, index) => buildImportParsedRowFromExpense(
          expense: expense,
          index: index,
        ),
        transformRow: (row) => row.copyWith(category: newCategory),
        updateExpense: (expense, row) => updatePersistedExpenseFromImportRow(
          expense: expense,
          row: row,
        ),
      );

      await _refreshTransactionsAfterBatchUpdate(batchResult.updatedExpenses);

      if (!mounted) {
        return;
      }

      if (batchResult.updatedExpenses.isNotEmpty &&
          batchResult.failures.isEmpty) {
        AppToast.success(
          context,
          context.l10n.updatedTransactionsCount(
            batchResult.updatedExpenses.length.toString(),
          ),
        );
        return;
      }

      if (batchResult.updatedExpenses.isNotEmpty) {
        AppToast.error(
          context,
          context.l10n.failedToUpdateSomeTransactions(
            'Updated ${batchResult.updatedExpenses.length}, failed ${batchResult.failures.length}.',
          ),
        );
        return;
      }

      if (batchResult.failures.isNotEmpty) {
        AppToast.error(
          context,
          context.l10n.failedToUpdateSomeTransactions(
            batchResult.failures.first.error.toString(),
          ),
        );
        return;
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(context,
            context.l10n.failedToUpdateSomeTransactions(error.toString()));
      }
    }
  }

  Future<void> _refreshTransactionsAfterBatchUpdate(
    List<ExpenseEntry> updatedExpenses,
  ) async {
    if (updatedExpenses.isEmpty || !mounted) return;

    final updatedExpensesById = {
      for (final expense in updatedExpenses) expense.id: expense,
    };

    setState(() {
      _transactions = _transactions.map((item) {
        final updatedExpense = updatedExpensesById[item.expense.id];
        if (updatedExpense == null) {
          return item;
        }
        return SyncedTransaction(
          expense: updatedExpense,
          isRecurring: updatedExpense.isRecurring,
          recurrenceRule: item.recurrenceRule,
        );
      }).toList(growable: false);
    });
  }

  Future<_ConnectionSyncSnapshot> _fetchConnectionSyncSnapshot() async {
    final row = await Supabase.instance.client.rpc(
      'get_mobile_bank_connection_sync_snapshot',
      params: {'p_connection_id': widget.session.connectionId},
    ).maybeSingle();

    if (row == null) {
      return const _ConnectionSyncSnapshot();
    }

    final metadata = row['metadata'];
    final metadataMap =
        metadata is Map<String, dynamic> ? metadata : <String, dynamic>{};
    final syncStatus = _parseConnectionSyncStatus(metadataMap);

    return _ConnectionSyncSnapshot(
      requiresReconnect: row['status'] == 'needs_reauth' ||
          row['relink_state'] == 'required' ||
          row['item_status'] == 'pending_relink',
      lastSuccessfulSyncAt: row['last_successful_sync_at'] != null
          ? DateTime.tryParse(row['last_successful_sync_at'].toString())
          : null,
      syncStatus: syncStatus,
    );
  }

  Future<List<SyncedTransaction>> _loadSyncedTransactionsFromDatabase() async {
    final bankAccountIds = _accounts
        .map((account) => account.bankAccountId)
        .toList(growable: false);
    if (bankAccountIds.isEmpty) {
      return const [];
    }

    var query = Supabase.instance.client
        .from('expenses')
        .select(
          'id, contact_id, user_id, household_id, date, amount_cents, currency, '
          'category, created_at, updated_at, raw_text, merchant, bank_account_id, '
          'account_id, type, is_recurring, recurrence_rule',
        )
        .inFilter('bank_account_id', bankAccountIds)
        .isFilter('deleted_at', null);

    if (widget.session.targetHouseholdId == null) {
      query = query.isFilter('household_id', null);
    } else {
      query = query.eq('household_id', widget.session.targetHouseholdId!);
    }

    final rows = await query.order('date', ascending: false).limit(200);

    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((row) => SyncedTransaction(
              expense: ExpenseEntry.fromJson(row),
              isRecurring: row['is_recurring'] == true,
              recurrenceRule: row['recurrence_rule'] as Map<String, dynamic>?,
            ))
        .toList(growable: false);
  }

  Future<_DirectPlaidFetchResult>
      _loadTransactionsFromPlaidSyncFunction() async {
    final response = await Supabase.instance.client.functions.invoke(
      'plaid-sync-transactions',
      body: {
        'connectionId': widget.session.connectionId,
        if (widget.session.targetHouseholdId != null)
          'targetHouseholdId': widget.session.targetHouseholdId,
      },
    );

    if (response.status >= 400) {
      return const _DirectPlaidFetchResult(transactions: []);
    }

    final parsed = parseSyncedTransactionPayload(response.data);
    return _DirectPlaidFetchResult(
      transactions: parsed.transactions,
      syncStatus: parsed.syncStatus,
      requiresReconnect: _payloadRequiresReconnect(response.data),
    );
  }

  Future<void> _handleDone() async {
    if (!_canDismissReview) {
      return;
    }

    try {
      await _refreshAfterSync();
    } catch (_) {}

    if (_isTransactionsStillSyncing && mounted) {
      AppToast.info(
        context,
        context.l10n.plaidStillSyncingBackground,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedAccount;
    final grouped = _groupByMonth(_selectedTransactions);
    final monthKeys = grouped.keys.toList()
      ..sort((a, b) => b.asDate.compareTo(a.asDate));
    final showHistoricalSyncBanner = !_isPreparing &&
        _errorMessage == null &&
        widget.session.provider == 'plaid' &&
        _shouldShowHistoricalSyncStatus(_syncStatus);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_canDismissReview) {
          return;
        }
        unawaited(_handleDone());
      },
      child: Scaffold(
        backgroundColor: colorScheme.appBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: colorScheme.appBackground,
          elevation: 0,
          leading: _canDismissReview
              ? IconButton(
                  onPressed: () => unawaited(_handleDone()),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                )
              : const SizedBox.shrink(),
          title: Text(
            selected == null ? context.l10n.transactions : selected.walletName,
          ),
        ),
        body: SafeArea(
          child: _errorMessage != null
              ? _ReviewErrorState(
                  message: _errorMessage!,
                  onRetry: _prepareReview,
                )
              : _isPreparing
                  ? _ReviewLoadingState(
                      accountName: selected?.walletName,
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (_accounts.length > 1)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemBuilder: (context, index) {
                                    final account = _accounts[index];
                                    final isSelected = account.bankAccountId ==
                                        _selectedBankAccountId;
                                    return ChoiceChip(
                                      label: Text(account.displayName),
                                      selected: isSelected,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedBankAccountId =
                                              account.bankAccountId;
                                        });
                                      },
                                    );
                                  },
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemCount: _accounts.length,
                                ),
                              ),
                            ),
                          ),
                        if (selected != null)
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _WalletHeaderDelegate(
                              account: selected,
                              displayBalanceCents:
                                  _displayBalanceCentsForAccount(selected),
                              isBusy: _isPreparing || _isUpdatingWallet,
                              onEdit: _editSelectedWallet,
                            ),
                          ),
                        if (showHistoricalSyncBanner)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                12,
                              ),
                              child: _HistoricalSyncStatusCard(
                                syncStatus: _syncStatus!,
                              ),
                            ),
                          ),
                        if (_selectedTransactions.isEmpty &&
                            _isTransactionsStillSyncing)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _ReviewLoadingState(
                              accountName: selected?.walletName,
                              title:
                                  context.l10n.plaidStillImportingTransactions,
                              description: context.l10n.keepScreenOpenForImport,
                            ),
                          )
                        else if (_selectedTransactions.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  context.l10n.noTransactionsFound,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            sliver: SliverList.list(
                              children: [
                                for (final month in monthKeys)
                                  _MonthSection(
                                    title: DateFormat('MMMM yyyy').format(
                                      month.asDate,
                                    ),
                                    transactions: grouped[month]!,
                                    onDelete: _deleteTransaction,
                                    onEdit: _editTransaction,
                                  ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                      ],
                    ),
        ),
        bottomNavigationBar: _canCompleteReview
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _handleDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(context.l10n.done),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

bool _isPlaidStillImporting(PlaidSyncStatus? syncStatus) {
  if (syncStatus == null) {
    return false;
  }

  return syncStatus.initialUpdateComplete != true ||
      syncStatus.historicalUpdateComplete != true;
}

bool _shouldShowHistoricalSyncStatus(PlaidSyncStatus? syncStatus) {
  if (syncStatus == null) {
    return false;
  }

  return syncStatus.initialUpdateComplete == false ||
      syncStatus.historicalUpdateComplete == false;
}

bool _payloadRequiresReconnect(dynamic payload) {
  if (payload is! Map<String, dynamic>) {
    return false;
  }

  final connections = payload['connections'];
  if (connections is! List) {
    return false;
  }

  for (final item in connections.whereType<Map<String, dynamic>>()) {
    final error = item['error']?.toString().toLowerCase() ?? '';
    if (error.contains('login is required') ||
        error.contains('re-authentication') ||
        error.contains('reconnected')) {
      return true;
    }
  }

  return false;
}

PlaidSyncStatus? _parseConnectionSyncStatus(Map<String, dynamic> metadata) {
  final nested = metadata['plaid_sync_status'];
  final syncStatus =
      nested is Map<String, dynamic> ? nested : <String, dynamic>{};
  final initialUpdateComplete = syncStatus['initial_update_complete'] as bool?;
  final historicalUpdateComplete =
      syncStatus['historical_update_complete'] as bool?;
  final webhookCode = syncStatus['webhook_code']?.toString();
  final updatedAt =
      DateTime.tryParse(syncStatus['updated_at']?.toString() ?? '');

  if (initialUpdateComplete == null &&
      historicalUpdateComplete == null &&
      webhookCode == null &&
      updatedAt == null) {
    return null;
  }

  return PlaidSyncStatus(
    initialUpdateComplete: initialUpdateComplete,
    historicalUpdateComplete: historicalUpdateComplete,
    webhookCode: webhookCode,
    updatedAt: updatedAt,
  );
}

class _ConnectionSyncSnapshot {
  const _ConnectionSyncSnapshot({
    this.requiresReconnect = false,
    this.lastSuccessfulSyncAt,
    this.syncStatus,
  });

  final bool requiresReconnect;
  final DateTime? lastSuccessfulSyncAt;
  final PlaidSyncStatus? syncStatus;
}

class _DirectPlaidFetchResult {
  const _DirectPlaidFetchResult({
    required this.transactions,
    this.syncStatus,
    this.requiresReconnect = false,
  });

  final List<SyncedTransaction> transactions;
  final PlaidSyncStatus? syncStatus;
  final bool requiresReconnect;
}

class _WalletHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _WalletHeaderDelegate({
    required this.account,
    required this.displayBalanceCents,
    required this.isBusy,
    required this.onEdit,
  });

  final BankSyncReviewAccount account;
  final int displayBalanceCents;
  final bool isBusy;
  final VoidCallback onEdit;

  @override
  double get minExtent => 131;

  @override
  double get maxExtent => 276;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = ((shrinkOffset) / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final easedProgress = Curves.easeOutCubic.transform(progress);
    final cardHeight = lerpDouble(260, 90, easedProgress)!;

    return ColoredBox(
      color: colorScheme.appBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: cardHeight,
            child: _ReviewWalletCard(
              account: account,
              displayBalanceCents: displayBalanceCents,
              isBusy: isBusy,
              onEdit: onEdit,
              isExpanded: easedProgress < 0.45,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _WalletHeaderDelegate oldDelegate) {
    return account != oldDelegate.account ||
        displayBalanceCents != oldDelegate.displayBalanceCents ||
        isBusy != oldDelegate.isBusy;
  }
}

class _ReviewWalletCard extends StatelessWidget {
  const _ReviewWalletCard({
    required this.account,
    required this.displayBalanceCents,
    required this.isBusy,
    required this.onEdit,
    required this.isExpanded,
  });

  final BankSyncReviewAccount account;
  final int displayBalanceCents;
  final bool isBusy;
  final VoidCallback onEdit;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return WalletStackCard(
      wallet: WalletEntity(
        id: account.walletId ?? account.bankAccountId,
        userId: '',
        householdId: null,
        name: account.walletName,
        icon: account.walletIcon,
        color: account.walletColor,
        openingBalanceCents: account.openingBalanceCents,
        goalAmountCents: account.goalAmountCents,
        isDefault: account.isDefault,
        isSystem: false,
        isArchived: false,
        currentBalanceCents: displayBalanceCents,
      ),
      currencyCode: account.currency,
      displayBalanceCents: displayBalanceCents,
      isExpanded: isExpanded,
      subtitle: account.displayName,
      showBalanceChevron: false,
      headerAction: TextButton(
        onPressed: isBusy ? null : onEdit,
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.foreground,
          backgroundColor: colorScheme.surface.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(color: colorScheme.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: Text(
          context.l10n.edit,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _HistoricalSyncStatusCard extends StatelessWidget {
  const _HistoricalSyncStatusCard({
    required this.syncStatus,
  });

  final PlaidSyncStatus? syncStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final initialComplete = syncStatus?.initialUpdateComplete;
    final title = initialComplete == false
        ? l10n.plaidStillPreparingFirstDownload
        : l10n.recentTransactionsReadyHistoricalSyncing;
    final description = initialComplete == false
        ? l10n.keepWalletConnectedForBackgroundImport
        : l10n.newestActivityAvailableOlderBackground;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.sheetBorder),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    height: 1.4,
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

class _ReviewLoadingState extends StatelessWidget {
  const _ReviewLoadingState({
    required this.accountName,
    this.title,
    this.description,
  });

  final String? accountName;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShimmeringText(
              text: title ??
                  (accountName == null
                      ? l10n.preparingBankSync
                      : l10n.syncingTransactionsIntoWallet(accountName!)),
              style: TextStyle(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description ?? l10n.creatingWalletLinksAndImportingTransactions,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewErrorState extends StatelessWidget {
  const _ReviewErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.destructive,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.foreground),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

Map<_MonthKey, List<SyncedTransaction>> _groupByMonth(
  List<SyncedTransaction> items,
) {
  final map = <_MonthKey, List<SyncedTransaction>>{};
  for (final tx in items) {
    final key = _MonthKey(tx.expense.date.year, tx.expense.date.month);
    map.putIfAbsent(key, () => []).add(tx);
  }
  for (final entry in map.entries) {
    entry.value.sort((a, b) => b.expense.date.compareTo(a.expense.date));
  }
  return map;
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.title,
    required this.transactions,
    required this.onDelete,
    required this.onEdit,
  });

  final String title;
  final List<SyncedTransaction> transactions;
  final Future<void> Function(SyncedTransaction) onDelete;
  final Future<void> Function(SyncedTransaction) onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: colorScheme.surface.withValues(alpha: 0.0),
          ),
          child: ExpansionTile(
            iconColor: colorScheme.mutedForeground,
            collapsedIconColor: colorScheme.mutedForeground,
            initiallyExpanded: true,
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            children: [
              for (final tx in transactions)
                Slidable(
                  key: ValueKey(tx.expense.id),
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.22,
                    children: [
                      SlidableAction(
                        onPressed: (_) => onDelete(tx),
                        backgroundColor: colorScheme.destructive,
                        foregroundColor: colorScheme.onError,
                        icon: Icons.delete,
                        label: context.l10n.delete,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                  child: buildExpenseTransactionTile(
                    context: context,
                    category: tx.expense.category,
                    rawText: tx.expense.rawText ?? tx.expense.merchant,
                    date: tx.expense.date,
                    amount: tx.expense.amount,
                    currency: tx.expense.currency ?? 'USD',
                    isIncome: (tx.expense.type ?? 'expense').toLowerCase() ==
                        'income',
                    onTap: () => onEdit(tx),
                    showRecurringChip: tx.isRecurring,
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthKey {
  _MonthKey(this.year, this.month);

  final int year;
  final int month;

  DateTime get asDate => DateTime(year, month, 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MonthKey && year == other.year && month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

String? _resolveCurrencyCode(List<SyncedTransaction> transactions) {
  for (final transaction in transactions) {
    final currency = transaction.expense.currency?.trim().toUpperCase();
    if (currency != null && currency.isNotEmpty) {
      return currency;
    }
  }
  return null;
}
