import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/home/presentation/utils/transaction_grouping.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/features/home/presentation/utils/transaction_exporter.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import '../widgets/unified_transaction_sheet.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/domain/utils/recurring_projection.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';

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
  bool _isDeleting = false;

  final TextEditingController _searchController = TextEditingController();
  final PageController _chartPageController = PageController();

  @override
  void dispose() {
    _searchController.dispose();
    _chartPageController.dispose();
    super.dispose();
  }

  List<ExpenseEntry> _baseExpenses = const [];

  List<ExpenseEntry> get filteredExpenses {
    final filterState = ref.watch(homeFilterProvider);
    final preferredTimezone = ref
        .watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
    final userNow = effectiveNow(preferredTimezone: preferredTimezone);
    final householdScope = ref.watch(householdScopeProvider);
    // Exclude recurring templates from the transactions list.
    // Also copy to avoid mutating the base list when sorting.
    var expenses = _baseExpenses.where((e) => !e.isRecurring).toList();

    // Merge projected recurring entries
    final recurringState = ref.watch(
      recurringTransactionsProvider(widget.householdId),
    );
    recurringState.data.whenData((recurringTxs) {
      if (recurringTxs.isNotEmpty) {
        final projected = projectRecurringTransactionsAsExpenseEntries(
          recurringTransactions: recurringTxs,
          rangeStart: DateTime(2000),
          rangeEnd: userNow,
          selectedCurrency: filterState.selectedCurrency,
        );
        expenses = [...expenses, ...projected];
      }
    });

    // Filter by the currently selected account (personal vs private space vs shared space)
    // unless this page was explicitly opened for a specific householdId.
    if (widget.householdId == null) {
      expenses = expenses.where((e) {
        final hid = e.householdId;
        switch (householdScope.activeAccountType) {
          case ActiveAccountType.personal:
            return hid == null || hid.isEmpty;
          case ActiveAccountType.portfolio:
            final selectedId = householdScope.activeAccountHouseholdId;
            if (selectedId == null || selectedId.isEmpty) return false;
            return hid == selectedId;
          case ActiveAccountType.household:
            final selectedId = householdScope.selectedHouseholdId;
            if (selectedId == null || selectedId.isEmpty) return false;
            return hid == selectedId;
        }
      }).toList();
    }

    // Filter by currency if selected
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    if (selectedCurrency != null) {
      expenses = expenses.where((e) {
        return (e.currency?.toUpperCase() == selectedCurrency);
      }).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      expenses = expenses.where((e) {
        final category = (e.category ?? 'uncategorized').toLowerCase();
        final amount = (e.amount).toString();
        final rawText = (e.rawText ?? '').toLowerCase();
        final query = searchQuery.toLowerCase();

        return category.contains(query) ||
            amount.contains(query) ||
            rawText.contains(query);
      }).toList();
    }

    // Filter by category
    if (selectedCategory != 'all') {
      expenses = expenses.where((e) {
        final cat = (e.category ?? 'uncategorized').toLowerCase();
        return cat == selectedCategory.toLowerCase();
      }).toList();
    }

    // Filter by type
    if (selectedType != 'all') {
      expenses = expenses.where((e) {
        final t = (e.type ?? 'expense').toLowerCase();
        return t == selectedType;
      }).toList();
    }

    // Filter by date range
    if (_selectedDateFilter != DateRangeFilter.allTime) {
      final range = getDateRangeFromFilter(
        _selectedDateFilter,
        _customStart,
        _customEnd,
        now: userNow,
      );
      final from = range['from']!;
      final to = range['to']!;
      final toEndOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
      expenses = expenses.where((e) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        return !d.isBefore(from) && !d.isAfter(toEndOfDay);
      }).toList();
    }

    // Sort by date, newest first
    expenses.sort((a, b) => b.date.compareTo(a.date));

    return expenses;
  }

  List<String> get categories {
    final cats = _baseExpenses
        .where((e) => !e.isRecurring)
        .map((e) => (e.category ?? 'uncategorized').toLowerCase())
        .toSet()
        .toList()
      ..sort();
    return ['all', ...cats];
  }

  String _formatLocalizedCurrency(
    BuildContext context,
    double amount,
    String? currency,
  ) {
    final code = currency ?? 'USD';
    final normalized = double.parse(formatAmount(amount));
    final symbol = resolveCurrencySymbol(code);
    final localized = formatLocalizedNumber(context, normalized);
    return '$symbol$localized';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);

    // Resolve base expenses source (household-specific or global analytics)
    if (widget.householdId != null) {
      final expensesAsync = ref.watch(householdExpensesProvider(
        HouseholdExpensesParams(householdId: widget.householdId!),
      ));
      return expensesAsync.when(
        loading: () => Scaffold(
          backgroundColor: colorScheme.appBackground,
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Scaffold(
          backgroundColor: colorScheme.appBackground,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: colorScheme.destructive),
                  const SizedBox(height: 12),
                  Text(context.l10n.failedToLoadHouseholdTransactions,
                      style: TextStyle(color: colorScheme.destructive)),
                ],
              ),
            ),
          ),
        ),
        data: (list) {
          _baseExpenses = list;
          return _buildMainScaffold(colorScheme, null);
        },
      );
    } else {
      _baseExpenses = analyticsData.allExpenses;
    }

    return _buildMainScaffold(colorScheme, analyticsData.contact);
  }

  AdaptiveScaffold _buildMainScaffold(
      ColorScheme colorScheme, UserContact? contact) {
    final expensesToExport = filteredExpenses;

    final monthGroups = groupTransactionsByMonth(expensesToExport);
    final listItems = <_TransactionListItem>[];
    for (final month in monthGroups) {
      listItems.add(_TransactionListItem.monthHeader(month));
      final dayGroups = groupTransactionsByDay(month.expenses);
      for (final day in dayGroups) {
        listItems.add(_TransactionListItem.dayHeader(day));
        for (var i = 0; i < day.expenses.length; i++) {
          listItems.add(
            _TransactionListItem.entry(
              expense: day.expenses[i],
              isFirst: i == 0,
              isLast: i == day.expenses.length - 1,
            ),
          );
        }
      }
    }

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

      // Category Option
      AdaptivePopupMenuItem(
        label: selectedCategory == 'all'
            ? '${context.l10n.category}: ${context.l10n.all}'
            : '${context.l10n.category}: ${getCategoryTranslation(context, selectedCategory)}',
        icon: PlatformInfo.isIOS26OrHigher() ? 'tag' : Icons.category_outlined,
        value: 'category_filter',
      ),
    ];

    return AdaptiveScaffold(
      // Remove default AppBar to use SliverAppBar for custom actions logic
      // appBar: null,
      body: Material(
        color: colorScheme.appleGroupedBackground,
        child: RefreshIndicator(
          onRefresh: () async {
            if (widget.householdId != null) {
              ref.invalidate(householdExpensesProvider);
            } else {
              ref
                  .read(analyticsProvider.notifier)
                  .refresh(ref.read(authProvider).uid);
            }
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
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
                          _showFilterSheet(context, colorScheme);
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
                      onPressed: () => exportTransactionsAsExcelSheet(
                        context,
                        expensesToExport,
                        fileNamePrefix: widget.householdId != null
                            ? 'household_transactions'
                            : 'transactions',
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

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
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
                      onChanged: (value) => setState(() => searchQuery = value),
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
                  child: _buildChart(
                    colorScheme,
                    contact,
                    expensesToExport,
                  ),
                ),
              ),

              // Transactions List Groups
              listItems.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: colorScheme.mutedForeground,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.noTransactionsFound,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.mutedForeground,
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
                          final item = listItems[index];
                          if (item.isMonthHeader) {
                            return _buildMonthHeader(
                              context,
                              item.monthGroup!,
                              colorScheme,
                            );
                          }
                          if (item.isDayHeader) {
                            return _buildDayHeader(
                              context,
                              item.dayGroup!,
                              colorScheme,
                            );
                          }
                          return _buildTransactionRow(
                            context,
                            item.expense!,
                            contact,
                            colorScheme,
                            isFirst: item.isFirst,
                            isLast: item.isLast,
                          );
                        },
                        childCount: listItems.length,
                      ),
                    ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isDeleting ? null : _handleBulkDelete,
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              elevation: 4,
              icon: _isDeleting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: colorScheme.onError, strokeWidth: 2))
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(_isDeleting
                  ? 'Deleting...'
                  : '${context.l10n.delete} (${_selectedIds.length})'),
            )
          : null,
    );
  }

  Widget _buildMonthHeader(
    BuildContext context,
    MonthTransactionGroup group,
    ColorScheme colorScheme,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = formatMonthHeader(group.monthStart, locale: locale);

    final filterState = ref.watch(homeFilterProvider);
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    final currencies = group.expenses
        .map((e) => e.currency?.toUpperCase())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet();

    String? totalString;
    if (selectedCurrency != null) {
      final totalFormatted = formatLocalizedNumber(context, group.total.abs());
      final symbol = resolveCurrencySymbol(selectedCurrency);
      totalString = '${group.total < 0 ? '-' : ''}$symbol$totalFormatted';
    } else if (currencies.length == 1) {
      final currency = currencies.first;
      final totalFormatted = formatLocalizedNumber(context, group.total.abs());
      final symbol = resolveCurrencySymbol(currency);
      totalString = '${group.total < 0 ? '-' : ''}$symbol$totalFormatted';
    } else if (currencies.length > 1) {
      totalString = context.l10n.multipleCurrencies;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (totalString != null)
            Text(
              totalString,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.mutedForeground,
                letterSpacing: -0.2,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    DayTransactionGroup group,
    ColorScheme colorScheme,
  ) {
    final preferredTimezone = ref
        .watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
    final now = effectiveNow(preferredTimezone: preferredTimezone);
    final date = group.date;
    String dateLabel;

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      dateLabel = context.l10n.today;
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      dateLabel = context.l10n.yesterday;
    } else {
      final locale = Localizations.localeOf(context).toString();
      dateLabel = DateFormat('MMM d', locale).format(date);
    }

    final filterState = ref.watch(homeFilterProvider);
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    final currencies = group.expenses
        .map((e) => e.currency?.toUpperCase())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet();

    String? totalString;
    if (selectedCurrency != null) {
      final totalFormatted = formatLocalizedNumber(context, group.total.abs());
      final symbol = resolveCurrencySymbol(selectedCurrency);
      totalString = '${group.total < 0 ? '-' : ''}$symbol$totalFormatted';
    } else if (currencies.length == 1) {
      final currency = currencies.first;
      final totalFormatted = formatLocalizedNumber(context, group.total.abs());
      final symbol = resolveCurrencySymbol(currency);
      totalString = '${group.total < 0 ? '-' : ''}$symbol$totalFormatted';
    } else if (currencies.length > 1) {
      totalString = context.l10n.multipleCurrencies;
    }

    return Padding(
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
    required bool isFirst,
    required bool isLast,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(24) : Radius.zero,
      bottom: isLast ? const Radius.circular(24) : Radius.zero,
    );
    final shouldShadow = isFirst || isLast;

    return Container(
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

    setState(() => _isDeleting = true);
    final supabase = Supabase.instance.client;
    final user = ref.read(authProvider);

    int failCount = 0;
    int successCount = 0;

    try {
      final response = await supabase.functions.invoke(
        'delete-expense',
        body: {
          'userId': user.uid,
          'expenseIds': _selectedIds.join(','),
        },
      );

      final payload = response.data as Map<String, dynamic>?;
      if (payload == null || payload['success'] != true) {
        failCount = payload?['failedCount'] as int? ?? _selectedIds.length;
        successCount = payload?['deletedCount'] as int? ?? 0;
      } else {
        successCount = payload['deletedCount'] as int? ?? _selectedIds.length;
        failCount = payload['failedCount'] as int? ?? 0;
      }
    } catch (e) {
      failCount = _selectedIds.length;
    }

    if (widget.householdId != null) {
      ref.invalidate(householdExpensesProvider);
    } else {
      await ref.read(analyticsProvider.notifier).loadData(user.uid);
    }

    if (mounted) {
      setState(() {
        _isDeleting = false;
        _isSelectionMode = false;
        _selectedIds.clear();
      });

      if (failCount > 0) {
        AppToast.error(context,
            'Failed to delete $failCount items. Deleted $successCount successfully.',
            duration: const Duration(seconds: 4));
      } else {
        AppToast.success(context, 'Transactions deleted successfully',
            duration: const Duration(seconds: 3));
      }
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

    if (!mounted) return;

    // Using root navigator for blocking dialog to ensure it overlays everything
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final toastContext = rootNavigator
        .context; // Use this context for toasts if needed while dialog is up or after

    showBlockingProcessingDialog(
      context: toastContext,
      message: '${l10n.delete}...',
    );

    try {
      final user = ref.read(authProvider);
      final res = await Supabase.instance.client.functions
          .invoke('delete-expense', body: {
        'userId': user.uid,
        'expenseIds': expense.id,
      });

      if (rootNavigator.canPop()) rootNavigator.pop(); // Close blocking dialog

      if (res.data != null && (res.data['success'] == true)) {
        // Refresh data
        if (widget.householdId != null) {
          ref
              .read(cacheInvalidatorProvider)
              .invalidateHouseholdData(widget.householdId!);
          ref.invalidate(householdExpensesProvider);
        } else {
          await ref.read(analyticsProvider.notifier).loadData(user.uid);
        }

        if (mounted) {
          AppToast.success(context, l10n.transactionDeleted);
        }
      } else {
        final message = (res.data?['error'] as String?) ?? l10n.anErrorOccurred;
        if (mounted) AppToast.error(context, message);
      }
    } catch (e) {
      if (rootNavigator.canPop()) rootNavigator.pop(); // Close blocking dialog
      if (mounted) {
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(e));
      }
    }
  }

  Widget _buildDateFilterChips(ColorScheme colorScheme) {
    const filters = [
      DateRangeFilter.last7Days,
      DateRangeFilter.today,
      DateRangeFilter.yesterday,
      DateRangeFilter.thisWeek,
      DateRangeFilter.lastWeek,
      DateRangeFilter.thisMonth,
      DateRangeFilter.last30Days,
      DateRangeFilter.thisYear,
      DateRangeFilter.allTime,
      DateRangeFilter.custom,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
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
                }
              } else {
                setState(() {
                  _selectedDateFilter = filter;
                  _customStart = null;
                  _customEnd = null;
                });
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
        },
      ),
    );
  }

  Widget _buildChart(
    ColorScheme colorScheme,
    UserContact? contact,
    List<ExpenseEntry> expenses,
  ) {
    final spendOnly = expenses
        .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
        .toList();
    final totalSpent = spendOnly.fold(0.0, (sum, e) => sum + e.amount.abs());
    final filterState = ref.watch(homeFilterProvider);
    final periodLabel = context.l10n.allTime;
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    final currencies = spendOnly
        .map((e) => e.currency?.toUpperCase())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet();

    final displayText = selectedCurrency == null && currencies.length > 1
        ? context.l10n.multipleCurrencies
        : _formatLocalizedCurrency(
            context,
            totalSpent,
            filterState.selectedCurrency,
          );

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
          Text(
            context.l10n.spent,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          Text(
            periodLabel,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),
          // Chart with aspect ratio for proper sizing
          AspectRatio(
            aspectRatio: 1.1, // Slightly wider than tall for better mobile fit
            child: PageView(
              controller: _chartPageController,
              onPageChanged: (index) {
                setState(() {
                  currentChartIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildPieChart(colorScheme, expenses),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildLineChart(colorScheme, expenses),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildBarChart(colorScheme, expenses),
                ),
              ],
            ),
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
    List<ExpenseEntry> expenses,
  ) {
    final spendOnly = expenses
        .where((e) => (e.type ?? 'expense').toLowerCase() != 'income')
        .toList();

    final totalsByCategory = <String, double>{};
    for (final expense in spendOnly) {
      final category = (expense.category ?? 'uncategorized').toLowerCase();
      totalsByCategory[category] =
          (totalsByCategory[category] ?? 0) + expense.amount.abs();
    }

    if (totalsByCategory.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noData,
          style: TextStyle(color: colorScheme.mutedForeground),
        ),
      );
    }

    final sortedEntries = totalsByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(6).toList();
    final totalValue = topEntries.fold(0.0, (sum, item) => sum + item.value);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 48,
          sectionsSpace: 3,
          borderData: FlBorderData(show: false),
          sections: topEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final value = item.value;
            final percentage = totalValue == 0 ? 0 : (value / totalValue) * 100;

            return PieChartSectionData(
              value: value,
              color: AppTheme.pocketChartPalette[
                  index % AppTheme.pocketChartPalette.length],
              radius: 62,
              showTitle: percentage >= 8,
              title: '${percentage.toStringAsFixed(0)}%',
              titleStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
              borderSide: BorderSide(
                color: colorScheme.card,
                width: 2,
              ),
            );
          }).toList(),
        ),
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
    List<ExpenseEntry> expenses,
  ) {
    const chartIntervalType = 'yearly';
    final periodTotals = groupExpensesByInterval(expenses, chartIntervalType);
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
    List<ExpenseEntry> expenses,
  ) {
    const chartIntervalType = 'yearly';
    final barData = groupExpensesForBarChart(expenses, chartIntervalType);

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
      BuildContext context, ExpenseEntry expense, UserContact? contact,
      {bool isLast = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
    final currentUserId = ref.watch(authProvider).uid;
    final isYou = widget.householdId != null &&
        expense.userId != null &&
        expense.userId == currentUserId;

    final isSelected = _selectedIds.contains(expense.id);
    final isProjectedRecurring = expense.id.startsWith('recurring_');

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
              if (!isProjectedRecurring) {
                showUnifiedTransactionSheet(context,
                    existingExpense: expense, contact: contact);
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
                          date: expense.date,
                          amount: expense.amount,
                          currency: expense.currency ?? 'USD',
                          isIncome: isIncome,
                          showYouLabel: isYou,
                          showRecurringChip:
                              expense.id.startsWith('recurring_'),
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

  void _showFilterSheet(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
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
                    children: categories.map((category) {
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
                              _searchController.clear();
                              _selectedDateFilter = DateRangeFilter.last7Days;
                              _customStart = null;
                              _customEnd = null;
                            });
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

class _TransactionListItem {
  final MonthTransactionGroup? monthGroup;
  final DayTransactionGroup? dayGroup;
  final ExpenseEntry? expense;
  final bool isMonthHeader;
  final bool isDayHeader;
  final bool isFirst;
  final bool isLast;

  const _TransactionListItem._({
    this.monthGroup,
    this.dayGroup,
    this.expense,
    required this.isMonthHeader,
    required this.isDayHeader,
    required this.isFirst,
    required this.isLast,
  });

  factory _TransactionListItem.monthHeader(MonthTransactionGroup group) {
    return _TransactionListItem._(
      monthGroup: group,
      isMonthHeader: true,
      isDayHeader: false,
      isFirst: false,
      isLast: false,
    );
  }

  factory _TransactionListItem.dayHeader(DayTransactionGroup group) {
    return _TransactionListItem._(
      dayGroup: group,
      isMonthHeader: false,
      isDayHeader: true,
      isFirst: false,
      isLast: false,
    );
  }

  factory _TransactionListItem.entry({
    required ExpenseEntry expense,
    required bool isFirst,
    required bool isLast,
  }) {
    return _TransactionListItem._(
      expense: expense,
      isMonthHeader: false,
      isDayHeader: false,
      isFirst: isFirst,
      isLast: isLast,
    );
  }
}
