import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/home/presentation/utils/transaction_exporter.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:moneko/features/home/presentation/utils/transactions_page_derived_data.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/app/router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/recurring/presentation/widgets/upcoming_recurring_banner.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/utils/transaction_display_datetime.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

// ============================================================================
// TRANSACTIONS PAGE
// ============================================================================

class TransactionsPage extends ConsumerStatefulWidget {
  final String? householdId;
  final bool enableDateFilter;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const TransactionsPage({
    super.key,
    this.householdId,
    this.enableDateFilter = false,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String searchQuery = '';
  String _debouncedSearchQuery = '';
  String selectedCategory = 'all';
  String selectedType = 'all'; // all | expense | income
  int currentChartIndex = 0;

  // Date Filter State
  DateRangeFilter _selectedDateFilter = DateRangeFilter.last7Days;
  DateTime? _customStart;
  DateTime? _customEnd;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final Set<String> _optimisticallyDeletedIds = {};

  final TextEditingController _searchController = TextEditingController();
  final PageController _chartPageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _dateFilterScrollController = ScrollController();
  final GlobalKey _dateFilterScrollViewKey = GlobalKey();
  final Map<DateRangeFilter, GlobalKey> _dateFilterChipKeys = {
    for (final filter in _dateFilterOptions) filter: GlobalKey(),
  };
  Timer? _searchDebounce;
  bool _didScrollInitialDateFilterIntoView = false;

  TransactionsFeedQuery? _activeFeedQuery;
  _TransactionsDerivedCacheKey? _derivedCacheKey;
  TransactionsPageDerivedData? _cachedDerivedData;

  static const _dateFilterOptions = [
    DateRangeFilter.last7Days,
    DateRangeFilter.today,
    DateRangeFilter.yesterday,
    DateRangeFilter.thisWeek,
    DateRangeFilter.lastWeek,
    DateRangeFilter.thisMonth,
    DateRangeFilter.lastMonth,
    DateRangeFilter.last3Months,
    DateRangeFilter.last30Days,
    DateRangeFilter.thisYear,
    DateRangeFilter.allTime,
    DateRangeFilter.custom,
  ];

  String _dateFilterPrefKey(String userId) =>
      'transactions_date_filter:$userId';
  String _dateFilterCustomStartPrefKey(String userId) =>
      'transactions_date_filter_custom_start:$userId';
  String _dateFilterCustomEndPrefKey(String userId) =>
      'transactions_date_filter_custom_end:$userId';

  @override
  void initState() {
    super.initState();
    _loadDateFilterPreference();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _chartPageController.dispose();
    _scrollController.dispose();
    _dateFilterScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDateFilterPreference() async {
    final userId = ref.read(authProvider).uid;
    final prefs = ref.read(sharedPreferencesProvider);
    final savedFilterName = prefs.getString(_dateFilterPrefKey(userId));
    if (savedFilterName == null || savedFilterName.isEmpty) {
      return;
    }

    DateRangeFilter? savedFilter;
    for (final filter in DateRangeFilter.values) {
      if (filter.name == savedFilterName) {
        savedFilter = filter;
        break;
      }
    }

    if (savedFilter == null) {
      return;
    }

    DateTime? customStart;
    DateTime? customEnd;
    if (savedFilter == DateRangeFilter.custom) {
      final savedStartMillis =
          prefs.getInt(_dateFilterCustomStartPrefKey(userId));
      final savedEndMillis = prefs.getInt(_dateFilterCustomEndPrefKey(userId));
      if (savedStartMillis != null && savedEndMillis != null) {
        customStart = DateTime.fromMillisecondsSinceEpoch(savedStartMillis);
        customEnd = DateTime.fromMillisecondsSinceEpoch(savedEndMillis);
      } else {
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedDateFilter = savedFilter!;
      _customStart = customStart;
      _customEnd = customEnd;
    });
    _scheduleInitialDateFilterScroll();
  }

  void _scheduleInitialDateFilterScroll() {
    if (_didScrollInitialDateFilterIntoView) {
      return;
    }
    _didScrollInitialDateFilterIntoView = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSelectedDateFilterIntoView();
    });
  }

  void _scrollSelectedDateFilterIntoView() {
    if (!mounted || !_dateFilterScrollController.hasClients) {
      return;
    }

    final chipContext =
        _dateFilterChipKeys[_selectedDateFilter]?.currentContext;
    final scrollContext = _dateFilterScrollViewKey.currentContext;
    if (chipContext == null || scrollContext == null) {
      return;
    }

    final chipBox = chipContext.findRenderObject() as RenderBox?;
    final scrollBox = scrollContext.findRenderObject() as RenderBox?;
    if (chipBox == null || scrollBox == null) {
      return;
    }

    final chipLeft = chipBox.localToGlobal(Offset.zero).dx;
    final scrollLeft = scrollBox.localToGlobal(Offset.zero).dx;
    final targetOffset = (_dateFilterScrollController.offset +
            chipLeft -
            scrollLeft -
            (scrollBox.size.width - chipBox.size.width) / 2)
        .clamp(0.0, _dateFilterScrollController.position.maxScrollExtent)
        .toDouble();

    _dateFilterScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _persistDateFilterPreference() async {
    final userId = ref.read(authProvider).uid;
    final prefs = ref.read(sharedPreferencesProvider);

    await prefs.setString(_dateFilterPrefKey(userId), _selectedDateFilter.name);

    if (_selectedDateFilter == DateRangeFilter.custom &&
        _customStart != null &&
        _customEnd != null) {
      await prefs.setInt(
        _dateFilterCustomStartPrefKey(userId),
        _customStart!.millisecondsSinceEpoch,
      );
      await prefs.setInt(
        _dateFilterCustomEndPrefKey(userId),
        _customEnd!.millisecondsSinceEpoch,
      );
      return;
    }

    await prefs.remove(_dateFilterCustomStartPrefKey(userId));
    await prefs.remove(_dateFilterCustomEndPrefKey(userId));
  }

  List<ExpenseEntry> _baseExpenses = const [];

  String? get _recurringScopeHouseholdId {
    final householdScope = ref.read(householdScopeProvider);
    return widget.householdId ??
        (householdScope.activeAccountType == ActiveWalletType.personal
            ? null
            : householdScope.activeAccountHouseholdId);
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _debouncedSearchQuery = value;
      });
    });
  }

  Future<void> _loadMoreTransactions() async {
    final query = _activeFeedQuery;
    if (query == null) {
      return;
    }

    await ref.read(transactionsFeedProvider(query).notifier).loadMore();
  }

  TransactionsPageDerivedData _resolveDerivedData({
    required HouseholdScope householdScope,
    required String? selectedCurrency,
    required List<String>? selectedCurrencies,
    required DateTime userNow,
    required List<ExpenseEntry> projectedRecurringExpenses,
  }) {
    final dayAnchor = DateTime(userNow.year, userNow.month, userNow.day);
    final filterCacheKey = _TransactionsFilterCacheKey(
      searchQuery: _debouncedSearchQuery,
      selectedCategory: selectedCategory,
      selectedType: selectedType,
      selectedCurrency: selectedCurrency?.toUpperCase(),
      selectedCurrencies: selectedCurrencies,
      selectedDateFilter: _selectedDateFilter,
      customStart: _customStart,
      customEnd: _customEnd,
      pinnedHouseholdId: widget.householdId,
      activeAccountType: householdScope.activeAccountType,
      activeAccountHouseholdId: householdScope.activeAccountHouseholdId,
      selectedHouseholdId: householdScope.selectedHouseholdId,
      dayAnchor: dayAnchor,
    );
    final derivedCacheKey = _TransactionsDerivedCacheKey(
      baseExpensesSignature: _expenseEntriesSignature(_baseExpenses),
      projectedRecurringExpensesSignature:
          _expenseEntriesSignature(projectedRecurringExpenses),
      filterCacheKey: filterCacheKey,
    );

    if (_cachedDerivedData != null && _derivedCacheKey == derivedCacheKey) {
      return _cachedDerivedData!;
    }

    final derivedData = deriveTransactionsPageData(
      TransactionsPageFilterInput(
        baseExpenses: _baseExpenses,
        projectedRecurringExpenses: projectedRecurringExpenses,
        searchQuery: _debouncedSearchQuery,
        selectedCategory: selectedCategory,
        selectedType: selectedType,
        selectedCurrency: selectedCurrency,
        selectedCurrencies: selectedCurrencies,
        selectedDateFilter: _selectedDateFilter,
        customStart: _customStart,
        customEnd: _customEnd,
        now: userNow,
        pinnedHouseholdId: widget.householdId,
        activeAccountType: householdScope.activeAccountType,
        activeAccountHouseholdId: householdScope.activeAccountHouseholdId,
        selectedHouseholdId: householdScope.selectedHouseholdId,
      ),
    );

    _derivedCacheKey = derivedCacheKey;
    _cachedDerivedData = derivedData;

    return derivedData;
  }

  int _expenseEntriesSignature(List<ExpenseEntry> expenses) {
    return Object.hashAll(
      expenses.map(
        (expense) => Object.hash(
          expense.id,
          expense.date,
          expense.amountCents,
          expense.householdId,
          expense.currency,
          expense.category,
          expense.rawText,
          expense.type,
          expense.isRecurring,
          expense.walletId,
        ),
      ),
    );
  }

  String _selectedPeriodLabel(BuildContext context) {
    if (_selectedDateFilter == DateRangeFilter.custom &&
        _customStart != null &&
        _customEnd != null) {
      final locale = Localizations.localeOf(context).toString();
      final formatter = DateFormat('MMM d', locale);
      final startLabel = formatter.format(_customStart!);
      final endLabel = formatter.format(_customEnd!);
      return startLabel == endLabel ? startLabel : '$startLabel - $endLabel';
    }

    return _selectedDateFilter.getLabel(context);
  }

  void _showRootSuccessToast(String message) {
    final rootContext = rootNavigatorKey.currentContext;
    if (rootContext == null) return;

    AppToast.success(rootContext, message);
  }

  void _showRootErrorToast(String message) {
    final rootContext = rootNavigatorKey.currentContext;
    if (rootContext == null) return;

    AppToast.error(rootContext, message);
  }

  Future<void> _refreshActiveFeed() async {
    final query = _activeFeedQuery;
    if (query == null) {
      return;
    }
    await ref.read(transactionsFeedProvider(query).notifier).refresh();
    ref.invalidate(transactionsFeedAllItemsProvider(query));
  }

  Future<void> _exportTransactions(
    TransactionsFeedQuery query, {
    required List<ExpenseEntry> projectedRecurringExpenses,
  }) async {
    final householdScope = ref.read(householdScopeProvider);
    final allExpenses =
        await ref.read(transactionsFeedServiceProvider).fetchAllPages(
              query,
            );
    final exportData = deriveTransactionsPageData(
      TransactionsPageFilterInput(
        baseExpenses: allExpenses,
        projectedRecurringExpenses: projectedRecurringExpenses,
        searchQuery: '',
        selectedCategory: 'all',
        selectedType: 'all',
        selectedCurrency: null,
        selectedDateFilter: DateRangeFilter.allTime,
        customStart: null,
        customEnd: null,
        now: DateTime.now(),
        pinnedHouseholdId: widget.householdId,
        activeAccountType: householdScope.activeAccountType,
        activeAccountHouseholdId: householdScope.activeAccountHouseholdId,
        selectedHouseholdId: householdScope.selectedHouseholdId,
      ),
    );

    if (!mounted) {
      return;
    }

    await exportTransactionsAsExcelSheet(
      context,
      exportData.filteredExpenses,
      fileNamePrefix: widget.householdId != null
          ? 'household_transactions'
          : 'transactions',
    );
  }

  void _openRecurringTransactionEditor(RecurringTransaction transaction) {
    showAddRecurringSheet(
      context,
      type: transaction.type,
      existingTransaction: transaction,
    );
  }

  Widget _buildUpcomingRecurringBannerSliver(ColorScheme colorScheme) {
    final hasActivePageFilters = searchQuery.isNotEmpty ||
        selectedCategory != 'all' ||
        selectedType != 'all' ||
        _selectedDateFilter != DateRangeFilter.allTime;
    if (hasActivePageFilters) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final filterState = ref.watch(homeFilterProvider);
    final upcoming = ref.watch(
      upcomingRecurringTransactionProvider(
        UpcomingRecurringScope(
          householdId: _recurringScopeHouseholdId,
          currency: filterState.selectedCurrency,
        ),
      ),
    );

    if (upcoming == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: UpcomingRecurringBanner(
          upcoming: upcoming,
          onTap: () => _openRecurringTransactionEditor(upcoming.transaction),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analyticsContact =
        ref.watch(analyticsProvider.select((state) => state.contact));
    final householdScope = ref.watch(householdScopeProvider);
    final filterState = ref.watch(homeFilterProvider);
    final selectedCurrency = filterState.selectedCurrency;
    final selectedCurrencies = filterState.normalizedSelectedCurrencies;
    final userCategoryLists = ref.watch(userCategoryListsProvider).valueOrNull;
    final userNow = effectiveNow(
      preferredTimezone: analyticsContact?.preferredTimezone,
    );
    final recurringTransactions = ref
            .watch(recurringTransactionsProvider(_recurringScopeHouseholdId))
            .data
            .valueOrNull ??
        const <RecurringTransaction>[];
    final projectedRecurringExpenses = recurringTransactions.isEmpty
        ? const <ExpenseEntry>[]
        : projectRecurringTransactionsAsExpenseEntries(
            recurringTransactions: recurringTransactions,
            rangeStart: DateTime(2000),
            rangeEnd: userNow,
            selectedCurrency: selectedCurrency,
          );
    final recurringTransactionsById = {
      for (final transaction in recurringTransactions)
        transaction.id: transaction,
    };
    final currentUserId = ref.watch(authProvider.select((state) => state.uid));
    final scopedAccounts =
        ref.watch(scopedWalletsProvider).valueOrNull ?? const <WalletEntity>[];
    final accountLabelsById = {
      for (final account in scopedAccounts)
        if (account.id.isNotEmpty) account.id: account.name,
    };

    final effectiveHouseholdId = widget.householdId ??
        (householdScope.activeAccountType == ActiveWalletType.personal
            ? null
            : householdScope.activeAccountHouseholdId);
    final range = _selectedDateFilter == DateRangeFilter.allTime
        ? null
        : getDateRangeFromFilter(
            _selectedDateFilter,
            _customStart,
            _customEnd,
            now: userNow,
          );
    final feedQuery = TransactionsFeedQuery(
      userId: currentUserId,
      householdId: effectiveHouseholdId,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      selectedCategory: selectedCategory == 'all' ? null : selectedCategory,
      selectedType: selectedType,
      searchQuery: _debouncedSearchQuery,
      startDate: range?['from'],
      endDate: range?['to'],
    );
    _activeFeedQuery = feedQuery;

    final feedState = ref.watch(transactionsFeedProvider(feedQuery));
    final isMultiCurrencySelection = (selectedCurrencies?.length ?? 0) > 1;
    final chartSourceState = isMultiCurrencySelection
        ? ref.watch(transactionsFeedAllItemsProvider(feedQuery))
        : null;
    final rateTable = ref.watch(currencyRateTableProvider).valueOrNull ??
        const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: CurrencyRates.rates,
        );
    _baseExpenses = feedState.items
        .where((entry) => !_optimisticallyDeletedIds.contains(entry.id))
        .toList(growable: false);
    final shouldLoadCompleteGroupTotals = range != null &&
        range['from']!.year == range['to']!.year &&
        range['from']!.month == range['to']!.month;
    final completeActualExpensesState = shouldLoadCompleteGroupTotals
        ? ref.watch(transactionsFeedAllItemsProvider(feedQuery))
        : null;
    final completeActualExpenses = completeActualExpensesState?.valueOrNull;
    final shouldSuppressHeaderTotals = shouldLoadCompleteGroupTotals &&
        feedState.hasMore &&
        completeActualExpenses == null;

    final projectedOnlyDerivedData = deriveTransactionsPageData(
      TransactionsPageFilterInput(
        baseExpenses: const <ExpenseEntry>[],
        projectedRecurringExpenses: projectedRecurringExpenses,
        searchQuery: _debouncedSearchQuery,
        selectedCategory: selectedCategory,
        selectedType: selectedType,
        selectedCurrency: selectedCurrency,
        selectedCurrencies: selectedCurrencies,
        selectedDateFilter: _selectedDateFilter,
        customStart: _customStart,
        customEnd: _customEnd,
        now: userNow,
        pinnedHouseholdId: widget.householdId,
        activeAccountType: householdScope.activeAccountType,
        activeAccountHouseholdId: householdScope.activeAccountHouseholdId,
        selectedHouseholdId: householdScope.selectedHouseholdId,
      ),
    );

    final derivedData = _resolveDerivedData(
      householdScope: householdScope,
      selectedCurrency: selectedCurrency,
      selectedCurrencies: selectedCurrencies,
      userNow: userNow,
      projectedRecurringExpenses: projectedRecurringExpenses,
    );
    final completeGroupTotals = completeActualExpenses == null
        ? const CompleteTransactionGroupTotals()
        : buildCompleteTransactionGroupTotals(
            deriveTransactionsPageData(
              TransactionsPageFilterInput(
                baseExpenses: completeActualExpenses,
                projectedRecurringExpenses: projectedRecurringExpenses,
                searchQuery: _debouncedSearchQuery,
                selectedCategory: selectedCategory,
                selectedType: selectedType,
                selectedCurrency: selectedCurrency,
                selectedCurrencies: selectedCurrencies,
                selectedDateFilter: _selectedDateFilter,
                customStart: _customStart,
                customEnd: _customEnd,
                now: userNow,
                pinnedHouseholdId: widget.householdId,
                activeAccountType: householdScope.activeAccountType,
                activeAccountHouseholdId:
                    householdScope.activeAccountHouseholdId,
                selectedHouseholdId: householdScope.selectedHouseholdId,
              ),
            ).monthGroups,
          );
    final groupCompleteness = resolveTransactionGroupCompleteness(
      loadedExpenses: feedState.items,
      hasMore: feedState.hasMore,
    );

    final chartSummary = isMultiCurrencySelection
        ? summarizeTransactionsInCurrency(
            [
              ...?chartSourceState?.valueOrNull,
              ...projectedOnlyDerivedData.filteredExpenses,
            ],
            targetCurrency: selectedCurrency ?? 'USD',
            rates: rateTable,
            intervalGranularity:
                feedQuery.normalizedSummaryIntervalGranularity ?? 'yearly',
          )
        : feedState.summary.addingExpenses(
            projectedOnlyDerivedData.filteredExpenses,
          );
    final isChartSourceLoading = isMultiCurrencySelection &&
        chartSourceState?.valueOrNull == null &&
        (chartSourceState?.isLoading ?? false);
    final isChartSourceError = isMultiCurrencySelection &&
        chartSourceState?.valueOrNull == null &&
        (chartSourceState?.hasError ?? false);

    final availableCategories = _resolveAvailableCategories(userCategoryLists);

    return _buildMainScaffold(
      colorScheme: colorScheme,
      contact: analyticsContact,
      feedQuery: feedQuery,
      feedState: feedState,
      derivedData: derivedData,
      groupCompleteness: groupCompleteness,
      completeGroupTotals: completeGroupTotals,
      shouldSuppressHeaderTotals: shouldSuppressHeaderTotals,
      chartSummary: chartSummary,
      isChartSourceLoading: isChartSourceLoading,
      isChartSourceError: isChartSourceError,
      availableCategories: availableCategories,
      currentUserId: currentUserId,
      accountLabelsById: accountLabelsById,
      recurringTransactionsById: recurringTransactionsById,
    );
  }

  List<String> _resolveAvailableCategories(UserCategoryLists? lists) {
    final expenseCategories =
        lists?.expenseCategories ?? getExpenseCategories();
    final incomeCategories = lists?.incomeCategories ?? getIncomeCategories();

    final merged = switch (selectedType) {
      'expense' => expenseCategories,
      'income' => incomeCategories,
      _ => {...expenseCategories, ...incomeCategories}.toList()..sort(),
    };

    return ['all', ...merged.where((category) => category != 'all')];
  }

  Widget _buildMainScaffold({
    required ColorScheme colorScheme,
    required UserContact? contact,
    required TransactionsFeedQuery feedQuery,
    required TransactionsFeedState feedState,
    required TransactionsPageDerivedData derivedData,
    required TransactionGroupCompleteness groupCompleteness,
    required CompleteTransactionGroupTotals completeGroupTotals,
    required bool shouldSuppressHeaderTotals,
    required TransactionsFeedSummary chartSummary,
    required bool isChartSourceLoading,
    required bool isChartSourceError,
    required List<String> availableCategories,
    required String currentUserId,
    required Map<String, String> accountLabelsById,
    required Map<String, RecurringTransaction> recurringTransactionsById,
  }) {
    final expensesToExport = derivedData.filteredExpenses;
    final visibleListItems = buildVisibleTransactionRenderItems(
      monthGroups: derivedData.monthGroups,
      visibleExpenseCount: derivedData.filteredExpenses.length,
    );
    final visibleListItemIndexByKey = buildTransactionRenderItemIndexByKey(
      visibleListItems,
    );

    // Prepare Filter Menu Items
    final filterItems = <AdaptivePopupMenuItem>[
      // Type Options
      ...['all', 'expense', 'income'].map((type) {
        final isSelected = selectedType == type;
        final label = type == 'all'
            ? context.l10n.all
            : type == 'expense'
                ? context.l10n.expenses
                : context.l10n.income;
        return AdaptivePopupMenuItem(
          label: 'Type: $label',
          icon: isSelected
              ? (PlatformInfo.isIOS26OrHigher() ? 'checkmark' : Icons.check)
              : null,
          value: 'type_$type',
        );
      }),
    ];

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      // Remove default AppBar to use SliverAppBar for custom actions logic
      // appBar: null,
      body: Material(
        color: colorScheme.appleGroupedBackground,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(transactionsFeedProvider(feedQuery).notifier)
                .refresh();
            ref.invalidate(transactionsFeedAllItemsProvider(feedQuery));
          },
          child: AutoPaginatedScroll(
            hasMore: feedState.hasMore,
            isLoading: feedState.isLoading,
            isLoadingMore: feedState.isLoadingMore,
            onLoadMore: _loadMoreTransactions,
            child: CustomScrollView(
              controller: _scrollController,
              key: const PageStorageKey('transactions_scroll'),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  snap: true,
                  backgroundColor: colorScheme.appleGroupedBackground,
                  surfaceTintColor: Colors.transparent,
                  title: Text(
                    _isSelectionMode
                        ? '${_selectedIds.length} Selected'
                        : context.l10n.transactions,
                    style: TextStyle(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.bold),
                  ),
                  iconTheme: IconThemeData(color: colorScheme.foreground),
                  actions: [
                    if (!_isSelectionMode) ...[
                      if (expensesToExport.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.checklist_rounded,
                              color: colorScheme.foreground),
                          onPressed: () {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedIds.clear();
                            });
                          },
                        ),
                      AdaptivePopupMenuButton.widget(
                        items: filterItems,
                        onSelected: (index, item) async {
                          final value = item.value as String;
                          if (value.startsWith('type_')) {
                            setState(() => selectedType = value.substring(5));
                          } else if (value == 'category_filter') {
                            _showFilterSheet(
                              context,
                              colorScheme,
                              availableCategories,
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: Icon(Icons.filter_list_rounded,
                              color: colorScheme.foreground),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.file_download_rounded,
                            color: colorScheme.foreground),
                        onPressed: () => _exportTransactions(
                          feedQuery,
                          projectedRecurringExpenses: derivedData
                              .filteredExpenses
                              .where((expense) =>
                                  extractRecurringTransactionIdFromProjectedExpenseId(
                                    expense.id,
                                  ) !=
                                  null)
                              .toList(),
                        ),
                      ),
                    ] else ...[
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.foreground),
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedIds.clear();
                          });
                        },
                      ),
                    ]
                  ],
                ),

                _buildUpcomingRecurringBannerSliver(colorScheme),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.card,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: Theme.of(context).brightness ==
                                Brightness.dark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                )
                              ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: TextStyle(
                            color: colorScheme.foreground, fontSize: 17),
                        decoration: InputDecoration(
                          hintText: context.l10n.search,
                          hintStyle: TextStyle(
                              color: colorScheme.mutedForeground, fontSize: 17),
                          prefixIcon: Icon(Icons.search,
                              color: colorScheme.mutedForeground, size: 22),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),

                // Date Filter Chips
                SliverToBoxAdapter(
                  child: _buildDateFilterChips(colorScheme),
                ),

                // Chart Display
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: isChartSourceLoading
                        ? const Center(child: CircularProgressIndicator())
                        : isChartSourceError
                            ? Center(
                                child: Text(
                                  context
                                      .l10n.failedToLoadHouseholdTransactions,
                                  style: TextStyle(
                                    color: colorScheme.destructive,
                                  ),
                                ),
                              )
                            : _buildChart(
                                colorScheme,
                                chartSummary,
                              ),
                  ),
                ),

                // Transactions List Groups
                expensesToExport.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48.0),
                            child: feedState.isLoading
                                ? const CircularProgressIndicator()
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 64,
                                        color: colorScheme.mutedForeground,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        feedState.error == null
                                            ? context.l10n.noTransactionsFound
                                            : context.l10n
                                                .failedToLoadHouseholdTransactions,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: feedState.error == null
                                              ? colorScheme.mutedForeground
                                              : colorScheme.destructive,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = visibleListItems[index];
                            if (item.isMonthHeader) {
                              return _buildMonthHeader(
                                context,
                                item.monthGroup!,
                                colorScheme,
                                key: ValueKey(item.key),
                              );
                            }
                            if (item.isDayHeader) {
                              final completeDayGroup = completeGroupTotals
                                  .dayGroupFor(item.dayGroup!.date);
                              return _buildDayHeader(
                                context,
                                item.dayGroup!,
                                colorScheme,
                                key: ValueKey(item.key),
                                preferredTimezone: contact?.preferredTimezone,
                                isTotalComplete: !shouldSuppressHeaderTotals &&
                                    groupCompleteness.isDayComplete(
                                      item.dayGroup!.date,
                                    ),
                                totalOverrideGroup: completeDayGroup,
                              );
                            }

                            return _buildTransactionRow(
                              context,
                              item.expense!,
                              contact,
                              colorScheme,
                              key: ValueKey(item.key),
                              currentUserId: currentUserId,
                              accountLabelsById: accountLabelsById,
                              recurringTransactionsById:
                                  recurringTransactionsById,
                              isFirst: item.isFirst,
                              isLast: item.isLast,
                            );
                          },
                          childCount: visibleListItems.length,
                          findChildIndexCallback: (key) {
                            final valueKey = key;
                            if (valueKey is! ValueKey<String>) {
                              return null;
                            }
                            return visibleListItemIndexByKey[valueKey.value];
                          },
                        ),
                      ),

                PaginatedLoadMoreSliverIndicator(
                  show: feedState.isLoadingMore,
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _handleBulkDelete,
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              elevation: 4,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('${context.l10n.delete} (${_selectedIds.length})'),
            )
          : null,
    ));
  }

  Widget _buildMonthHeader(
    BuildContext context,
    MonthTransactionGroup group,
    ColorScheme colorScheme, {
    Key? key,
  }) {
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = formatMonthHeader(group.monthStart, locale: locale);

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        dateLabel,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.mutedForeground,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    DayTransactionGroup group,
    ColorScheme colorScheme, {
    Key? key,
    required String? preferredTimezone,
    bool isTotalComplete = true,
    DayTransactionGroup? totalOverrideGroup,
  }) {
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(group.date.year, group.date.month, group.date.day);
    String dateLabel;

    if (date == today) {
      dateLabel = context.l10n.today;
    } else if (date == yesterday) {
      dateLabel = context.l10n.yesterday;
    } else {
      final locale = Localizations.localeOf(context).toString();
      dateLabel = DateFormat('MMM d', locale).format(date);
    }

    final totalGroup = totalOverrideGroup ?? group;
    final selectedCurrency =
        ref.read(homeFilterProvider).selectedCurrency?.toUpperCase();
    final currencies = totalGroup.expenses
        .map((expense) => expense.currency?.toUpperCase())
        .where((currency) => currency != null && currency.isNotEmpty)
        .cast<String>()
        .toSet();

    String? totalString;
    final total = resolveDayTransactionHeaderTotal(totalGroup);
    if (!isTotalComplete && totalOverrideGroup == null) {
      totalString = null;
    } else if (currencies.length > 1) {
      totalString = context.l10n.multipleCurrencies;
    } else if (selectedCurrency != null) {
      final totalFormatted = formatLocalizedNumber(context, total.abs());
      final symbol = resolveCurrencySymbol(selectedCurrency);
      totalString = '${total < 0 ? '-' : ''}$symbol$totalFormatted';
    } else if (currencies.length == 1) {
      final currency = currencies.first;
      final totalFormatted = formatLocalizedNumber(context, total.abs());
      final symbol = resolveCurrencySymbol(currency);
      totalString = '${total < 0 ? '-' : ''}$symbol$totalFormatted';
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          if (totalString != null) ...[
            const SizedBox(width: 8),
            Text(
              totalString,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionRow(
    BuildContext context,
    ExpenseEntry item,
    UserContact? contact,
    ColorScheme colorScheme, {
    Key? key,
    required String currentUserId,
    required Map<String, String> accountLabelsById,
    required Map<String, RecurringTransaction> recurringTransactionsById,
    required bool isFirst,
    required bool isLast,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(24) : Radius.zero,
      bottom: isLast ? const Radius.circular(24) : Radius.zero,
    );
    final shouldShadow = isFirst || isLast;

    return Container(
      key: key,
      margin: EdgeInsets.fromLTRB(16, 0, 16, isLast ? 16 : 0),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colorScheme.homeCardSurface,
        borderRadius: radius,
        boxShadow:
            Theme.of(context).brightness == Brightness.dark || !shouldShadow
                ? null
                : [
                    BoxShadow(
                      color: colorScheme.homeCardShadow,
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    )
                  ],
      ),
      child: _buildTransactionItem(
        context,
        item,
        contact,
        currentUserId: currentUserId,
        accountLabelsById: accountLabelsById,
        recurringTransactionsById: recurringTransactionsById,
        isLast: isLast,
      ),
    );
  }

  Future<void> _handleBulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final dialogResult = await MonekoAlertDialog.show(
      context: context,
      title:
          '${context.l10n.delete} ${_selectedIds.length} ${context.l10n.transactions}?',
      description: context.l10n.confirmDeleteExpense,
      confirmLabel: context.l10n.delete,
      cancelLabel: context.l10n.cancel,
      isDestructive: true,
    );

    final confirmed = dialogResult?.confirmed == true;

    if (!confirmed) return;

    final selectedIds = Set<String>.from(_selectedIds);
    final selectedExpenses = _baseExpenses
        .where((expense) => selectedIds.contains(expense.id))
        .toList(growable: false);
    if (selectedExpenses.isEmpty) return;

    setState(() {
      _optimisticallyDeletedIds.addAll(selectedIds);
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    _showRootSuccessToast('Transactions deleted successfully');

    final success = await ref
        .read(transactionEditProvider.notifier)
        .deleteExpensesOptimistically(selectedExpenses);

    if (!mounted) return;

    if (!success) {
      setState(() {
        _optimisticallyDeletedIds.removeAll(selectedIds);
      });
      final error = ref.read(transactionEditProvider).error;
      _showRootErrorToast(
        ErrorHandler.getUserFriendlyMessage(
          error,
          context: BackendErrorContext.deleteExpense,
        ),
      );
    } else {
      await _refreshActiveFeed();
    }
  }

  Future<void> _handleSingleDelete(ExpenseEntry expense) async {
    final l10n = context.l10n;

    final result = await MonekoAlertDialog.show(
      context: context,
      title: l10n.delete,
      description: l10n.confirmDeleteExpense,
      confirmLabel: l10n.delete,
      isDestructive: true,
    );

    if (result?.confirmed != true) return;

    setState(() {
      _optimisticallyDeletedIds.add(expense.id);
    });
    _showRootSuccessToast(l10n.transactionDeleted);

    final success = await ref
        .read(transactionEditProvider.notifier)
        .deleteExpensesOptimistically([expense]);

    if (!mounted) return;

    if (!success) {
      setState(() {
        _optimisticallyDeletedIds.remove(expense.id);
      });
      final error = ref.read(transactionEditProvider).error;
      _showRootErrorToast(
        ErrorHandler.getUserFriendlyMessage(
          error,
          context: BackendErrorContext.deleteExpense,
        ),
      );
    } else {
      await _refreshActiveFeed();
    }
  }

  Widget _buildDateFilterChips(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: SizedBox(
        height: 35,
        child: SingleChildScrollView(
          key: _dateFilterScrollViewKey,
          controller: _dateFilterScrollController,
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final filter in _dateFilterOptions) ...[
                  _buildDateFilterChip(colorScheme, filter),
                  if (filter != _dateFilterOptions.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(
    ColorScheme colorScheme,
    DateRangeFilter filter,
  ) {
    final isSelected = _selectedDateFilter == filter;

    String label;
    if (filter == DateRangeFilter.custom &&
        _customStart != null &&
        _customEnd != null &&
        isSelected) {
      final fmt = DateFormat('MMM d');
      label = '${fmt.format(_customStart!)} – ${fmt.format(_customEnd!)}';
    } else {
      label = filter.getLabel(context);
    }

    return GestureDetector(
      key: _dateFilterChipKeys[filter],
      onTap: () async {
        if (filter == DateRangeFilter.custom) {
          final result = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: effectiveNow(
              preferredTimezone:
                  ref.read(analyticsProvider).contact?.preferredTimezone,
            ),
            initialDateRange: _customStart != null && _customEnd != null
                ? DateTimeRange(start: _customStart!, end: _customEnd!)
                : null,
          );
          if (result != null) {
            setState(() {
              _selectedDateFilter = DateRangeFilter.custom;
              _customStart = result.start;
              _customEnd = result.end;
            });
            unawaited(_persistDateFilterPreference());
          }
        } else {
          setState(() {
            _selectedDateFilter = filter;
            _customStart = null;
            _customEnd = null;
          });
          unawaited(_persistDateFilterPreference());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.border.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? colorScheme.primaryForeground
                : colorScheme.foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildChart(
    ColorScheme colorScheme,
    TransactionsFeedSummary summary,
  ) {
    const pageHeights = [420.0, 280.0, 280.0];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(10), // Radius 10
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ExpandablePageView(
            controller: _chartPageController,
            currentPage: currentChartIndex,
            pageHeights: pageHeights,
            itemCount: 3,
            onPageChanged: (index) {
              setState(() {
                currentChartIndex = index;
              });
            },
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildPieChart(colorScheme, summary),
                  );
                case 1:
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildLineChart(
                        colorScheme, summary.yearlyPeriodTotals),
                  );
                default:
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child:
                        _buildBarChart(colorScheme, summary.yearlyPeriodTotals),
                  );
              }
            },
          ),
          const SizedBox(height: 16),
          // Carousel indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return GestureDetector(
                onTap: () {
                  _chartPageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: currentChartIndex == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: currentChartIndex == index
                        ? colorScheme.primary
                        : colorScheme.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    ColorScheme colorScheme,
    TransactionsFeedSummary summary,
  ) {
    final categorySummaries = summary.categorySummaries
        .map(
          (category) => CategorySummary(
            category: category.category,
            amount: category.amount,
            transactionCount: category.transactionCount,
            color: getCategoryColor(category.category),
          ),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: TransactionsPieChart(
        colorScheme: colorScheme,
        expenses: const <ExpenseEntry>[],
        selectedCurrency: ref.watch(homeFilterProvider).selectedCurrency,
        periodLabel: _selectedPeriodLabel(context),
        categorySummariesOverride: categorySummaries,
        totalSpentOverride: summary.expenseTotal,
        initialDateFilter: _selectedDateFilter,
        initialStartDate: _customStart,
        initialEndDate: _customEnd,
      ),
    );
  }

  /// Format Y-axis values dynamically based on magnitude
  String _formatYAxisValue(double value) {
    if (value == 0) return '0';

    final absValue = value.abs();

    // For values >= 1 million
    if (absValue >= 1000000) {
      final millions = value / 1000000;
      // Show 1 decimal place for millions, unless it's a whole number
      if (millions == millions.truncate()) {
        return '${millions.truncate()}M';
      }
      return '${millions.toStringAsFixed(1)}M';
    }

    // For values >= 1 thousand
    if (absValue >= 1000) {
      final thousands = value / 1000;
      // Show 1 decimal place for thousands, unless it's a whole number
      if (thousands == thousands.truncate()) {
        return '${thousands.truncate()}k';
      }
      return '${thousands.toStringAsFixed(1)}k';
    }

    // For values < 1000, show as-is
    // Show whole numbers without decimals
    if (value == value.truncate()) {
      return value.truncate().toString();
    }
    // Show up to 2 decimal places, removing trailing zeros
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  Widget _buildLineChart(
    ColorScheme colorScheme,
    Map<DateTime, double> periodTotals,
  ) {
    const chartIntervalType = 'yearly';
    final sortedDates = periodTotals.keys.toList()..sort();
    if (sortedDates.isEmpty) {
      return Center(
        child: Text(context.l10n.noData,
            style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }

    // Calculate cumulative spending
    double cumulative = 0;
    final cumulativeData = <FlSpot>[];
    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      cumulative += periodTotals[date] ?? 0;
      cumulativeData.add(FlSpot(i.toDouble(), cumulative));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: cumulative > 0 ? cumulative / 4 : 100,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colorScheme.border.withValues(alpha: 0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatYAxisValue(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.mutedForeground,
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval:
                    1, // Show all data points (already bucketed to 6-7 points)
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= sortedDates.length) {
                    return const SizedBox();
                  }
                  final date = sortedDates[value.toInt()];
                  return Text(
                    formatDateForInterval(date, chartIntervalType),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.mutedForeground,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: cumulativeData,
              isCurved: true,
              color: AppTheme.monekoPrimary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  if (index == cumulativeData.length - 1) {
                    return FlDotCirclePainter(
                      radius: 7,
                      color: AppTheme.danger,
                      strokeWidth: 3,
                      strokeColor: colorScheme.onError,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 0,
                    color: colorScheme.surface.withValues(alpha: 0.0),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.monekoPrimary.withValues(alpha: 0.28),
                    AppTheme.monekoPrimary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: cumulative > 0 ? (cumulative * 1.25).ceilToDouble() : 100,
        ),
      ),
    );
  }

  Widget _buildBarChart(
    ColorScheme colorScheme,
    Map<DateTime, double> periodTotals,
  ) {
    const chartIntervalType = 'yearly';
    final periodDates = <String, DateTime>{};
    final periodLabels = <String, double>{};
    for (final entry in periodTotals.entries) {
      final label = formatDateForInterval(entry.key, chartIntervalType);
      periodDates[label] = entry.key;
      periodLabels[label] = entry.value;
    }
    final sortedPeriods = periodLabels.keys.toList()
      ..sort(
          (left, right) => periodDates[left]!.compareTo(periodDates[right]!));
    final barData = BarChartPeriodData(
      periodTotals: periodLabels,
      periodDates: periodDates,
      sortedPeriods: sortedPeriods,
    );

    if (barData.periodTotals.isEmpty) {
      return Center(
        child: Text(context.l10n.noData,
            style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }

    final maxValue =
        barData.periodTotals.values.reduce((a, b) => a > b ? a : b);

    // Calculate dynamic Y-axis max and interval to prevent overlapping
    double chartMaxY;
    double interval;

    if (maxValue <= 0) {
      chartMaxY = 10;
      interval = 2;
    } else if (maxValue <= 50) {
      // For small values (0-50), use increments of 10
      chartMaxY = ((maxValue / 10).ceil() * 10).toDouble();
      interval = chartMaxY / 5;
    } else if (maxValue <= 100) {
      // For values 50-100, use increments of 20
      chartMaxY = ((maxValue / 20).ceil() * 20).toDouble();
      interval = chartMaxY / 5;
    } else if (maxValue <= 500) {
      // For values 100-500, use increments of 100
      chartMaxY = ((maxValue / 100).ceil() * 100).toDouble();
      interval = chartMaxY / 5;
    } else if (maxValue <= 1000) {
      // For values 500-1000, use increments of 200
      chartMaxY = ((maxValue / 200).ceil() * 200).toDouble();
      interval = chartMaxY / 5;
    } else {
      // For larger values, round to nearest significant figure
      final magnitude = (maxValue / 5).ceilToDouble();
      final powerOf10 = pow(10, (log(magnitude) / ln10).floor());
      interval = ((magnitude / powerOf10).ceil() * powerOf10).toDouble();
      chartMaxY = interval * 5;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: chartMaxY,
          barGroups: barData.sortedPeriods.asMap().entries.map((entry) {
            final index = entry.key;
            final period = entry.value;
            final value = barData.periodTotals[period] ?? 0;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: colorScheme.success,
                  width: 40,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  // Only show labels at intervals to avoid clutter
                  if ((value % interval).abs() > 0.01) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      _formatYAxisValue(value),
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= barData.sortedPeriods.length) {
                    return const SizedBox();
                  }
                  return Text(
                    barData.sortedPeriods[value.toInt()],
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.mutedForeground,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colorScheme.border.withValues(alpha: 0.3),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    ExpenseEntry expense,
    UserContact? contact, {
    required String currentUserId,
    required Map<String, String> accountLabelsById,
    required Map<String, RecurringTransaction> recurringTransactionsById,
    bool isLast = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayDateTime = composeTransactionDisplayDateTime(
      transactionDate: expense.date,
      createdAt: expense.createdAt,
      preferredTimezone: contact?.preferredTimezone,
    );

    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    final isYou = widget.householdId != null &&
        expense.userId != null &&
        expense.userId == currentUserId;

    final isSelected = _selectedIds.contains(expense.id);
    final recurringId = extractRecurringTransactionIdFromProjectedExpenseId(
      expense.id,
    );
    final projectedRecurringTransaction =
        recurringId == null ? null : recurringTransactionsById[recurringId];
    final isProjectedRecurring = projectedRecurringTransaction != null;
    final accountLabel =
        (expense.walletId != null && expense.walletId!.isNotEmpty)
            ? accountLabelsById[expense.walletId!] ?? expense.accountName
            : expense.accountName;

    return Slidable(
      key: ValueKey(expense.id),
      enabled: !_isSelectionMode && !isProjectedRecurring,
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _handleSingleDelete(expense),
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            icon: Icons.delete,
            spacing: 2,
            borderRadius: BorderRadius.zero,
          ),
        ],
      ),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent, // Background handled by container
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              if (isProjectedRecurring) return;
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(expense.id);
                } else {
                  _selectedIds.add(expense.id);
                }
              });
            } else {
              if (isProjectedRecurring) {
                _openRecurringTransactionEditor(projectedRecurringTransaction);
              } else {
                unawaited(
                  showUnifiedTransactionSheet(
                    context,
                    existingExpense: expense,
                    contact: contact,
                  ).then((_) => _refreshActiveFeed()),
                );
              }
            }
          },
          onLongPress: () {
            if (isProjectedRecurring) return;
            if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(expense.id);
                } else {
                  _selectedIds.add(expense.id);
                }
              });
              return;
            }

            setState(() {
              _isSelectionMode = true;
              _selectedIds.add(expense.id);
            });
          },
          child: Container(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: Row(
                    children: [
                      // Selection Checkbox
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isSelectionMode ? 32 : 0,
                        height: _isSelectionMode ? 56 : 0,
                        margin:
                            EdgeInsets.only(right: _isSelectionMode ? 12 : 0),
                        child: _isSelectionMode
                            ? Center(
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.outline
                                              .withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(Icons.check,
                                          size: 16,
                                          color: colorScheme.onPrimary)
                                      : null,
                                ),
                              )
                            : null,
                      ),
                      Expanded(
                        child: TransactionListTile(
                          onTap: null, // Tap handled by parent InkWell
                          category: expense.category ?? 'uncategorized',
                          title: getCategoryTranslation(
                              context, expense.category ?? 'uncategorized'),
                          description: expense.rawText,
                          date: displayDateTime,
                          amount: expense.amount,
                          currency: expense.currency ?? 'USD',
                          isIncome: isIncome,
                          showYouLabel: isYou,
                          showRecurringChip: isProjectedRecurring,
                          accountLabel: accountLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                // Inset Divider
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 56, // Indent 56px per spec
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    ColorScheme colorScheme,
    List<String> availableCategories,
  ) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: colorScheme.appBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.filterTransactions,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.foreground,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.foreground),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCategories.map((category) {
                      final isSelected = selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                          });
                          setModalState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.muted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.border,
                            ),
                          ),
                          child: Text(
                            category.toLowerCase() == 'all'
                                ? context.l10n.allCategories
                                : getCategoryTranslation(context, category),
                            style: TextStyle(
                              color: isSelected
                                  ? colorScheme.primaryForeground
                                  : colorScheme.foreground,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryAdaptiveButton(
                          onPressed: () {
                            setState(() {
                              selectedCategory = 'all';
                              searchQuery = '';
                              _debouncedSearchQuery = '';
                              _searchDebounce?.cancel();
                              _searchController.clear();
                              _selectedDateFilter = DateRangeFilter.last7Days;
                              _customStart = null;
                              _customEnd = null;
                            });
                            unawaited(_persistDateFilterPreference());
                            Navigator.pop(context);
                          },
                          child: Text(context.l10n.reset),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryAdaptiveButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.apply),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TransactionsFilterCacheKey {
  final String searchQuery;
  final String selectedCategory;
  final String selectedType;
  final String? selectedCurrency;
  final List<String>? selectedCurrencies;
  final DateRangeFilter selectedDateFilter;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? pinnedHouseholdId;
  final ActiveWalletType activeAccountType;
  final String? activeAccountHouseholdId;
  final String? selectedHouseholdId;
  final DateTime dayAnchor;

  const _TransactionsFilterCacheKey({
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedType,
    required this.selectedCurrency,
    required this.selectedCurrencies,
    required this.selectedDateFilter,
    required this.customStart,
    required this.customEnd,
    required this.pinnedHouseholdId,
    required this.activeAccountType,
    required this.activeAccountHouseholdId,
    required this.selectedHouseholdId,
    required this.dayAnchor,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _TransactionsFilterCacheKey &&
        searchQuery == other.searchQuery &&
        selectedCategory == other.selectedCategory &&
        selectedType == other.selectedType &&
        selectedCurrency == other.selectedCurrency &&
        _listEquals(selectedCurrencies, other.selectedCurrencies) &&
        selectedDateFilter == other.selectedDateFilter &&
        customStart == other.customStart &&
        customEnd == other.customEnd &&
        pinnedHouseholdId == other.pinnedHouseholdId &&
        activeAccountType == other.activeAccountType &&
        activeAccountHouseholdId == other.activeAccountHouseholdId &&
        selectedHouseholdId == other.selectedHouseholdId &&
        dayAnchor == other.dayAnchor;
  }

  @override
  int get hashCode => Object.hash(
        searchQuery,
        selectedCategory,
        selectedType,
        selectedCurrency,
        Object.hashAll(selectedCurrencies ?? const <String>[]),
        selectedDateFilter,
        customStart,
        customEnd,
        pinnedHouseholdId,
        activeAccountType,
        activeAccountHouseholdId,
        selectedHouseholdId,
        dayAnchor,
      );
}

bool _listEquals(List<String>? left, List<String>? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class _TransactionsDerivedCacheKey {
  final int baseExpensesSignature;
  final int projectedRecurringExpensesSignature;
  final _TransactionsFilterCacheKey filterCacheKey;

  const _TransactionsDerivedCacheKey({
    required this.baseExpensesSignature,
    required this.projectedRecurringExpensesSignature,
    required this.filterCacheKey,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is _TransactionsDerivedCacheKey &&
        baseExpensesSignature == other.baseExpensesSignature &&
        projectedRecurringExpensesSignature ==
            other.projectedRecurringExpensesSignature &&
        filterCacheKey == other.filterCacheKey;
  }

  @override
  int get hashCode => Object.hash(
        baseExpensesSignature,
        projectedRecurringExpensesSignature,
        filterCacheKey,
      );
}

class _ExpandablePageView extends StatefulWidget {
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final int itemCount;
  final List<double> pageHeights;
  final IndexedWidgetBuilder itemBuilder;

  const _ExpandablePageView({
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.itemCount,
    required this.pageHeights,
    required this.itemBuilder,
  });

  @override
  State<_ExpandablePageView> createState() => _ExpandablePageViewState();
}

class _ExpandablePageViewState extends State<_ExpandablePageView> {
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: SizedBox(
        height: widget.pageHeights[widget.currentPage],
        child: PageView.builder(
          controller: widget.controller,
          onPageChanged: widget.onPageChanged,
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }
}
