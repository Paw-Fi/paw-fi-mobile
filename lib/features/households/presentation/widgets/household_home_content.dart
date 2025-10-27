import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../pages/household_onboarding_page.dart';
import '../widgets/household_selector.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'household_metric_cards.dart';
import '../pages/create_budget_page.dart';
import '../pages/budget_detail_page.dart';
import '../pages/household_expenses_page.dart';
import '../pages/household_settings_page.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Household home content that handles loading, empty, and data states
/// Returns Sliver widgets for use in CustomScrollView
class HouseholdHomeContent extends ConsumerStatefulWidget {
  const HouseholdHomeContent({super.key});

  @override
  ConsumerState<HouseholdHomeContent> createState() => _HouseholdHomeContentState();
}

class _HouseholdHomeContentState extends ConsumerState<HouseholdHomeContent> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(
          colorScheme,
          context.l10n.userNotLoggedIn,
          context.l10n.pleaseSignInToAccessHouseholdFeatures,
        ),
      );
    }

    final householdsAsync = ref.watch(userHouseholdsProvider(userId));

    return householdsAsync.when(
      loading: () => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildLoadingState(colorScheme),
      ),
      error: (error, stack) => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(
          colorScheme,
          context.l10n.errorLoadingHouseholds,
          error.toString(),
        ),
      ),
      data: (households) {
        if (households.isEmpty) {
          // Show onboarding when user has no households
          // Use SliverToBoxAdapter with LayoutBuilder to provide proper sizing
          return SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height - 200, // Account for app bar
                  child: const HouseholdOnboardingPage(),
                );
              },
            ),
          );
        } else {
          // Initialize selected household if not set
          final selectedState = ref.watch(selectedHouseholdProvider);
          
          if (selectedState.householdId == null && !selectedState.isLoading) {
            // Auto-initialize on first load
            Future.microtask(() {
              ref.read(selectedHouseholdProvider.notifier).initialize(userId);
            });
          }
          
          // Determine which household to show
          final household = selectedState.household ?? households.first;
          
          // Filters
          final filterState = ref.watch(homeFilterProvider);
          final dateRange = getDateRangeFromFilter(
            filterState.dateRangeFilter,
            filterState.customStartDate,
            filterState.customEndDate,
          );
          final from = dateRange['from']!;
          final to = dateRange['to']!;
          final selectedCurrency = (filterState.selectedCurrency ?? household.currency).toUpperCase();

          // Data providers
          final expensesAsync = ref.watch(
            householdExpensesProvider(
              HouseholdExpensesParams(householdId: household.id, limit: 500),
            ),
          );
          final budgetsAsync = ref.watch(householdBudgetsProvider(household.id));
          final summaryAsync = ref.watch(
            householdSummaryProvider(
              HouseholdSummaryParams(householdId: household.id, currency: selectedCurrency),
            ),
          );

          // UI
          return SliverList(
            delegate: SliverChildListDelegate([
              // Header with custom expandable section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOutCubic,
                                width: _isExpanded ? 0 : 48,
                                height: 48,
                                margin: EdgeInsets.only(right: _isExpanded ? 0 : 12),
                                child: AnimatedOpacity(
                                  opacity: _isExpanded ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  child: OverflowBox(
                                    maxWidth: 48,
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: colorScheme.border.withValues(alpha: 0.4),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: household.coverImageUrl != null
                                          ? Image.network(
                                              household.coverImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stack) => Container(
                                                color: colorScheme.muted.withValues(alpha: 0.5),
                                                child: Icon(
                                                  Icons.home_rounded,
                                                  size: 24,
                                                  color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: colorScheme.muted.withValues(alpha: 0.5),
                                              child: Icon(
                                                Icons.home_rounded,
                                                size: 24,
                                                color: colorScheme.mutedForeground.withValues(alpha: 0.7),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  household.name,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    color: colorScheme.foreground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Settings icon button
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colorScheme.muted.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => HouseholdSettingsPage(householdId: household.id),
                                        ),
                                      );
                                    },
                                    child: Icon(
                                      Icons.settings_outlined,
                                      size: 20,
                                      color: colorScheme.foreground.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedRotation(
                                turns: _isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOutCubic,
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: colorScheme.mutedForeground,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                          child: _isExpanded
                              ? const Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: const [
                                    SizedBox(height: 8),
                                    HouseholdSelector(),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                ),
              ),
              const SizedBox(height: 16),

              // Spending Card with Line Chart (reuse home component)
              expensesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, st) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(context.l10n.errorLoadingExpenses, style: TextStyle(color: colorScheme.destructive)),
                ),
                data: (allExpenses) {
                  final filteredExpenses = allExpenses.where((e) {
                    final d = DateTime(e.date.year, e.date.month, e.date.day);
                    final dateOk = !d.isBefore(from) && !d.isAfter(to);
                    final rawCurrency = (e.currency ?? '').trim().toUpperCase();
                    final currencyOk = rawCurrency.isEmpty || rawCurrency == selectedCurrency;
                    return dateOk && currencyOk;
                  }).toList();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HouseholdExpensesPage(household: household),
                          ),
                        );
                      },
                      child: buildSpendingCard(
                        context,
                        colorScheme,
                        filteredExpenses,
                        null,
                        filterState.dateRangeFilter,
                        selectedCurrency: selectedCurrency,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Horizontal metric cards: Shared Budgets + Net Position
              SizedBox(
                height: 180,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    SizedBox(
                      width: 200,
                      child: budgetsAsync.when(
                        loading: () => Container(
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.border, width: 1),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, st) => Container(
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.border, width: 1),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Text('Error', style: TextStyle(color: colorScheme.destructive)),
                        ),
                        data: (budgets) => buildHouseholdBudgetCard(
                          context,
                          colorScheme,
                          budgets,
                          currencyCode: selectedCurrency,
                          budgetStatuses: summaryAsync.asData?.value?.budgets,
                          onTap: () async {
                            if (budgets.isEmpty) {
                              // Navigate to create budget
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreateBudgetPage(householdId: household.id),
                                ),
                              );
                              return;
                            }

                            await showModalBottomSheet(
                              context: context,
                              backgroundColor: colorScheme.card,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (ctx) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            Text(
                                              context.l10n.budgets,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.foreground,
                                              ),
                                            ),
                                            const Spacer(),
                                            // '+' hidden: allow only one budget at a time for now
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: budgets.length,
                                          itemBuilder: (c, i) {
                                            final b = budgets[i];
                                            return ListTile(
                                              title: Text(
                                                b.name,
                                                style: TextStyle(color: colorScheme.foreground),
                                              ),
                                              subtitle: Text(
                                                '${b.period.toJson().toUpperCase()} • ${b.currency} ${(b.amountCents / 100).toStringAsFixed(2)}',
                                                style: TextStyle(color: colorScheme.mutedForeground),
                                              ),
                                              trailing: Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
                                              onTap: () {
                                                Navigator.pop(ctx);
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => BudgetDetailPage(budget: b, householdId: household.id),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: summaryAsync.when(
                        loading: () => Container(
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.border, width: 1),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, st) => Container(
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.border, width: 1),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Text('Error', style: TextStyle(color: colorScheme.destructive)),
                        ),
                        data: (summary) => buildHouseholdNetPositionCard(
                          context,
                          colorScheme,
                          summary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HouseholdExpensesPage(household: household),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Category breakdown (reuse)
              expensesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (allExpenses) {
                  final filteredExpenses = allExpenses.where((e) {
                    final d = DateTime(e.date.year, e.date.month, e.date.day);
                    final dateOk = !d.isBefore(from) && !d.isAfter(to);
                    final rawCurrency = (e.currency ?? '').trim().toUpperCase();
                    final currencyOk = rawCurrency.isEmpty || rawCurrency == selectedCurrency;
                    return dateOk && currencyOk;
                  }).toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HouseholdExpensesPage(household: household),
                          ),
                        );
                      },
                      child: buildCategoryBreakdownCard(
                        context,
                        colorScheme,
                        filteredExpenses,
                        null,
                        selectedCurrency: selectedCurrency,
                        householdId: household.id,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Spending breakdown donut (reuse)
              expensesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (allExpenses) {
                  final filteredExpenses = allExpenses.where((e) {
                    final d = DateTime(e.date.year, e.date.month, e.date.day);
                    final dateOk = !d.isBefore(from) && !d.isAfter(to);
                    final rawCurrency = (e.currency ?? '').trim().toUpperCase();
                    final currencyOk = rawCurrency.isEmpty || rawCurrency == selectedCurrency;
                    return dateOk && currencyOk;
                  }).toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HouseholdExpensesPage(household: household),
                          ),
                        );
                      },
                      child: buildSpendingBreakdownChart(
                        context,
                        colorScheme,
                        filteredExpenses,
                        const <DailyBudgetEntry>[],
                        null,
                        filterState.dateRangeFilter,
                        selectedCurrency: selectedCurrency,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ]),
          );
        }
      },
    );
  }

  /// Full-page loading state with skeleton
  Widget _buildLoadingState(shadcnui.ColorScheme colorScheme) {
    return Container(
      color: colorScheme.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.loadingHousehold,
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

  /// Error state with retry option
  Widget _buildErrorState(
    shadcnui.ColorScheme colorScheme,
    String title,
    String message,
  ) {
    return Container(
      color: colorScheme.background,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.destructive.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 50,
                color: colorScheme.destructive,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.mutedForeground,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
