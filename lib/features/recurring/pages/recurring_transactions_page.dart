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
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

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
  @override
  void initState() {
    super.initState();
    // Load initial data (only if not already loaded)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// Load data only if it hasn't been loaded before (respects caching)
  Future<void> _loadData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final state = ref.read(recurringTransactionsProvider);

    // Only load if we've NEVER loaded successfully before
    // This prevents unnecessary reloads when navigating back to this page
    if (!state.hasLoadedOnce) {
      await ref
          .read(recurringTransactionsProvider.notifier)
          .loadRecurringTransactions(user.id);
    }
  }

  /// Force refresh (used by pull-to-refresh)
  Future<void> _refresh() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Force refresh the unified list
    await ref.read(recurringTransactionsProvider.notifier).refresh(user.id);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Watch the filtered providers (they derive from the unified provider)
    final recurringExpenses = ref.watch(recurringExpensesProvider);
    final recurringIncomes = ref.watch(recurringIncomesProvider);
    final selectedCurrency =
        ref.watch(homeFilterProvider).selectedCurrency?.toUpperCase();
    return AdaptiveScaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AdaptiveTabBarView(
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
              ),
            ),
            _buildRecurringTabView(
              colorScheme,
              _buildIncomesSliver(
                recurringIncomes,
                colorScheme,
                selectedCurrency,
              ),
            ),
          ],
          onTabChanged: (index) {
            ref.read(selectedRecurringTabProvider.notifier).state = index;
          },
        ),
      ),

      // Floating action button
      floatingActionButton: _buildFAB(colorScheme),
    );
  }

  Widget _buildRecurringTabView(
    ColorScheme colorScheme,
    Widget sliver,
  ) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Header is now provided globally in MainShell; add spacing only
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
        sliver,
      ],
    );
  }

  Widget _buildExpensesSliver(
    AsyncValue<List<dynamic>> recurringExpenses,
    ColorScheme colorScheme,
    String? selectedCurrency,
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
                  type: 'expense',
                  onAddPressed: () => _showAddSheet('expense'),
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
                  onDelete: () => _deleteTransaction(expense),
                );
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => _buildLoadingSliver(),
      error: (error, _) => _buildErrorSliver(error.toString(), 'expense'),
    );
  }

  Widget _buildIncomesSliver(
    AsyncValue<List<dynamic>> recurringIncomes,
    ColorScheme colorScheme,
    String? selectedCurrency,
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
                  type: 'income',
                  onAddPressed: () => _showAddSheet('income'),
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
                  onDelete: () => _deleteTransaction(income),
                );
              },
              childCount: filtered.length,
            ),
          ),
        );
      },
      loading: () => _buildLoadingSliver(),
      error: (error, _) => _buildErrorSliver(error.toString(), 'income'),
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
                onPressed: _refresh,
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

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddSheet(isExpense ? 'expense' : 'income'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  color: colorScheme.primaryForeground,
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _deleteTransaction(RecurringTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteRecurringTransaction),
        content: Text(
            context.l10n.areYouSureYouWantToDeleteThisRecurringTransaction),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final success = await ref
          .read(recurringTransactionsProvider.notifier)
          .deleteRecurring(user.id, transaction.id);

      if (mounted) {
        if (success) {
          AppToast.success(context.l10n.recurringTransactionDeleted);
        } else {
          AppToast.error(context.l10n.failedToDeleteRecurringTransaction);
        }
      }
    }
  }
}
