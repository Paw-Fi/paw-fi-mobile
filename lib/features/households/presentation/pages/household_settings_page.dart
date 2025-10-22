import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../domain/entities/shared_budget.dart';
import '../providers/household_providers.dart';

/// Household Settings Page
/// Manage budgets, privacy preferences, and household settings
class HouseholdSettingsPage extends ConsumerStatefulWidget {
  final String householdId;

  const HouseholdSettingsPage({
    super.key,
    required this.householdId,
  });

  @override
  ConsumerState<HouseholdSettingsPage> createState() =>
      _HouseholdSettingsPageState();
}

class _HouseholdSettingsPageState extends ConsumerState<HouseholdSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          'Household Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.mutedForeground,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Budgets'),
            Tab(text: 'Privacy'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BudgetsTab(householdId: widget.householdId),
          _PrivacyTab(householdId: widget.householdId),
          _NotificationsTab(householdId: widget.householdId),
        ],
      ),
    );
  }
}

/// Budgets Tab
class _BudgetsTab extends ConsumerWidget {
  final String householdId;

  const _BudgetsTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(householdBudgetsProvider(householdId));
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return budgetsAsync.when(
      data: (budgets) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Add Budget Button
          shadcnui.PrimaryButton(
            onPressed: () => _showCreateBudgetDialog(context, ref),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add),
                SizedBox(width: 8),
                Text('Create Budget'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Budgets List
          if (budgets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No budgets yet. Create one to start tracking!',
                  style: TextStyle(color: colorScheme.mutedForeground),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...budgets.map((budget) => _BudgetCard(
                  budget: budget,
                  householdId: householdId,
                )),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: TextStyle(color: colorScheme.destructive)),
      ),
    );
  }

  void _showCreateBudgetDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    BudgetPeriod selectedPeriod = BudgetPeriod.monthly;
    double warnThreshold = 0.8;
    double alertThreshold = 1.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Budget'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Budget Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BudgetPeriod>(
                value: selectedPeriod,
                decoration: const InputDecoration(labelText: 'Period'),
                items: BudgetPeriod.values
                    .map((period) => DropdownMenuItem(
                          value: period,
                          child: Text(period.toJson()),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) selectedPeriod = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (nameController.text.isNotEmpty && amount != null) {
                await ref.read(householdBudgetsProvider(householdId).notifier).createBudget(
                  name: nameController.text,
                  period: selectedPeriod.toJson(),
                  currency: 'USD',
                  amountCents: (amount * 100).toInt(),
                  warnThreshold: warnThreshold,
                  alertThreshold: alertThreshold,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Budget Card
class _BudgetCard extends StatelessWidget {
  final SharedBudget budget;
  final String householdId;

  const _BudgetCard({
    required this.budget,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final amount = budget.amountCents / 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budget.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              budget.period.toJson().toUpperCase(),
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  size: 16,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  'Budget Boop at ${(budget.warnThreshold * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.warning,
                  size: 16,
                  color: colorScheme.destructive,
                ),
                const SizedBox(width: 4),
                Text(
                  'Purr-suasive Nudge at ${(budget.alertThreshold * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Privacy Tab
class _PrivacyTab extends ConsumerWidget {
  final String householdId;

  const _PrivacyTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Default Privacy Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 16),
        _PrivacyOption(
          title: 'Transactions',
          description: 'Who can see your transactions by default',
          value: 'Private',
          onTap: () {},
        ),
        _PrivacyOption(
          title: 'Accounts',
          description: 'Who can see your account balances',
          value: 'Private',
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Text(
          'Category Overrides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set different privacy levels for specific categories',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        shadcnui.OutlineButton(
          onPressed: () {},
          child: const Text('Add Category Override'),
        ),
      ],
    );
  }
}

/// Privacy Option Widget
class _PrivacyOption extends StatelessWidget {
  final String title;
  final String description;
  final String value;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.title,
    required this.description,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(color: colorScheme.primary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Notifications Tab
class _NotificationsTab extends ConsumerStatefulWidget {
  final String householdId;

  const _NotificationsTab({required this.householdId});

  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  bool enableNudges = true;
  TimeOfDay quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Enable Budget Nudges'),
          subtitle: const Text('Receive notifications when approaching budget limits'),
          value: enableNudges,
          onChanged: (value) {
            setState(() {
              enableNudges = value;
            });
          },
        ),
        const Divider(),
        ListTile(
          title: const Text('Quiet Hours Start'),
          subtitle: Text('No nudges after ${quietHoursStart.format(context)}'),
          trailing: Icon(Icons.access_time, color: colorScheme.primary),
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: quietHoursStart,
            );
            if (time != null) {
              setState(() {
                quietHoursStart = time;
              });
            }
          },
        ),
        ListTile(
          title: const Text('Quiet Hours End'),
          subtitle: Text('Resume nudges at ${quietHoursEnd.format(context)}'),
          trailing: Icon(Icons.access_time, color: colorScheme.primary),
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: quietHoursEnd,
            );
            if (time != null) {
              setState(() {
                quietHoursEnd = time;
              });
            }
          },
        ),
        const SizedBox(height: 24),
        shadcnui.PrimaryButton(
          onPressed: () {
            // Save preferences
          },
          child: const Text('Save Preferences'),
        ),
      ],
    );
  }
}
