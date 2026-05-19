import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/core/navigation/navigation_ready_provider.dart';
import 'package:moneko/core/notifications/notification_dedupe_store.dart';
import 'package:moneko/core/notifications/notification_intent.dart';
import 'package:moneko/core/notifications/notification_intent_resolver.dart';
import 'package:moneko/core/notifications/notification_pending_store.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/home/presentation/state/home_page_command_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/widgets/budget_status_sheet.dart';
import 'package:moneko/features/households/presentation/widgets/household_invitation_sheet.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_page_command_provider.dart';
import 'package:moneko/features/utils/currency.dart';

class NotificationDispatcher {
  NotificationDispatcher(
    this._ref, {
    NotificationIntentResolver? resolver,
    NotificationDedupeStore? dedupeStore,
    NotificationPendingStore? pendingStore,
    Future<bool> Function()? readinessOverride,
    String? Function()? userIdOverride,
    Future<void> Function(NotificationIntent intent)? executorOverride,
    Future<NotificationIntent> Function(NotificationIntent intent)?
        resolverOverride,
    ExpenseEntry? Function(String expenseId)? cacheLookupOverride,
    Future<ExpenseEntry?> Function(String expenseId)?
        directExpenseFetchOverride,
    void Function(ExpenseEntry expense)? cacheInjectionOverride,
    Future<ExpenseEntry?> Function(String expenseId, String userId)?
        rpcFetchOverride,
  })  : _resolver = resolver ?? NotificationIntentResolver(),
        _dedupeStore = dedupeStore ?? NotificationDedupeStore(),
        _pendingStore = pendingStore ?? NotificationPendingStore(),
        _readinessOverride = readinessOverride,
        _userIdOverride = userIdOverride,
        _executorOverride = executorOverride,
        _resolverOverride = resolverOverride,
        _cacheLookupOverride = cacheLookupOverride,
        _directExpenseFetchOverride = directExpenseFetchOverride,
        _cacheInjectionOverride = cacheInjectionOverride,
        _rpcFetchOverride = rpcFetchOverride;

  final Ref? _ref;
  final NotificationIntentResolver _resolver;
  final NotificationDedupeStore _dedupeStore;
  final NotificationPendingStore _pendingStore;
  final Future<bool> Function()? _readinessOverride;
  final String? Function()? _userIdOverride;
  final Future<void> Function(NotificationIntent intent)? _executorOverride;
  final Future<NotificationIntent> Function(NotificationIntent intent)?
      _resolverOverride;
  final ExpenseEntry? Function(String expenseId)? _cacheLookupOverride;
  final Future<ExpenseEntry?> Function(String expenseId)?
      _directExpenseFetchOverride;
  final void Function(ExpenseEntry expense)? _cacheInjectionOverride;
  final Future<ExpenseEntry?> Function(String expenseId, String userId)?
      _rpcFetchOverride;

  final Queue<NotificationIntent> _queue = Queue<NotificationIntent>();
  bool _isProcessing = false;
  int _requestCounter = 0;

  Future<void> enqueueIntent(NotificationIntent intent,
      {String source = 'unknown'}) async {
    _queue.add(intent);
    await _drainQueue();
  }

  Future<void> replayPendingIntents() async {
    final pending = await _pendingStore.loadAll();
    if (pending.isNotEmpty) {
      await _pendingStore.clear();
      for (final intent in pending) {
        _queue.add(intent);
      }
    }
    await _drainQueue();
  }

  @visibleForTesting
  Future<ExpenseEntry?> resolveExpenseForNotification({
    required String expenseId,
    required String userId,
  }) {
    return _findExpenseWithRetry(expenseId: expenseId, userId: userId);
  }

