import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import '../providers/goals_providers.dart';
import '../widgets/goal_card.dart';
import '../widgets/create_goal_sheet.dart';
import '../../../../core/l10n/l10n.dart';

class GoalsListPage extends ConsumerStatefulWidget {
  const GoalsListPage({super.key});

  @override
  ConsumerState<GoalsListPage> createState() => _GoalsListPageState();
}

class _GoalsListPageState extends ConsumerState<GoalsListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // String? _householdId;
  // String? _userId;

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
    final l10n = context.l10n;
    final goalsState = ref.watch(goalsListProvider);
    final summaryState = ref.watch(goalSummaryProvider);

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(l10n.goals),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filter sheet
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.all),
            Tab(text: l10n.savings),
            Tab(text: l10n.paydown),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary card
          summaryState.when(
            data: (summary) => _buildSummaryCard(summary),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Goals list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGoalsList(goalsState, null),
                _buildGoalsList(goalsState, 'savings'),
                _buildGoalsList(goalsState, 'paydown'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showCreateGoalSheet(context);
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.createGoal),
      ),
    ),
        // In Development Overlay
        // Positioned.fill(
        //   child: BackdropFilter(
        //     filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        //     child: Container(
        //       color: Colors.black.withValues(alpha: 0.3),
        //       child: Center(
        //         child: Container(
        //           margin: const EdgeInsets.all(32),
        //           padding: const EdgeInsets.all(24),
        //           decoration: BoxDecoration(
        //             color: Colors.white,
        //             borderRadius: BorderRadius.circular(16),
        //             boxShadow: [
        //               BoxShadow(
        //                 color: Colors.black.withValues(alpha: 0.2),
        //                 blurRadius: 20,
        //                 offset: const Offset(0, 10),
        //               ),
        //             ],
        //           ),
        //           child: const Column(
        //             mainAxisSize: MainAxisSize.min,
        //             children: [
        //               Icon(
        //                 Icons.construction,
        //                 size: 64,
        //                 color: Colors.orange,
        //               ),
        //               SizedBox(height: 16),
        //               Text(
        //                 'In Development',
        //                 style: TextStyle(
        //                   fontSize: 24,
        //                   fontWeight: FontWeight.bold,
        //                   color: Colors.black87,
        //                 ),
        //               ),
        //               SizedBox(height: 12),
        //               Text(
        //                 'Goals feature is currently under construction.\nStay tuned for updates!',
        //                 textAlign: TextAlign.center,
        //                 style: TextStyle(
        //                   fontSize: 14,
        //                   color: Colors.black54,
        //                 ),
        //               ),
        //             ],
        //           ),
        //         ),
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildSummaryCard(dynamic summary) {
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  l10n.totalGoals,
                  summary.totalGoals.toString(),
                  Icons.flag,
                ),
                _buildSummaryItem(
                  l10n.active,
                  summary.activeGoals.toString(),
                  Icons.play_circle,
                ),
                _buildSummaryItem(
                  l10n.completed,
                  summary.completedGoals.toString(),
                  Icons.check_circle,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: summary.overallProgress / 100,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.overallProgress.toStringAsFixed(1)}% ${l10n.overallProgress}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildGoalsList(AsyncValue<List<dynamic>> goalsState, String? category) {
    return goalsState.when(
      data: (goals) {
        final filteredGoals = category != null
            ? goals.where((g) => g.category == category).toList()
            : goals;

        if (filteredGoals.isEmpty) {
          return _buildEmptyState(category);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredGoals.length,
          itemBuilder: (context, index) {
            final goal = filteredGoals[index];
            return GoalCard(
              goal: goal,
              onTap: () {
                // TODO: Navigate to goal detail page
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  Widget _buildEmptyState(String? category) {
    final l10n = context.l10n;

    String message;
    if (category == 'savings') {
      message = l10n.noSavingsGoals;
    } else if (category == 'paydown') {
      message = l10n.noPaydownGoals;
    } else {
      message = l10n.noGoals;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.flag, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showCreateGoalSheet(context);
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.createGoal),
          ),
        ],
      ),
    );
  }
}
