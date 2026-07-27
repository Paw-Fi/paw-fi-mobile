import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/foundation.dart' as foundation;

import 'package:moneko/core/app/app_user_context_provider.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_page_command_provider.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/moneko_tab_bar_view.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

const bool _enableDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugPrint(String? message, {int? wrapWidth}) {
  if (foundation.kDebugMode && _enableDebugLogs) {
    foundation.debugPrint(message, wrapWidth: wrapWidth);
  }
}

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
  final GlobalKey _recurringFabSpotlightKey = GlobalKey();
  final GlobalKey _recurringTabBarSpotlightKey = GlobalKey();
  late final PageController _pageController;
  late SpotlightTourController _recurringTourController;
  Locale? _recurringTourLocale;
  bool _didInitRecurringTour = false;

  /// Force refresh (used by pull-to-refresh)
  Future<void> _refresh(String? householdId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Force refresh the unified list for current scope
    await ref
        .read(recurringTransactionsProvider(householdId).notifier)
        .refresh(user.id);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ref.read(selectedRecurringTabProvider),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_didInitRecurringTour && _recurringTourLocale == locale) return;

    _recurringTourController = SpotlightTourController(
      tourId: 'recurring_transactions_v1',
      steps: [
        SpotlightStep(
          id: 'recurring_fab',
          targetKey: _recurringFabSpotlightKey,
          title: context.l10n.recurringTourFabTitle,
          description: context.l10n.recurringTourFabDescription,
          placement: SpotlightPlacement.top,
          padding: 6,
          borderRadius: 34,
        ),
        SpotlightStep(
          id: 'recurring_tab_bar',
          targetKey: _recurringTabBarSpotlightKey,
          title: context.l10n.recurringTourTabsTitle,
          description: context.l10n.recurringTourTabsDescription,
          placement: SpotlightPlacement.bottom,
          padding: 6,
          borderRadius: 24,
        ),
      ],
    );
    _recurringTourLocale = locale;
    _didInitRecurringTour = true;
  }

  Future<void> _startRecurringTourIfNeeded(int currentTabIndex) async {
    if (!_didInitRecurringTour || currentTabIndex != 1) return;
    if (supabase.auth.currentUser == null) return;

    await _recurringTourController.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = supabase.auth.currentUser;
    final currentTabIndex = ref.watch(mainShellTabIndexProvider);
    final selectedRecurringTab = ref.watch(selectedRecurringTabProvider);
    final preview = ref.watch(previewModeProvider);
    final rateTable = ref.watch(currencyRateTableProvider).valueOrNull ??
        const CurrencyRateTable(
            baseCurrency: 'USD', rates: CurrencyRates.rates);

    // Use householdScopeProvider to properly handle portfolio households
    // Portfolio households (is_portfolio=true) are treated as personal, not household
    final householdScope = ref.watch(householdScopeProvider);
    final String? householdId = switch (householdScope.activeAccountType) {
      ActiveWalletType.personal => null,
      ActiveWalletType.portfolio => householdScope.activeAccountHouseholdId,
      ActiveWalletType.household => householdScope.selectedHouseholdId,
    };

    ref.listen<RecurringPageCommand?>(recurringPageCommandProvider,
        (previous, next) {
      if (next == null) {
        return;
      }

      Future<void>.microtask(() => _handleRecurringCommand(next, householdId));
    });

    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _debugPrint('🏠 [RecurringPage] BUILD');
    _debugPrint('   IsHouseholdView: ${householdScope.isHouseholdView}');
    _debugPrint('   IsPersonalView: ${householdScope.isPersonalView}');
    _debugPrint(
        '   IsPortfolioSelected: ${householdScope.isPortfolioSelected}');
    _debugPrint('   HouseholdId: $householdId');
    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Ensure data is loaded for this scope
    final state = ref.watch(recurringTransactionsProvider(householdId));

    _debugPrint('📊 [RecurringPage] Provider State:');
    _debugPrint('   HasLoadedOnce: ${state.hasLoadedOnce}');
    _debugPrint('   IsLoading: ${state.data.isLoading}');
    _debugPrint('   HasValue: ${state.data.hasValue}');
    _debugPrint('   HasError: ${state.data.hasError}');
    if (state.data.hasValue) {
      _debugPrint('   Data count: ${state.data.value?.length ?? 0}');
    }

    final shouldTriggerPreviewLoad =
        preview.isActive && !state.hasLoadedOnce && !state.data.isLoading;

    if ((user != null || shouldTriggerPreviewLoad) &&
        !state.hasLoadedOnce &&
        !state.data.isLoading) {
      _debugPrint('🚀 [RecurringPage] Triggering initial load...');
      Future.microtask(() {
        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .loadRecurringTransactions(
                user?.id ?? PreviewMockData.contact.userId ?? 'preview-user');
      });
    } else {
      _debugPrint(
          '⏭️  [RecurringPage] Not triggering load (hasLoadedOnce=${state.hasLoadedOnce}, isLoading=${state.data.isLoading})');
    }

    // Watch the filtered providers (they derive from the unified provider)
    final recurringExpenses = ref.watch(recurringExpensesProvider(householdId));
    final recurringIncomes = ref.watch(recurringIncomesProvider(householdId));
    final filterState = ref.watch(homeFilterProvider);
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    final selectedCurrencies = filterState.normalizedSelectedCurrencies;
    final preferredTimezone = ref.watch(appPreferredTimezoneProvider);
    final userNow = effectiveNow(preferredTimezone: preferredTimezone);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startRecurringTourIfNeeded(currentTabIndex);
    });

    void selectRecurringTab(int index) {
      if (index == selectedRecurringTab) return;
      ref.read(selectedRecurringTabProvider.notifier).state = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      body: Column(
        children: [
          Padding(
            key: _recurringTabBarSpotlightKey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: MonekoSegmentedControl(
              labels: [
                context.l10n.expenses,
                context.l10n.income,
              ],
              selectedIndex: selectedRecurringTab,
              onValueChanged: selectRecurringTab,
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                ref.read(selectedRecurringTabProvider.notifier).state = index;
              },
              children: [
                _buildRecurringTabView(
                  colorScheme: colorScheme,
                  slivers: _buildExpensesSlivers(
                    recurringExpenses,
                    colorScheme,
                    selectedCurrency,
                    selectedCurrencies,
                    householdId,
                    userNow,
                    rateTable,
                  ),
                  householdId: householdId,
                  isLoading: recurringExpenses.isLoading,
                ),
                _buildRecurringTabView(
                  colorScheme: colorScheme,
                  slivers: _buildIncomesSlivers(
                    recurringIncomes,
                    colorScheme,
                    selectedCurrency,
                    selectedCurrencies,
                    householdId,
                    userNow,
                    rateTable,
                  ),
                  householdId: householdId,
                  isLoading: recurringIncomes.isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Future<void> _handleRecurringCommand(
    RecurringPageCommand command,
    String? householdId,
  ) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return;
    }

    final notifier =
        ref.read(recurringTransactionsProvider(householdId).notifier);
    var state = ref.read(recurringTransactionsProvider(householdId));
    if (!state.hasLoadedOnce || state.data.isLoading) {
      await notifier.loadRecurringTransactions(user.id, forceRefresh: true);
      state = ref.read(recurringTransactionsProvider(householdId));
    }

    final transactions =
        state.data.valueOrNull ?? const <RecurringTransaction>[];
    RecurringTransaction? transaction;
    for (final entry in transactions) {
      if (entry.id == command.recurringId) {
        transaction = entry;
        break;
      }
    }

    if (!mounted) {
      return;
    }

    if (transaction == null) {
      AppToast.info(context, context.l10n.errorLoadingData);
    } else {
      _showTransactionDetails(transaction);
    }
    ref.read(recurringPageCommandProvider.notifier).state = null;
  }

  Widget _buildRecurringTabView({
    required ColorScheme colorScheme,
    required List<Widget> slivers,
    required String? householdId,
    required bool isLoading,
  }) {
    return RefreshIndicator(
      onRefresh: () => _refresh(householdId),
      child: Skeletonizer(
        enabled: isLoading,
        effect: ShimmerEffect(
          baseColor: colorScheme.skeletonBase,
          highlightColor: colorScheme.skeletonHighlight,
        ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
      ),
    );
  }

  List<Widget> _buildExpensesSlivers(
    AsyncValue<List<dynamic>> recurringExpenses,
    ColorScheme colorScheme,
    String? selectedCurrency,
    List<String>? selectedCurrencies,
    String? householdId,
    DateTime userNow,
    CurrencyRateTable rateTable,
  ) {
    return recurringExpenses.when(
      data: (expenses) {
        final currencySet = _normalizedCurrencySet(selectedCurrencies) ??
            _normalizedCurrencySet(
              selectedCurrency == null ? null : <String>[selectedCurrency],
            );
        final filtered = (currencySet == null
                ? expenses
                : expenses
                    .where((e) => currencySet.contains(
                        (e as RecurringTransaction).currency.toUpperCase()))
                    .toList())
            .cast<RecurringTransaction>();

        return _buildTabSlivers(
          transactions: filtered,
          colorScheme: colorScheme,
          type: 'expense',
          householdId: householdId,
          isLoading: false,
          baseCurrency: selectedCurrency ?? 'USD',
          rateTable: rateTable,
          userNow: userNow,
        );
      },
      loading: () {
        final currency = selectedCurrency ?? 'USD';
        final fakeExpenses = _buildFakeRecurringTransactions(
          isIncome: false,
          currency: currency,
          now: userNow,
        );

        return _buildTabSlivers(
          transactions: fakeExpenses,
          colorScheme: colorScheme,
          type: 'expense',
          householdId: householdId,
          isLoading: true,
          baseCurrency: currency,
          rateTable: rateTable,
          userNow: userNow,
        );
      },
      error: (error, _) => [
        _buildErrorSliver(error.toString(), context.l10n.expense),
      ],
    );
  }

  List<Widget> _buildIncomesSlivers(
    AsyncValue<List<dynamic>> recurringIncomes,
    ColorScheme colorScheme,
    String? selectedCurrency,
    List<String>? selectedCurrencies,
    String? householdId,
    DateTime userNow,
    CurrencyRateTable rateTable,
  ) {
    return recurringIncomes.when(
      data: (incomes) {
        final currencySet = _normalizedCurrencySet(selectedCurrencies) ??
            _normalizedCurrencySet(
              selectedCurrency == null ? null : <String>[selectedCurrency],
            );
        final filtered = (currencySet == null
                ? incomes
                : incomes
                    .where((e) => currencySet.contains(
                        (e as RecurringTransaction).currency.toUpperCase()))
                    .toList())
            .cast<RecurringTransaction>();

        return _buildTabSlivers(
          transactions: filtered,
          colorScheme: colorScheme,
          type: 'income',
          householdId: householdId,
          isLoading: false,
          baseCurrency: selectedCurrency ?? 'USD',
          rateTable: rateTable,
          userNow: userNow,
        );
      },
      loading: () {
        final currency = selectedCurrency ?? 'USD';
        final fakeIncomes = _buildFakeRecurringTransactions(
          isIncome: true,
          currency: currency,
          now: userNow,
        );

        return _buildTabSlivers(
          transactions: fakeIncomes,
          colorScheme: colorScheme,
          type: 'income',
          householdId: householdId,
          isLoading: true,
          baseCurrency: currency,
          rateTable: rateTable,
          userNow: userNow,
        );
      },
      error: (error, _) => [
        _buildErrorSliver(error.toString(), context.l10n.income),
      ],
    );
  }

  List<Widget> _buildTabSlivers({
    required List<RecurringTransaction> transactions,
    required ColorScheme colorScheme,
    required String type,
    required String? householdId,
    required bool isLoading,
    required String baseCurrency,
    required CurrencyRateTable rateTable,
    required DateTime userNow,
  }) {
    if (!isLoading && transactions.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: EmptyRecurringState(
                type: type,
                onAddPressed: () => _showAddSheet(type),
              ),
            ),
          ),
        ),
      ];
    }

    final activeTransactions = transactions.where((t) => t.isActive).toList();
    final totalCommitted =
        _calculateTotalMonthlyCommitted(transactions, baseCurrency, rateTable);

    // Build summary card
    final summaryCardSliver = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _buildSummaryCard(
          colorScheme: colorScheme,
          total: totalCommitted,
          currencyCode: baseCurrency,
          activeCount: activeTransactions.length,
          isIncome: type == 'income',
          hasMultipleCurrencies: (ref
                      .read(homeFilterProvider)
                      .normalizedSelectedCurrencies
                      ?.length ??
                  0) >
              1,
        ),
      ),
    );

    if (isLoading) {
      // While loading, build fake transactions in a simple list without grouping headers
      return [
        summaryCardSliver,
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final transaction = transactions[index];
                return RecurringTransactionCard(
                  transaction: transaction,
                  onTap: null,
                  onDelete: null,
                );
              },
              childCount: transactions.length,
            ),
          ),
        ),
      ];
    }

    // Group transactions
    final groups = GroupedRecurringTransactions.fromList(transactions, userNow);

    final slivers = <Widget>[
      summaryCardSliver,
    ];

    Widget buildSectionHeader(String title, int count) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Row(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.mutedForeground,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: colorScheme.muted.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Helper to add a group section
    void addGroupSection({
      required String title,
      required List<RecurringTransaction> groupTransactions,
    }) {
      if (groupTransactions.isEmpty) return;
      slivers.add(
        SliverToBoxAdapter(
          child: buildSectionHeader(title, groupTransactions.length),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final transaction = groupTransactions[index];
                return RecurringTransactionCard(
                  transaction: transaction,
                  onTap: () => _showTransactionDetails(transaction),
                  onDelete: () => _deleteTransaction(transaction, householdId),
                );
              },
              childCount: groupTransactions.length,
            ),
          ),
        ),
      );
    }

    addGroupSection(
      title: context.l10n.dueIn7Days,
      groupTransactions: groups.dueIn7Days,
    );

    addGroupSection(
      title: context.l10n.dueThisMonth,
      groupTransactions: groups.dueThisMonth,
    );

    addGroupSection(
      title: context.l10n.dueLater,
      groupTransactions: groups.dueLater,
    );

    // Bottom spacing
    slivers.add(
      const SliverToBoxAdapter(
        child: SizedBox(height: 40),
      ),
    );

    return slivers;
  }

  Widget _buildSummaryCard({
    required ColorScheme colorScheme,
    required double total,
    required String currencyCode,
    required int activeCount,
    required bool isIncome,
    required bool hasMultipleCurrencies,
  }) {
    final symbol = resolveCurrencySymbol(currencyCode);
    final normalized = double.parse(formatAmount(total));
    final localizedTotal = formatLocalizedNumber(context, normalized);
    final label =
        isIncome ? context.l10n.monthlyIncome : context.l10n.monthlyCommitment;
    final subtext = isIncome
        ? (activeCount == 1
            ? '1 active paycheck'
            : '$activeCount active paychecks')
        : (activeCount == 1 ? '1 active bill' : '$activeCount active bills');

    final isDark = colorScheme.brightness == Brightness.dark;

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                 
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.mutedForeground,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              if (hasMultipleCurrencies)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.muted.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 10,
                        color: colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CONVERTED',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.mutedForeground,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                '$symbol$localizedTotal',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                currencyCode,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colorScheme.recurringSummaryGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? colorScheme.homeCardShadow
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: isDark
                ? colorScheme.homeCardShadow
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: isDark
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: content,
              )
            : content,
      ),
    );
  }

  Widget _buildErrorSliver(String error, String type) {
    final colorScheme = Theme.of(context).colorScheme;

    final householdScope = ref.watch(householdScopeProvider);
    final String? householdId = switch (householdScope.activeAccountType) {
      ActiveWalletType.personal => null,
      ActiveWalletType.portfolio => householdScope.activeAccountHouseholdId,
      ActiveWalletType.household => householdScope.selectedHouseholdId,
    };

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.12),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.errorLoadingData,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 13,
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

  Set<String>? _normalizedCurrencySet(Iterable<String>? currencies) {
    final normalized = currencies
        ?.map((currency) => currency.trim().toUpperCase())
        .where((currency) => currency.isNotEmpty)
        .toSet();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  List<RecurringTransaction> _buildFakeRecurringTransactions({
    required bool isIncome,
    required String currency,
    required DateTime now,
  }) {
    return [
      RecurringTransaction(
        id: isIncome ? 'fake-income-1' : 'fake-expense-1',
        date: now,
        category: isIncome ? 'Salary' : 'Rent',
        description: isIncome ? 'Monthly salary' : 'Monthly rent',
        source: isIncome ? 'Company' : null,
        amount: isIncome ? 2500 : 1200,
        currency: currency,
        ownerType: 'me',
        privacyScope: 'full',
        householdId: null,
        payerUserId: null,
        recurrenceRule: null,
        type: isIncome ? 'income' : 'expense',
        attachments: const [],
        createdAt: now,
        updatedAt: null,
      ),
      RecurringTransaction(
        id: isIncome ? 'fake-income-2' : 'fake-expense-2',
        date: now,
        category: isIncome ? 'Bonus' : 'Utilities',
        description: isIncome ? 'Bonus' : 'Utilities',
        source: isIncome ? 'Company' : null,
        amount: isIncome ? 400 : 150,
        currency: currency,
        ownerType: 'me',
        privacyScope: 'full',
        householdId: null,
        payerUserId: null,
        recurrenceRule: null,
        type: isIncome ? 'income' : 'expense',
        attachments: const [],
        createdAt: now,
        updatedAt: null,
      ),
    ];
  }

  void _showAddSheet(String type) {
    showAddRecurringSheet(
      context,
      type: type,
    );
  }

  void _showTransactionDetails(RecurringTransaction transaction) {
    showAddRecurringSheet(
      context,
      type: transaction.type,
      existingTransaction: transaction,
    );
  }

  Future<void> _deleteTransaction(
      RecurringTransaction transaction, String? householdId) async {
    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _debugPrint('🗑️ [RecurringPage] Delete tapped');
    _debugPrint(
        '   txId=${transaction.id} type=${transaction.type} txHouseholdId=${transaction.householdId} scopeHouseholdId=$householdId');

    final l10n = context.l10n;
    final deleteEntireSeriesLabel = l10n.deleteEntireSeries.trim().isEmpty
        ? l10n.delete
        : l10n.deleteEntireSeries;
    final skipNextOccurrenceLabel = l10n.skipNextOccurrence.trim().isEmpty
        ? l10n.skip
        : l10n.skipNextOccurrence;

    final result = await MonekoAlertDialog.show(
      context: context,
      title: l10n.deleteRecurringTransaction,
      description: l10n.deleteRecurringChoiceDescription,
      confirmLabel: deleteEntireSeriesLabel,
      secondaryLabel: skipNextOccurrenceLabel,
      cancelLabel: l10n.cancel,
      isDestructive: true,
      barrierDismissible: true,
    );

    if (result == null || result.action == MonekoAlertDialogAction.cancel) {
      _debugPrint('⏭️  [RecurringPage] Delete cancelled');
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    if (!mounted) return;

    final failedDeleteMessage = l10n.failedToDeleteRecurringTransaction;
    final skipNextOccurrenceMessage = '${l10n.skipNextOccurrence}...';
    final deleteMessage = '${l10n.delete}...';
    final occurrenceSkippedMessage = l10n.occurrenceSkipped;
    final recurringDeletedMessage = l10n.recurringTransactionDeleted;
    final unauthenticatedMessage = l10n.userNotAuthenticated;

    final user = ref.read(authProvider);
    if (user.uid.isEmpty) {
      _debugPrint('⚠️  [RecurringPage] Delete aborted: user is empty');
      AppToast.error(context, unauthenticatedMessage);
      _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final toastContext = rootNavigator.context;
    var dialogOpen = false;
    void closeDialog() {
      if (!dialogOpen) return;
      if (rootNavigator.canPop()) rootNavigator.pop();
      dialogOpen = false;
    }

    final isSkipOccurrence = result.action == MonekoAlertDialogAction.secondary;

    if (!toastContext.mounted) return;

    // Show loading dialog
    showBlockingProcessingDialog(
      context: toastContext,
      message: isSkipOccurrence ? skipNextOccurrenceMessage : deleteMessage,
    );
    dialogOpen = true;

    try {
      final notifier =
          ref.read(recurringTransactionsProvider(householdId).notifier);

      DeleteRecurringResult operationResult;

      if (isSkipOccurrence) {
        // Compute the next occurrence date to skip
        final preferredTimezone =
            ref.read(analyticsProvider).contact?.preferredTimezone;
        final userNow = effectiveNow(preferredTimezone: preferredTimezone);
        final nextDate = transaction.getNextSkippableOccurrence(userNow);
        if (nextDate == null) {
          closeDialog();
          if (!toastContext.mounted) return;
          AppToast.error(toastContext, failedDeleteMessage);
          return;
        }
        operationResult = await notifier.skipOccurrence(
          user.uid,
          transaction.id,
          nextDate,
        );
      } else {
        // Delete entire series
        operationResult =
            await notifier.deleteRecurring(user.uid, transaction.id);
      }

      if (!mounted) return;

      closeDialog();

      if (operationResult.success) {
        if (!toastContext.mounted) return;
        AppToast.success(
          toastContext,
          isSkipOccurrence ? occurrenceSkippedMessage : recurringDeletedMessage,
        );
      } else {
        if (operationResult.error == 'preview_mode_blocked') {
          return;
        }
        final message = (operationResult.error != null &&
                operationResult.error!.trim().isNotEmpty)
            ? operationResult.error!
            : failedDeleteMessage;
        if (!toastContext.mounted) return;
        AppToast.error(toastContext, message);
      }
    } catch (e) {
      closeDialog();
      if (!mounted) return;
      if (!toastContext.mounted) return;

      AppToast.error(
        toastContext,
        ErrorHandler.getUserFriendlyMessage(e),
      );
    } finally {
      closeDialog();
    }

    _debugPrint('✅ [RecurringPage] Delete operation completed');
    _debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}

double _calculateMonthlyAmount(RecurringTransaction tx) {
  if (tx.recurrenceRule == null) return 0.0;
  final rule = tx.recurrenceRule!;
  final interval = rule.interval ?? 1;
  final effectiveInterval = interval <= 0 ? 1 : interval;

  switch (rule.frequency) {
    case 'daily':
      return tx.amount * (30.0 / effectiveInterval);
    case 'weekly':
      return tx.amount * (4.333333333333333 / effectiveInterval);
    case 'biweekly':
      return tx.amount * (2.1666666666666667 / effectiveInterval);
    case 'monthly':
      return tx.amount / effectiveInterval;
    case 'yearly':
      return tx.amount / (12.0 * effectiveInterval);
    default:
      return 0.0;
  }
}

double _calculateTotalMonthlyCommitted(
  List<RecurringTransaction> transactions,
  String baseCurrency,
  CurrencyRateTable rateTable,
) {
  double total = 0.0;
  for (final tx in transactions) {
    if (!tx.isActive) continue;
    final monthlyAmount = _calculateMonthlyAmount(tx);
    final converted = rateTable.convert(
      monthlyAmount,
      tx.currency.toUpperCase(),
      baseCurrency.toUpperCase(),
    );
    total += converted;
  }
  return total;
}

class GroupedRecurringTransactions {
  final List<RecurringTransaction> dueIn7Days;
  final List<RecurringTransaction> dueThisMonth;
  final List<RecurringTransaction> dueLater;

  GroupedRecurringTransactions({
    required this.dueIn7Days,
    required this.dueThisMonth,
    required this.dueLater,
  });

  factory GroupedRecurringTransactions.fromList(
    List<RecurringTransaction> list,
    DateTime userNow,
  ) {
    final listCopy = List<RecurringTransaction>.from(list)
      ..sort((a, b) {
        final nextA = a.getNextOccurrence(userNow);
        final nextB = b.getNextOccurrence(userNow);
        return nextA.compareTo(nextB);
      });

    final dueIn7Days = <RecurringTransaction>[];
    final dueThisMonth = <RecurringTransaction>[];
    final dueLater = <RecurringTransaction>[];

    final endOf7Days = DateTime(userNow.year, userNow.month, userNow.day)
        .add(const Duration(days: 7));
    final endOfThisMonth = DateTime(userNow.year, userNow.month + 1, 0);

    for (final tx in listCopy) {
      if (!tx.isActive) {
        dueLater.add(tx);
        continue;
      }
      final nextOccurrence = tx.getNextOccurrence(userNow);
      final nextDay = DateTime(
          nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);

      if (nextDay.isBefore(endOf7Days) ||
          nextDay.isAtSameMomentAs(endOf7Days)) {
        dueIn7Days.add(tx);
      } else if (nextDay.isBefore(endOfThisMonth) ||
          nextDay.isAtSameMomentAs(endOfThisMonth)) {
        dueThisMonth.add(tx);
      } else {
        dueLater.add(tx);
      }
    }

    return GroupedRecurringTransactions(
      dueIn7Days: dueIn7Days,
      dueThisMonth: dueThisMonth,
      dueLater: dueLater,
    );
  }
}