  Future<void> _drainQueue() async {
    if (_isProcessing) {
      return;
    }
    _isProcessing = true;

    try {
      while (_queue.isNotEmpty) {
        final isReady = await _awaitNavigationReady();
        if (!isReady) {
          break;
        }

        final intent = _queue.removeFirst();
        final dedupeId = intent.dedupeId;
        if (dedupeId != null && await _dedupeStore.hasHandled(dedupeId)) {
          continue;
        }

        final currentUserId = _currentUserId();
        if (intent.requiresAuth &&
            (currentUserId == null || currentUserId.isEmpty)) {
          await _pendingStore.add(intent);
          continue;
        }

        final resolved = _resolverOverride != null
            ? await _resolverOverride!(intent)
            : await _resolver.resolve(intent);

        await _execute(resolved);

        if (dedupeId != null) {
          await _dedupeStore.markHandled(dedupeId);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  String? _currentUserId() {
    if (_userIdOverride != null) {
      return _userIdOverride!();
    }
    final user = _ref?.read(authProvider);
    if (user == null) {
      return null;
    }
    return user.uid.isEmpty ? null : user.uid;
  }

  Future<bool> _awaitNavigationReady() async {
    if (_readinessOverride != null) {
      return _readinessOverride!();
    }

    final timeoutAt = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(timeoutAt)) {
      final ready = _ref?.read(navigationReadyProvider) ?? false;
      final navCtx = rootNavigatorKey.currentContext;
      if (ready && navCtx != null && navCtx.mounted) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    return false;
  }

  Future<void> _execute(NotificationIntent intent) async {
    if (_executorOverride != null) {
      await _executorOverride!(intent);
      return;
    }

    switch (intent.action) {
      case NotificationIntentAction.openExpenseSheet:
        await _openExpenseSheet(intent);
        return;
      case NotificationIntentAction.openBudgetStatus:
        await _openBudgetStatus(intent);
        return;
      case NotificationIntentAction.openHouseholdDashboard:
        await _openHouseholdDashboard(intent);
        return;
      case NotificationIntentAction.openHouseholdInvites:
        await _openHouseholdInvites(intent);
        return;
      case NotificationIntentAction.openSettlementHistory:
        await _openSettlementHistory(intent);
        return;
      case NotificationIntentAction.openRecurringEditor:
        await _openRecurringEditor(intent);
        return;
      case NotificationIntentAction.openRecurringPage:
        await _openRecurringPage(intent);
        return;
      case NotificationIntentAction.openLogExpenseQuickEntry:
        await _openLogExpenseDrawer(intent);
        return;
      case NotificationIntentAction.openPocketsPage:
        await _openPocketsPage(intent);
        return;
      case NotificationIntentAction.openInsightsPage:
        await _openInsightsPage(intent);
        return;
      case NotificationIntentAction.openHouseholdInviteAcceptance:
        await _openHouseholdInvitation(intent);
        return;
      case NotificationIntentAction.unknown:
        return;
    }
  }

  Future<void> _ensureDashboard() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    context.go('/dashboard');
  }

  Future<void> _selectHouseholdIfNeeded(String? householdId) async {
    if (householdId == null || householdId.isEmpty) {
      return;
    }
    _ref?.read(viewModeProvider.notifier).setMode(ViewMode.household);
    await _ref
        ?.read(selectedHouseholdProvider.notifier)
        .selectHousehold(householdId);
  }

  Future<void> _openExpenseSheet(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);
    _ref?.read(mainShellTabIndexProvider.notifier).state = 0;

    final user = _ref?.read(authProvider);
    if (user == null) {
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final expenseId = intent.expenseId;
    if (expenseId == null || expenseId.isEmpty) {
      if (intent.householdId != null && intent.householdId!.isNotEmpty) {
        await _openHouseholdDashboard(intent);
      }
      return;
    }

    await _ensureValidSession();

    final expense = await _findExpenseWithRetry(
      expenseId: expenseId,
      userId: user.uid,
    );

    final currentContext = rootNavigatorKey.currentContext;
    if (currentContext == null || !currentContext.mounted) {
      return;
    }

    if (expense == null) {
      if (intent.eventType == 'expense_deleted') {
        AppToast.info(currentContext, 'Expense was deleted');
      } else {
        AppToast.info(currentContext, 'Expense not found or deleted');
      }
      return;
    }

    if (user.uid.isNotEmpty) {
      unawaited(
        _ref
            ?.read(analyticsProvider.notifier)
            .loadData(user.uid, forceReload: true),
      );
    }

    await showUnifiedTransactionSheet(
      currentContext,
      existingExpense: expense,
    );
  }

  Future<ExpenseEntry?> _findExpenseWithRetry({
    required String expenseId,
    required String userId,
  }) async {
    if (userId.isEmpty) {
      return null;
    }

    final fromCache = _findExpenseInAnalyticsCache(expenseId);
    if (fromCache != null) {
      return fromCache;
    }

    final directFetch = await _fetchExpenseDirectly(expenseId);
    if (directFetch != null) {
      _injectIntoCache(directFetch);
      return directFetch;
    }

    final rpcFetch = await _fetchExpenseViaRpc(expenseId, userId);
    if (rpcFetch != null) {
      _injectIntoCache(rpcFetch);
      return rpcFetch;
    }

    await _ensureValidSession();

    final retryDirectFetch = await _fetchExpenseDirectly(expenseId);
    if (retryDirectFetch != null) {
      _injectIntoCache(retryDirectFetch);
      return retryDirectFetch;
    }

    return null;
  }

  Future<ExpenseEntry?> _fetchExpenseViaRpc(
      String expenseId, String userId) async {
    if (_rpcFetchOverride != null) {
      return _rpcFetchOverride!(expenseId, userId);
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final rpcResponse = await supabase.rpc(
          'get_user_expense_by_id_v1',
          params: {
            'p_user_id': userId,
            'p_expense_id': expenseId,
          },
        );

        if (rpcResponse is Map<String, dynamic>) {
          return ExpenseEntry.fromJson(rpcResponse);
        }

        if (attempt < 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await _ensureValidSession();
        }
      } catch (e) {
        if (attempt < 1) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await _ensureValidSession();
        }
      }
    }

    return null;
  }

  void _injectIntoCache(ExpenseEntry expense) {
    if (_cacheInjectionOverride != null) {
      _cacheInjectionOverride!(expense);
    } else {
      _ref?.read(analyticsProvider.notifier).addOptimisticTransaction(expense);
      final notifier =
          _ref?.read(transactionsFeedRefreshSignalProvider.notifier);
      if (notifier != null) {
        notifier.state += 1;
      }
    }
  }

  ExpenseEntry? _findExpenseInAnalyticsCache(String expenseId) {
    if (_cacheLookupOverride != null) {
      return _cacheLookupOverride!(expenseId);
    }

    final analytics = _ref?.read(analyticsProvider);
    if (analytics == null) {
      return null;
    }

    for (final entry in analytics.allExpenses) {
      if (entry.id == expenseId) {
        return entry;
      }
    }

    return null;
  }

  Future<ExpenseEntry?> _fetchExpenseDirectly(String expenseId) async {
    if (_directExpenseFetchOverride != null) {
      return _directExpenseFetchOverride!(expenseId);
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await supabase
            .from('expenses')
            .select(
                'id,contact_id,user_id,date,amount_cents,currency,category,created_at,raw_text,merchant,breakdown,receipt_image_url,household_id,split_group_id,account_id,type,is_recurring')
            .eq('id', expenseId)
            .maybeSingle();

        if (response != null) {
          return ExpenseEntry.fromJson(response);
        }

        if (attempt < 1) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        if (attempt < 1) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    return null;
  }

  Future<void> _ensureValidSession() async {
    try {
      await supabase.auth.refreshSession();
    } catch (_) {
      // Non-blocking: session refresh failure is not fatal.
    }
  }

  Future<void> _openBudgetStatus(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);
    _ref?.read(mainShellTabIndexProvider.notifier).state = 0;

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final spentCents =
        int.tryParse(intent.args['spent_cents']?.toString() ?? '0') ?? 0;
    final budgetCents =
        int.tryParse(intent.args['budget_cents']?.toString() ?? '0') ?? 0;
    final percent = intent.args['percentage_used']?.toString() ?? '0';
    final budgetName = intent.args['budget_name']?.toString() ?? 'Budget';

    final detail = '${formatAmount(spentCents / 100)} / '
        '${formatAmount(budgetCents / 100)} ($percent%)';

    await showBudgetStatusSheet(
      context,
      title: budgetName,
      status:
          intent.eventType == 'budget_alert' ? 'Over budget' : 'Budget warning',
      detail: detail,
      onViewBudget: () {
        _ref?.read(mainShellTabIndexProvider.notifier).state = 2;
      },
      onOpenHousehold: () {
        _openHouseholdDashboard(intent);
      },
    );
  }

  Future<void> _openHouseholdDashboard(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);
    _ref?.read(mainShellTabIndexProvider.notifier).state = 0;

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final message = intent.toastMessage;
    if (message != null && message.isNotEmpty) {
      AppToast.info(context, message);
    }
  }

