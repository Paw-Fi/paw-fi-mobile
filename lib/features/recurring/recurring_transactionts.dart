import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';

/// Modern recurring transactions page with Apple-inspired design
/// Features tabbed interface for expenses and income
class RecurringTransactionsPage extends ConsumerStatefulWidget {
  const RecurringTransactionsPage({super.key});

  @override
  ConsumerState<RecurringTransactionsPage> createState() =>
      _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState
    extends ConsumerState<RecurringTransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Load initial data (only if not already loaded)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _handleTabChange() {
    ref.read(selectedRecurringTabProvider.notifier).state =
        _tabController.index;
  }

  /// Load data only if it hasn't been loaded before (respects caching)
  Future<void> _loadData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final expensesState = ref.read(recurringExpensesProvider);
    final incomesState = ref.read(recurringIncomesProvider);

    // Only load if we've NEVER loaded successfully before
    // This prevents unnecessary reloads when navigating back to this page
    if (!expensesState.hasLoadedOnce) {
      await ref
          .read(recurringExpensesProvider.notifier)
          .loadRecurringExpenses(user.id);
    }

    if (!incomesState.hasLoadedOnce) {
      await ref
          .read(recurringIncomesProvider.notifier)
          .loadRecurringIncomes(user.id);
    }
  }

  /// Force refresh (used by pull-to-refresh)
  Future<void> _refresh() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Force refresh both lists
    await Future.wait([
      ref.read(recurringExpensesProvider.notifier).refresh(user.id),
      ref.read(recurringIncomesProvider.notifier).refresh(user.id),
    ]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    // Watch the state objects (not just the data)
    final recurringExpensesState = ref.watch(recurringExpensesProvider);
    final recurringIncomesState = ref.watch(recurringIncomesProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [                
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recurring',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'Manage your recurring transactions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.muted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: colorScheme.background,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: colorScheme.foreground,
                unselectedLabelColor: colorScheme.mutedForeground,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                labelPadding: EdgeInsets.zero,
                tabs: const [
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                   
                          Text('Expenses'),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
           
                          Text('Income'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Expenses tab - pass the AsyncValue data
                  _buildExpensesTab(recurringExpensesState.data, colorScheme),

                  // Income tab - pass the AsyncValue data
                  _buildIncomesTab(recurringIncomesState.data, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),

      // Floating action button
      floatingActionButton: _buildFAB(colorScheme),
    );
  }

  Widget _buildExpensesTab(
    AsyncValue<List<dynamic>> recurringExpenses,
    shadcnui.ColorScheme colorScheme,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: recurringExpenses.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return EmptyRecurringState(
              type: 'expense',
              onAddPressed: () => _showAddSheet('expense'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return RecurringTransactionCard(
                transaction: expense,
                onTap: () => _showTransactionDetails(expense),
                onDelete: () => _deleteTransaction(expense),
              );
            },
          );
        },
        loading: () => _buildLoadingState(),
        error: (error, _) => _buildErrorState(error.toString(), 'expense'),
      ),
    );
  }

  Widget _buildIncomesTab(
    AsyncValue<List<dynamic>> recurringIncomes,
    shadcnui.ColorScheme colorScheme,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: recurringIncomes.when(
        data: (incomes) {
          if (incomes.isEmpty) {
            return EmptyRecurringState(
              type: 'income',
              onAddPressed: () => _showAddSheet('income'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: incomes.length,
            itemBuilder: (context, index) {
              final income = incomes[index];
              return RecurringTransactionCard(
                transaction: income,
                onTap: () => _showTransactionDetails(income),
                onDelete: () => _deleteTransaction(income),
              );
            },
          );
        },
        loading: () => _buildLoadingState(),
        error: (error, _) => _buildErrorState(error.toString(), 'income'),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String error, String type) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Center(
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
              'Error Loading Data',
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
            shadcnui.PrimaryButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(shadcnui.ColorScheme colorScheme) {
    final selectedTab = ref.watch(selectedRecurringTabProvider);
    final isExpense = selectedTab == 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddSheet(isExpense ? 'expense' : 'income'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add ${isExpense ? 'Expense' : 'Income'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
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

  void _showTransactionDetails(dynamic transaction) {
    // TODO: Implement transaction details view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction details coming soon')),
    );
  }

  Future<void> _deleteTransaction(dynamic transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Transaction'),
        content: const Text(
            'Are you sure you want to delete this recurring transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final isExpense = transaction.type == 'expense';
      final success = isExpense
          ? await ref
              .read(recurringExpensesProvider.notifier)
              .deleteRecurring(user.id, transaction.id)
          : await ref
              .read(recurringIncomesProvider.notifier)
              .deleteRecurring(user.id, transaction.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Recurring transaction deleted'
                  : 'Failed to delete recurring transaction',
            ),
            backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
          ),
        );
      }
    }
  }
}
