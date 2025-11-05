import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import '../../../../core/l10n/l10n.dart';
import '../providers/household_providers.dart';
import '../widgets/household_header.dart';
import '../widgets/budget_progress_card.dart';
import '../widgets/member_avatars.dart';
import '../widgets/recent_splits_list.dart';

/// Household Overview Page
/// Shows dashboard with budgets, members, and recent activity
class HouseholdOverviewPage extends ConsumerWidget {
  final String householdId;

  const HouseholdOverviewPage({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdAsync = ref.watch(householdProvider(householdId));
    final membersAsync = ref.watch(householdMembersProvider(householdId));
    final budgetsAsync = ref.watch(householdBudgetsProvider(householdId));
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: householdAsync.when(
          data: (household) => Row(
            children: [
              if (household?.coverImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    household!.coverImageUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.muted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.home,
                        color: colorScheme.mutedForeground,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  household?.name ?? context.l10n.household,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
            ],
          ),
          loading: () => Text(context.l10n.loading, style: TextStyle(color: colorScheme.mutedForeground)),
          error: (_, __) => Text(context.l10n.error, style: TextStyle(color: colorScheme.destructive)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.foreground),
            onPressed: () {
              // Navigate to household settings
              Navigator.pushNamed(context, '/households/$householdId/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh all providers
          ref.invalidate(householdProvider(householdId));
          await ref.read(householdMembersProvider(householdId).notifier).load();
          await ref.read(householdBudgetsProvider(householdId).notifier).load();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Household Header
              householdAsync.when(
                data: (household) => household != null
                    ? HouseholdHeader(household: household)
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Members Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.members,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/households/$householdId/members');
                    },
                    child: Text(context.l10n.viewAll),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              membersAsync.when(
                data: (members) => MemberAvatars(members: members.take(5).toList()),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => Text(context.l10n.errorLoadingMembers, style: TextStyle(color: colorScheme.destructive)),
              ),
              const SizedBox(height: 24),

              // Budgets Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.budgets,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/households/$householdId/budgets');
                    },
                    child: Text(context.l10n.manage),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              budgetsAsync.when(
                data: (budgets) {
                  if (budgets.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.add_chart, size: 48, color: colorScheme.muted),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.noBudgetsYet,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.foreground,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.createSharedBudgetDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.mutedForeground),
                            ),
                            const SizedBox(height: 16),
                            shadcnui.PrimaryButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/households/$householdId/budgets/create');
                              },
                              child: Text(context.l10n.createBudget),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: budgets
                        .map((budget) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BudgetProgressCard(
                                budget: budget,
                                householdId: householdId,
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => Text(context.l10n.errorLoadingBudgets, style: TextStyle(color: colorScheme.destructive)),
              ),
              const SizedBox(height: 24),

              // Recent Splits Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.recentSplits,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/households/$householdId/splits');
                    },
                    child: Text(context.l10n.viewAll),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RecentSplitsList(householdId: householdId),
              const SizedBox(height: 24),

              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: shadcnui.OutlineButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/households/$householdId/invites');
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add, size: 18),
                          const SizedBox(width: 8),
                          Text(context.l10n.invite),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: shadcnui.PrimaryButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/households/$householdId/split/create');
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_split, size: 18),
                          const SizedBox(width: 8),
                          Text(context.l10n.split),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
