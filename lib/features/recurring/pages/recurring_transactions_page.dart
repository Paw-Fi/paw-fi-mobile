import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/widgets/currency_dropdown_button.dart';

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
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    // Watch the filtered providers (they derive from the unified provider)
    final recurringExpenses = ref.watch(recurringExpensesProvider);
    final recurringIncomes = ref.watch(recurringIncomesProvider);
    final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency?.toUpperCase();

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
                          context.l10n.recurring,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          context.l10n.manageYourRecurringTransactions,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const CurrencyDropdownButton(),
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
                      color: Colors.black.withValues(alpha: 0.05),
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
                tabs: [
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                   
                          Text(context.l10n.expenses),
                        ],
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
           
                          Text(context.l10n.income),
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
                  _buildExpensesTab(recurringExpenses, colorScheme, selectedCurrency),

                  // Income tab - pass the AsyncValue data
                  _buildIncomesTab(recurringIncomes, colorScheme, selectedCurrency),
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
    String? selectedCurrency,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: recurringExpenses.when(
        data: (expenses) {
          final filtered = selectedCurrency == null
              ? expenses
              : expenses.where((e) => (e as RecurringTransaction).currency.toUpperCase() == selectedCurrency).toList();
          if (filtered.isEmpty) {
            // Wrap in ListView to make it scrollable for RefreshIndicator
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: EmptyRecurringState(
                    type: 'expense',
                    onAddPressed: () => _showAddSheet('expense'),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final expense = filtered[index] as RecurringTransaction;
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
    String? selectedCurrency,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: recurringIncomes.when(
        data: (incomes) {
          final filtered = selectedCurrency == null
              ? incomes
              : incomes.where((e) => (e as RecurringTransaction).currency.toUpperCase() == selectedCurrency).toList();
          if (filtered.isEmpty) {
            // Wrap in ListView to make it scrollable for RefreshIndicator
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: EmptyRecurringState(
                    type: 'income',
                    onAddPressed: () => _showAddSheet('income'),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final income = filtered[index] as RecurringTransaction;
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error, String type) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    // Wrap in ListView to make it scrollable for RefreshIndicator
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
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
                  shadcnui.PrimaryButton(
                    onPressed: _refresh,
                    child: Text(context.l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
            colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.4),
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 24,
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
            child: Text(context.l10n.delete, style: const TextStyle(color: Colors.red)),
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
