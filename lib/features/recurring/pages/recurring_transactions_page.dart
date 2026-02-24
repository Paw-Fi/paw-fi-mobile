import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart' as foundation;

import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_page_command_provider.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/user_timezone.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

/// Modern recurring transactions page with Apple-inspired design
/// Features tabbed interface for expenses and income
class RecurringTransactionsPage extends ConsumerStatefulWidget {
  const RecurringTransactionsPage({super.key});

  @override
  ConsumerState<RecurringTransactionsPage> createState() =>
      _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState
    extends ConsumerState<RecurringTransactionsPage> {
  final GlobalKey _recurringFabSpotlightKey = GlobalKey();
  final GlobalKey _recurringTabBarSpotlightKey = GlobalKey();
  late SpotlightTourController _recurringTourController;
  Locale? _recurringTourLocale;
  bool _didInitRecurringTour = false;

  /// Force refresh (used by pull-to-refresh)
  Future<void> _refresh(String? householdId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Force refresh the unified list for current scope
    await ref
        .read(recurringTransactionsProvider(householdId).notifier)
        .refresh(user.id);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_didInitRecurringTour && _recurringTourLocale == locale) return;

    _recurringTourController = SpotlightTourController(
      tourId: 'recurring_transactions_v1',
      steps: [
        SpotlightStep(
          id: 'recurring_fab',
          targetKey: _recurringFabSpotlightKey,
          title: context.l10n.recurringTourFabTitle,
          description: context.l10n.recurringTourFabDescription,
          placement: SpotlightPlacement.top,
          padding: 6,
          borderRadius: 34,
        ),
        SpotlightStep(
          id: 'recurring_tab_bar',
          targetKey: _recurringTabBarSpotlightKey,
          title: context.l10n.recurringTourTabsTitle,
          description: context.l10n.recurringTourTabsDescription,
          placement: SpotlightPlacement.bottom,
          padding: 6,
          borderRadius: 24,
        ),
      ],
    );
    _recurringTourLocale = locale;
    _didInitRecurringTour = true;
  }

