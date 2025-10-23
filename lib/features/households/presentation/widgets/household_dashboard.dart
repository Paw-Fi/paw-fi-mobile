import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../pages/household_invites_page.dart';
import '../pages/household_members_page.dart';
import '../pages/household_settings_page.dart';
import '../pages/create_budget_page.dart';
import '../pages/budget_detail_page.dart';
import '../pages/household_expenses_page.dart';
import '../../../home/presentation/models/expense_entry.dart';
import '../../../home/presentation/widgets/unified_transaction_sheet.dart';
import '../../../../shared/widgets/user_avatar.dart';

/// Main household dashboard showing budgets, expenses, and splits
class HouseholdDashboard extends ConsumerWidget {
  final Household household;

  const HouseholdDashboard({
    super.key,
    required this.household,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Household Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.primary.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Household cover image and name
                 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          household.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Shared Household',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Settings button
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: colorScheme.foreground,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HouseholdSettingsPage(
                            householdId: household.id,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.people_outline,
                      label: 'Members',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HouseholdMembersPage(
                              householdId: household.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.link,
                      label: 'Invite',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HouseholdInvitesPage(
                              householdId: household.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Budgets Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Shared Budgets',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildBudgetsSection(ref, colorScheme),

        const SizedBox(height: 24),

        // Recent Activity Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildRecentActivity(ref, colorScheme),

        const SizedBox(height: 24),

        // Expense Splits Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pending Splits',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
        ),
        const SizedBox(height: 12),

        _buildSplitsSection(ref, colorScheme),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBudgetsSection(WidgetRef ref, shadcnui.ColorScheme colorScheme) {
    final budgetsAsync = ref.watch(householdBudgetsProvider(household.id));

    return budgetsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error loading budgets',
          style: TextStyle(color: colorScheme.destructive),
          textAlign: TextAlign.center,
        ),
      ),
      data: (budgets) {
        if (budgets.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Builder(
              builder: (context) => Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: colorScheme.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No shared budgets yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  shadcnui.TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateBudgetPage(
                            householdId: household.id,
                          ),
                        ),
                      );
                    },
                    child: const Text('Create Budget'),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              return _BudgetCard(budget: budget);
            },
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity(WidgetRef ref, shadcnui.ColorScheme colorScheme) {
    final expensesParams = HouseholdExpensesParams(householdId: household.id);
    final expensesAsync = ref.watch(householdExpensesProvider(expensesParams));

    return expensesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error loading activity',
          style: TextStyle(color: colorScheme.destructive),
          textAlign: TextAlign.center,
        ),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: colorScheme.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: expenses.length > 5 ? 5 : expenses.length, // Show max 5 recent
              itemBuilder: (context, index) {
                final expense = expenses[index];
                debugPrint('🔍 Expense ${expense.id}: userName=${expense.userName}, userId=${expense.userId}');
                return _ExpenseActivityCard(expense: expense);
              },
            ),
            
            // View All Expenses link
            if (expenses.length > 5)
              Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => HouseholdExpensesPage(
                            household: household,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View All Expenses',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSplitsSection(WidgetRef ref, shadcnui.ColorScheme colorScheme) {
    final splitsParams = HouseholdSplitsParams(householdId: household.id);
    final splitsAsync = ref.watch(householdSplitsProvider(splitsParams));

    return splitsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error loading splits',
          style: TextStyle(color: colorScheme.destructive),
          textAlign: TextAlign.center,
        ),
      ),
      data: (splits) {
        if (splits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.balance_outlined,
                    size: 48,
                    color: colorScheme.mutedForeground,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No pending splits',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: splits.length,
          itemBuilder: (context, index) {
            return _SplitCard(splitGroup: splits[index]);
          },
        );
      },
    );
  }
}

/// Quick action button widget
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.muted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: colorScheme.foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Budget card widget
class _BudgetCard extends ConsumerWidget {
  final dynamic budget;

  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        // Navigate to budget detail page
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BudgetDetailPage(
              budget: budget,
              householdId: budget.householdId,
            ),
          ),
        );
        
        // If budget was modified, refresh the budgets list
        if (result == true) {
          ref.invalidate(householdBudgetsProvider);
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              budget.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '\$${(budget.amountCents / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Text(
                  budget.period.toJson().toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: colorScheme.mutedForeground,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Split card widget
class _SplitCard extends StatelessWidget {
  final dynamic splitGroup;

  const _SplitCard({required this.splitGroup});

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.balance,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expense Split',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pending settlement',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }
}

/// Expense activity card widget
class _ExpenseActivityCard extends StatelessWidget {
  final ExpenseEntry expense;

  const _ExpenseActivityCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () {
        // Open unified transaction sheet for viewing/editing expense
        showUnifiedTransactionSheet(
          context,
          existingExpense: expense,
        );
      },
      child: _buildCard(context, colorScheme),
    );
  }

  Widget _buildCard(BuildContext context, shadcnui.ColorScheme colorScheme) {

    // Format date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(expense.date.year, expense.date.month, expense.date.day);

    String dateText;
    if (expenseDate == today) {
      dateText = 'Today';
    } else if (expenseDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = '${expense.date.month}/${expense.date.day}/${expense.date.year}';
    }

    // Get category icon
    IconData categoryIcon = Icons.shopping_bag;
    if (expense.category != null) {
      switch (expense.category!.toLowerCase()) {
        case 'food':
        case 'groceries':
          categoryIcon = Icons.restaurant;
          break;
        case 'transport':
        case 'transportation':
          categoryIcon = Icons.directions_car;
          break;
        case 'entertainment':
          categoryIcon = Icons.movie;
          break;
        case 'utilities':
          categoryIcon = Icons.lightbulb;
          break;
        case 'health':
          categoryIcon = Icons.local_hospital;
          break;
        default:
          categoryIcon = Icons.shopping_bag;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              categoryIcon,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category ?? 'Expense',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Show who added it with avatar
                    if (expense.userName != null) ...[
                      UserAvatar(
                        avatarUrl: expense.userAvatarUrl,
                        name: expense.userName,
                        size: 'tiny',
                      ),
                      const SizedBox(width: 6),
                      Text(
                        expense.userName!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    if (expense.splitGroupId != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SPLIT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.secondaryForeground,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${(expense.amountCents / 100).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
