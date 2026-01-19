import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';

class BudgetDashboardDemoScreen extends StatefulWidget {
  const BudgetDashboardDemoScreen({super.key});

  @override
  State<BudgetDashboardDemoScreen> createState() =>
      _BudgetDashboardDemoScreenState();
}

class _BudgetDashboardDemoScreenState extends State<BudgetDashboardDemoScreen> {
  // Global keys for spotlight targets
  final GlobalKey totalBalanceKey = GlobalKey();
  final GlobalKey spendingChartKey = GlobalKey();
  final GlobalKey addTransactionKey = GlobalKey();

  late final SpotlightTourController _tourController;

  @override
  void initState() {
    super.initState();

    final steps = [
      SpotlightStep(
        id: 'total_balance',
        targetKey: totalBalanceKey,
        title: 'Your total balance',
        description:
            'This shows how much money you currently have across all accounts.',
        placement: SpotlightPlacement.bottom,
      ),
      SpotlightStep(
        id: 'spending_chart',
        targetKey: spendingChartKey,
        title: 'Track your spending',
        description: 'Visualize where your money goes each month.',
        placement: SpotlightPlacement
            .top, // Chart is usually lower, so tooltip goes top
      ),
      SpotlightStep(
        id: 'add_transaction',
        targetKey: addTransactionKey,
        title: 'Add new transactions',
        description:
            'Tap here whenever you want to record a new expense or income.',
        placement:
            SpotlightPlacement.top, // FAB is at bottom, so tooltip goes top
      ),
    ];

    _tourController = SpotlightTourController(
      tourId: 'budget_dashboard_demo_v1',
      steps: steps,
      // You can also add listener here if needed
    );

    // Auto-start the tour
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tourController.start(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _tourController.forceStart(context),
            tooltip: 'Restart Tour',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Balance Card
            Container(
              key: totalBalanceKey,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      color:
                          colorScheme.primaryForeground.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$12,450.00',
                    style: TextStyle(
                        color: colorScheme.primaryForeground,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Monthly Spending Chart
            Text('Monthly Spending',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              key: spendingChartKey,
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.homeCardSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colorScheme.homeCardBorder),
              ),
              // Mock chart UI
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: 50.0 + (index * 20) % 100, // Randomish heights
                        decoration: BoxDecoration(
                          color: index == 6
                              ? colorScheme.primary
                              : colorScheme.muted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 32),

            // Transactions List
            Text('Recent Transactions',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.homeCardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.homeCardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shopping_bag,
                          color: colorScheme.warning,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Grocery Store',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Today',
                              style: TextStyle(
                                  color: colorScheme.mutedForeground,
                                  fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      const Text('-\$45.00',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: addTransactionKey,
        onPressed: () {},
        label: const Text('Add Transaction'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