  Future<void> _startRecurringTourIfNeeded(int currentTabIndex) async {
    if (!_didInitRecurringTour || currentTabIndex != 1) return;
    if (supabase.auth.currentUser == null) return;

    await _recurringTourController.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = supabase.auth.currentUser;
    final currentTabIndex = ref.watch(mainShellTabIndexProvider);

    // Use householdScopeProvider to properly handle portfolio households
    // Portfolio households (is_portfolio=true) are treated as personal, not household
    final householdScope = ref.watch(householdScopeProvider);
    final String? householdId = switch (householdScope.activeAccountType) {
      ActiveAccountType.personal => null,
      ActiveAccountType.portfolio => householdScope.activeAccountHouseholdId,
      ActiveAccountType.household => householdScope.selectedHouseholdId,
    };

    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _debugPrint('🏠 [RecurringPage] BUILD');
    _debugPrint('   IsHouseholdView: ${householdScope.isHouseholdView}');
    _debugPrint('   IsPersonalView: ${householdScope.isPersonalView}');
    _debugPrint(
        '   IsPortfolioSelected: ${householdScope.isPortfolioSelected}');
    _debugPrint('   HouseholdId: $householdId');
    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Ensure data is loaded for this scope
    final state = ref.watch(recurringTransactionsProvider(householdId));

    _debugPrint('📊 [RecurringPage] Provider State:');
    _debugPrint('   HasLoadedOnce: ${state.hasLoadedOnce}');
    _debugPrint('   IsLoading: ${state.data.isLoading}');
    _debugPrint('   HasValue: ${state.data.hasValue}');
    _debugPrint('   HasError: ${state.data.hasError}');
    if (state.data.hasValue) {
      _debugPrint('   Data count: ${state.data.value?.length ?? 0}');
    }

    if (user != null && !state.hasLoadedOnce && !state.data.isLoading) {
      _debugPrint('🚀 [RecurringPage] Triggering initial load...');
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .loadRecurringTransactions(user.id);
      });
    } else {
      _debugPrint(
          '⏭️  [RecurringPage] Not triggering load (hasLoadedOnce=${state.hasLoadedOnce}, isLoading=${state.data.isLoading})');
    }

    // Watch the filtered providers (they derive from the unified provider)
    final recurringExpenses = ref.watch(recurringExpensesProvider(householdId));
    final recurringIncomes = ref.watch(recurringIncomesProvider(householdId));
    ref.listen<RecurringPageCommand?>(recurringPageCommandProvider,
        (previous, next) {
      if (next == null) {
        return;
      }

      Future<void>.microtask(() => _handleRecurringCommand(next, householdId));
    });
    final selectedCurrency =
        ref.watch(homeFilterProvider).selectedCurrency?.toUpperCase();
    final preferredTimezone = ref
        .watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
    final userNow = effectiveNow(preferredTimezone: preferredTimezone);

    if (currentTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startRecurringTourIfNeeded(currentTabIndex);
      });
    }

    return AdaptiveScaffold(
      body: Column(
        children: [
          Expanded(
            child: MonekoTabBarView(
              tabs: [
                context.l10n.expenses,
                context.l10n.income,
              ],
              tabBarKey: _recurringTabBarSpotlightKey,
              children: [
                _buildRecurringTabView(
                  colorScheme,
                  _buildExpensesSliver(
                    recurringExpenses,
                    colorScheme,
                    selectedCurrency,
                    householdId,
                    userNow,
                  ),
                  householdId,
                  recurringExpenses.isLoading,
                ),
                _buildRecurringTabView(
                  colorScheme,
                  _buildIncomesSliver(
                    recurringIncomes,
                    colorScheme,
                    selectedCurrency,
                    householdId,
                    userNow,
                  ),
                  householdId,
                  recurringIncomes.isLoading,
                ),
              ],
              onTabChanged: (index) {
                ref.read(selectedRecurringTabProvider.notifier).state = index;
              },
            ),
          ),
        ],
      ),

      // Floating action button
      floatingActionButton: Padding(
        key: _recurringFabSpotlightKey,
        padding: const EdgeInsets.all(0),
        child: _buildFAB(colorScheme),
      ),
    );
  }

  Future<void> _handleRecurringCommand(
    RecurringPageCommand command,
    String? householdId,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return;
    }

    final notifier =
        ref.read(recurringTransactionsProvider(householdId).notifier);
    var state = ref.read(recurringTransactionsProvider(householdId));
    if (!state.hasLoadedOnce || state.data.isLoading) {
      await notifier.loadRecurringTransactions(user.id, forceRefresh: true);
      state = ref.read(recurringTransactionsProvider(householdId));
    }

    final transactions =
        state.data.valueOrNull ?? const <RecurringTransaction>[];
    RecurringTransaction? transaction;
    for (final entry in transactions) {
      if (entry.id == command.recurringId) {
        transaction = entry;
        break;
      }
    }

    if (!mounted) {
      return;
    }

    if (transaction == null) {
      AppToast.info(context, context.l10n.errorLoadingData);
    } else {
      _showTransactionDetails(transaction);
    }
    ref.read(recurringPageCommandProvider.notifier).state = null;
  }

  Widget _buildRecurringTabView(
    ColorScheme colorScheme,
    Widget sliver,
    String? householdId,
    bool isLoading,
  ) {
    return RefreshIndicator(
      onRefresh: () => _refresh(householdId),
      child: Skeletonizer(
        enabled: isLoading,
        effect: ShimmerEffect(
          baseColor: colorScheme.skeletonBase,
          highlightColor: colorScheme.skeletonHighlight,
        ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
            sliver,
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesSliver(
    AsyncValue<List<dynamic>> recurringExpenses,
    ColorScheme colorScheme,
    String? selectedCurrency,
    String? householdId,
    DateTime userNow,
  ) {
    return recurringExpenses.when(
      data: (expenses) {
        final filtered = (selectedCurrency == null
                ? expenses
                : expenses
                    .where((e) =>
                        (e as RecurringTransaction).currency.toUpperCase() ==
                        selectedCurrency)
                    .toList())
            .cast<RecurringTransaction>();

        return _buildTransactionsListSliver(
          filtered,
          colorScheme,
          'expense',
          householdId,
          isLoading: false,
        );
      },
      loading: () {
        final currency = selectedCurrency ?? 'USD';
        final fakeExpenses = _buildFakeRecurringTransactions(
          isIncome: false,
          currency: currency,
          now: userNow,
        );

        return _buildTransactionsListSliver(
          fakeExpenses,
          colorScheme,
          'expense',
          householdId,
          isLoading: true,
        );
      },
      error: (error, _) =>
          _buildErrorSliver(error.toString(), context.l10n.expense),
    );
  }

  Widget _buildIncomesSliver(
    AsyncValue<List<dynamic>> recurringIncomes,
    ColorScheme colorScheme,
    String? selectedCurrency,
    String? householdId,
    DateTime userNow,
  ) {
    return recurringIncomes.when(
      data: (incomes) {
        final filtered = (selectedCurrency == null
                ? incomes
                : incomes
                    .where((e) =>
                        (e as RecurringTransaction).currency.toUpperCase() ==
                        selectedCurrency)
                    .toList())
            .cast<RecurringTransaction>();

        return _buildTransactionsListSliver(
          filtered,
          colorScheme,
          'income',
          householdId,
          isLoading: false,
        );
      },
      loading: () {
        final currency = selectedCurrency ?? 'USD';
        final fakeIncomes = _buildFakeRecurringTransactions(
          isIncome: true,
          currency: currency,
          now: userNow,
        );

        return _buildTransactionsListSliver(
          fakeIncomes,
          colorScheme,
          'income',
          householdId,
          isLoading: true,
        );
      },
      error: (error, _) =>
          _buildErrorSliver(error.toString(), context.l10n.income),
    );
  }

  Widget _buildTransactionsListSliver(
    List<RecurringTransaction> transactions,
    ColorScheme colorScheme,
    String type,
    String? householdId, {
    required bool isLoading,
  }) {
    if (!isLoading && transactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: EmptyRecurringState(
              type: type,
              onAddPressed: () => _showAddSheet(type),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final transaction = transactions[index];
            return RecurringTransactionCard(
              transaction: transaction,
              onTap:
                  isLoading ? null : () => _showTransactionDetails(transaction),
              onDelete: isLoading
                  ? null
                  : () => _deleteTransaction(transaction, householdId),
            );
          },
          childCount: transactions.length,
        ),
      ),
    );
  }

  Widget _buildErrorSliver(String error, String type) {
    final colorScheme = Theme.of(context).colorScheme;

    final householdScope = ref.watch(householdScopeProvider);
    final String? householdId = switch (householdScope.activeAccountType) {
      ActiveAccountType.personal => null,
      ActiveAccountType.portfolio => householdScope.activeAccountHouseholdId,
      ActiveAccountType.household => householdScope.selectedHouseholdId,
    };

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.mutedForeground,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.errorLoadingData,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              AdaptiveButton(
                onPressed: () => _refresh(householdId),
                label: context.l10n.retry,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(ColorScheme colorScheme) {
    final selectedTab = ref.watch(selectedRecurringTabProvider);
    final isExpense = selectedTab == 0;

    return AdaptiveFloatingActionButton(
      onPressed: () => _showAddSheet(isExpense ? 'expense' : 'income'),
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.primaryForeground,
      child: const Icon(Icons.add),
    );
  }

  List<RecurringTransaction> _buildFakeRecurringTransactions({
    required bool isIncome,
    required String currency,
    required DateTime now,
  }) {
    return [
      RecurringTransaction(
        id: isIncome ? 'fake-income-1' : 'fake-expense-1',
        date: now,
        category: isIncome ? 'Salary' : 'Rent',
        description: isIncome ? 'Monthly salary' : 'Monthly rent',
        source: isIncome ? 'Company' : null,
        amount: isIncome ? 2500 : 1200,
        currency: currency,
        ownerType: 'me',
        privacyScope: 'full',
        householdId: null,
        payerUserId: null,
        recurrenceRule: null,
        type: isIncome ? 'income' : 'expense',
        attachments: const [],
        createdAt: now,
        updatedAt: null,
      ),
      RecurringTransaction(
        id: isIncome ? 'fake-income-2' : 'fake-expense-2',
        date: now,
        category: isIncome ? 'Bonus' : 'Utilities',
        description: isIncome ? 'Bonus' : 'Utilities',
        source: isIncome ? 'Company' : null,
        amount: isIncome ? 400 : 150,
        currency: currency,
        ownerType: 'me',
        privacyScope: 'full',
        householdId: null,
        payerUserId: null,
        recurrenceRule: null,
        type: isIncome ? 'income' : 'expense',
        attachments: const [],
        createdAt: now,
        updatedAt: null,
      ),
    ];
  }

  void _showAddSheet(String type) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddRecurringSheet(type: type),
      ),
    );
  }

  void _showTransactionDetails(RecurringTransaction transaction) {
    final colorScheme = Theme.of(context).colorScheme;
    // Show the add sheet with prefilled data for editing
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddRecurringSheet(
          type: transaction.type,
          existingTransaction: transaction,
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(
      RecurringTransaction transaction, String? householdId) async {
    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _debugPrint('🗑️ [RecurringPage] Delete tapped');
    _debugPrint(
        '   txId=${transaction.id} type=${transaction.type} txHouseholdId=${transaction.householdId} scopeHouseholdId=$householdId');

    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.deleteRecurringTransaction,
      description: context.l10n.deleteRecurringChoiceDescription,
      confirmLabel: context.l10n.deleteEntireSeries,
      secondaryLabel: context.l10n.skipNextOccurrence,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
      barrierDismissible: true,
    );

    if (result == null || result.action == MonekoAlertDialogAction.cancel) {
      _debugPrint('⏭️  [RecurringPage] Delete cancelled');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    final user = ref.read(authProvider);
    if (user.uid.isEmpty) {
      _debugPrint('⚠️  [RecurringPage] Delete aborted: user is empty');
      if (mounted) {
        final l10n = context.l10n;
        AppToast.error(context, l10n.userNotAuthenticated);
      }
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final toastContext = rootNavigator.context;
    final l10n = context.l10n;
    var dialogOpen = false;
    void closeDialog() {
      if (!dialogOpen) return;
      if (rootNavigator.canPop()) rootNavigator.pop();
      dialogOpen = false;
    }

    final isSkipOccurrence = result.action == MonekoAlertDialogAction.secondary;

    // Show loading dialog
    showBlockingProcessingDialog(
      context: toastContext,
      message: isSkipOccurrence
          ? '${l10n.skipNextOccurrence}...'
          : '${l10n.delete}...',
    );
    dialogOpen = true;

    try {
      final notifier =
          ref.read(recurringTransactionsProvider(householdId).notifier);

      DeleteRecurringResult operationResult;

      if (isSkipOccurrence) {
        // Compute the next occurrence date to skip
        final preferredTimezone =
            ref.read(analyticsProvider).contact?.preferredTimezone;
        final userNow = effectiveNow(preferredTimezone: preferredTimezone);
        final nextDate = transaction.getNextOccurrence(userNow);
        operationResult = await notifier.skipOccurrence(
          user.uid,
          transaction.id,
          nextDate,
        );
      } else {
        // Delete entire series
        operationResult =
            await notifier.deleteRecurring(user.uid, transaction.id);
      }

      if (!mounted) return;

      closeDialog();

      if (operationResult.success) {
        AppToast.success(
          toastContext,
          isSkipOccurrence
              ? l10n.occurrenceSkipped
              : l10n.recurringTransactionDeleted,
        );
      } else {
        final message = (operationResult.error != null &&
                operationResult.error!.trim().isNotEmpty)
            ? operationResult.error!
            : l10n.failedToDeleteRecurringTransaction;
        AppToast.error(toastContext, message);
      }
    } catch (e) {
      closeDialog();
      if (!mounted) return;

      AppToast.error(
        toastContext,
        ErrorHandler.getUserFriendlyMessage(e),
      );
    } finally {
      closeDialog();
    }

    _debugPrint('✅ [RecurringPage] Delete operation completed');
    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
