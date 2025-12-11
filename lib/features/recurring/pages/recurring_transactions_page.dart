import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

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
  
  /// Force refresh (used by pull-to-refresh)
  Future<void> _refresh(String? householdId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    // Force refresh the unified list for current scope
    await ref.read(recurringTransactionsProvider(householdId).notifier).refresh(user.id);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = supabase.auth.currentUser;
    
    // Determine current scope
    final viewMode = ref.watch(viewModeProvider);
    
    // Resolve household ID correctly - same logic as household_home_content.dart
    String? householdId;
    if (viewMode.mode == ViewMode.household) {
      final selectedHousehold = ref.watch(selectedHouseholdProvider);
      final householdsAsync = user != null 
          ? ref.watch(userHouseholdsProvider(user.id))
          : const AsyncValue<List<Household>>.data([]);
      
      final households = householdsAsync.valueOrNull ?? [];
      
      if (households.isNotEmpty) {
        // Use selected household if available, otherwise fall back to first
        final household = selectedHousehold.household ?? households.first;
        householdId = household.id;
        
        debugPrint('🏠 [RecurringPage] Resolved household: ${household.name} (${household.id})');
      } else {
        debugPrint('⚠️ [RecurringPage] No households available in household mode');
      }
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🏠 [RecurringPage] BUILD');
    debugPrint('   ViewMode: ${viewMode.mode}');
    debugPrint('   HouseholdId: $householdId');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Ensure data is loaded for this scope
    final state = ref.watch(recurringTransactionsProvider(householdId));
    
    debugPrint('📊 [RecurringPage] Provider State:');
    debugPrint('   HasLoadedOnce: ${state.hasLoadedOnce}');
    debugPrint('   IsLoading: ${state.data.isLoading}');
    debugPrint('   HasValue: ${state.data.hasValue}');
    debugPrint('   HasError: ${state.data.hasError}');
    if (state.data.hasValue) {
      debugPrint('   Data count: ${state.data.value?.length ?? 0}');
    }
    
    if (user != null && !state.hasLoadedOnce && !state.data.isLoading) {
      debugPrint('🚀 [RecurringPage] Triggering initial load...');
      Future.microtask(() {
        ref.read(recurringTransactionsProvider(householdId).notifier)
            .loadRecurringTransactions(user.id);
      });
    } else {
      debugPrint('⏭️  [RecurringPage] Not triggering load (hasLoadedOnce=${state.hasLoadedOnce}, isLoading=${state.data.isLoading})');
    }

    // Watch the filtered providers (they derive from the unified provider)
    final recurringExpenses = ref.watch(recurringExpensesProvider(householdId));
    final recurringIncomes = ref.watch(recurringIncomesProvider(householdId));
    final selectedCurrency =
        ref.watch(homeFilterProvider).selectedCurrency?.toUpperCase();
        
    return AdaptiveScaffold(
      body: AdaptiveTabBarView(
        tabs: [
          context.l10n.expenses,
          context.l10n.income,
        ],
        children: [
          _buildRecurringTabView(
            colorScheme,
            _buildExpensesSliver(
              recurringExpenses,
              colorScheme,
              selectedCurrency,
              householdId,
            ),
            householdId,
          ),
          _buildRecurringTabView(
            colorScheme,
            _buildIncomesSliver(
              recurringIncomes,
              colorScheme,
              selectedCurrency,
              householdId,
            ),
            householdId,
          ),
        ],
        onTabChanged: (index) {
          ref.read(selectedRecurringTabProvider.notifier).state = index;
        },
      ),

      // Floating action button
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(0),
        child: _buildFAB(colorScheme),
      ),
    );
  }

  Widget _buildRecurringTabView(
    ColorScheme colorScheme,
    Widget sliver,
    String? householdId,
  ) {
    return RefreshIndicator(
      onRefresh: () => _refresh(householdId),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header is now provided globally in MainShell; add spacing only
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
          sliver,
        ],
      ),
    );
  }

  Widget _buildExpensesSliver(
    AsyncValue<List<dynamic>> recurringExpenses,
    ColorScheme colorScheme,
    String? selectedCurrency,
    String? householdId,
  ) {
    return recurringExpenses.when(
      data: (expenses) {
        final filtered = selectedCurrency == null
            ? expenses
            : expenses
                .where((e) =>
                    (e as RecurringTransaction).currency.toUpperCase() ==
                    selectedCurrency)
                .toList();
        if (filtered.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: EmptyRecurringState(
                  type: context.l10n.expense,
                  onAddPressed: () => _showAddSheet(context.l10n.expense),
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
                final expense = filtered[index] as RecurringTransaction;
                return RecurringTransactionCard(
                  transaction: expense,
                  onTap: () => _showTransactionDetails(expense),
                  onDelete: () => _deleteTransaction(expense, householdId),
                );
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => _buildLoadingSliver(),
      error: (error, _) => _buildErrorSliver(error.toString(), context.l10n.expense),
    );
  }

  Widget _buildIncomesSliver(
    AsyncValue<List<dynamic>> recurringIncomes,
    ColorScheme colorScheme,
    String? selectedCurrency,
    String? householdId,
  ) {
    return recurringIncomes.when(
      data: (incomes) {
        final filtered = selectedCurrency == null
            ? incomes
            : incomes
                .where((e) =>
                    (e as RecurringTransaction).currency.toUpperCase() ==
                    selectedCurrency)
                .toList();
        if (filtered.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: EmptyRecurringState(
                  type: context.l10n.income,
                  onAddPressed: () => _showAddSheet(context.l10n.income),
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
                final income = filtered[index] as RecurringTransaction;
                return RecurringTransactionCard(
                  transaction: income,
                  onTap: () => _showTransactionDetails(income),
                  onDelete: () => _deleteTransaction(income, householdId),
                );
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => _buildLoadingSliver(),
      error: (error, _) => _buildErrorSliver(error.toString(), context.l10n.income),
    );
  }

  Widget _buildLoadingSliver() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorSliver(String error, String type) {
    final colorScheme = Theme.of(context).colorScheme;

    // Get householdId for retry logic
    final user = supabase.auth.currentUser;
    final viewMode = ref.watch(viewModeProvider);
    
    String? householdId;
    if (viewMode.mode == ViewMode.household && user != null) {
      final selectedHousehold = ref.watch(selectedHouseholdProvider);
      final householdsAsync = ref.watch(userHouseholdsProvider(user.id));
      final households = householdsAsync.valueOrNull ?? [];
      if (households.isNotEmpty) {
        final household = selectedHousehold.household ?? households.first;
        householdId = household.id;
      }
    }

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
      onPressed: () => _showAddSheet(isExpense ? context.l10n.expense : context.l10n.income),
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.primaryForeground,
      child: const Icon(Icons.add),
    );
  }

  void _showAddSheet(String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddRecurringSheet(type: type),
      ),
    );
  }

  void _showTransactionDetails(RecurringTransaction transaction) {
    // Show the add sheet with prefilled data for editing
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.deleteRecurringTransaction,
      description:
          context.l10n.areYouSureYouWantToDeleteThisRecurringTransaction,
      confirmLabel: context.l10n.delete,
      cancelLabel: context.l10n.cancel,
      barrierDismissible: true,
    );

    if (result == null || !result.confirmed) {
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final success = await ref
        .read(recurringTransactionsProvider(householdId).notifier)
        .deleteRecurring(user.id, transaction.id);

    if (!mounted) return;

    if (success) {
      AppToast.success(context, context.l10n.recurringTransactionDeleted);
    } else {
      AppToast.error(
          context, context.l10n.failedToDeleteRecurringTransaction);
    }
  }
}