  Future<void> _openHouseholdInvites(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final householdId = intent.householdId;
    if (householdId == null || householdId.isEmpty) {
      return;
    }
    context.push('/households/$householdId/invites');
  }

  Future<void> _openSettlementHistory(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final householdId = intent.householdId;
    if (householdId == null || householdId.isEmpty) {
      return;
    }
    context.push('/households/$householdId/settlements');
  }

  Future<void> _openRecurringEditor(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);

    final recurringId = intent.recurringId;
    if (recurringId == null || recurringId.isEmpty) {
      return;
    }

    _ref?.read(mainShellTabIndexProvider.notifier).state = 1;
    _requestCounter += 1;
    _ref?.read(recurringPageCommandProvider.notifier).state =
        RecurringPageCommand(
      recurringId: recurringId,
      recurringType: intent.recurringType,
      requestId: _requestCounter,
    );
  }

  Future<void> _openRecurringPage(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);
    _ref?.read(mainShellTabIndexProvider.notifier).state = 1;
  }

  Future<void> _openLogExpenseDrawer(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);

    _ref?.read(mainShellTabIndexProvider.notifier).state = 0;
    _requestCounter += 1;
    _ref?.read(homePageCommandProvider.notifier).state = HomePageCommand(
        HomePageCommandType.showLogExpenseDrawer,
        requestId: _requestCounter);
  }

  Future<void> _openPocketsPage(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);
    _ref?.read(mainShellTabIndexProvider.notifier).state = 2;
  }

  Future<void> _openInsightsPage(NotificationIntent intent) async {
    await _ensureDashboard();
    await _selectHouseholdIfNeeded(intent.householdId);
    _ref?.read(mainShellTabIndexProvider.notifier).state = 4;
  }

  Future<void> _openHouseholdInvitation(NotificationIntent intent) async {
    final context = rootNavigatorKey.currentContext;
    final token = intent.inviteToken;
    if (context == null || !context.mounted || token == null || token.isEmpty) {
      return;
    }

    await showHouseholdInvitationSheet(context, token: token);
  }
}

final notificationDispatcherProvider = Provider<NotificationDispatcher>((ref) {
  return NotificationDispatcher(ref);
});
