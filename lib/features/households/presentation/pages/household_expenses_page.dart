import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:intl/intl.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';

/// Date filter options for household expenses
enum DateFilterOption {
  allTime,
  today,
  yesterday,
  thisMonth,
}

/// Full expense list page with filtering and search for a household
class HouseholdExpensesPage extends ConsumerStatefulWidget {
  final Household household;

  const HouseholdExpensesPage({
    super.key,
    required this.household,
  });

  @override
  ConsumerState<HouseholdExpensesPage> createState() => _HouseholdExpensesPageState();
}

class _HouseholdExpensesPageState extends ConsumerState<HouseholdExpensesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedMemberId;
  DateFilterOption _selectedDateFilter = DateFilterOption.allTime;
  final PageController _chartPageController = PageController();
  int _currentChartIndex = 0;
  
  // Pagination (for future enhancement)
  // final int _pageSize = 50;
  // int _currentPage = 1;
  
  @override
  void dispose() {
    _searchController.dispose();
    _chartPageController.dispose();
    super.dispose();
  }

  // Build personal-share list of expenses from split groups
  List<ExpenseEntry> _personalShareExpenses(
    List<ExpenseEntry> expenses,
    List<ExpenseSplitGroup> splits,
    String currentUserId,
  ) {
    if (expenses.isEmpty || splits.isEmpty) return const <ExpenseEntry>[];
    final byGroupId = {for (final g in splits) g.id: g};
    final result = <ExpenseEntry>[];
    for (final e in expenses) {
      final gid = e.splitGroupId;
      if (gid == null) continue;
      final group = byGroupId[gid];
      if (group == null) continue;
      final line = (group.splitLines ?? const <ExpenseSplitLine>[])
          .firstWhere((l) => l.userId == currentUserId, orElse: () => ExpenseSplitLine(
                id: '',
                splitGroupId: '',
                userId: '',
                isSettled: false,
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
              ));
      if (line.userId != currentUserId) continue;
      final int share = (line.amountCents ?? 0);
      final int shareClamped = share < 0 ? 0 : share;
      result.add(e.copyWith(amountCents: shareClamped));
    }
    return result;
  }

  List<ExpenseEntry> _filterExpenses(List<ExpenseEntry> expenses) {
    var filtered = expenses;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((expense) {
        final query = _searchQuery.toLowerCase();
        final matchesDescription = expense.rawText?.toLowerCase().contains(query) ?? false;
        final matchesCategory = expense.category?.toLowerCase().contains(query) ?? false;
        final matchesAmount = expense.amount.toString().contains(query);
        final matchesUserName = expense.userName?.toLowerCase().contains(query) ?? false;
        return matchesDescription || matchesCategory || matchesAmount || matchesUserName;
      }).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((e) => e.category == _selectedCategory).toList();
    }

    // Member filter
    if (_selectedMemberId != null) {
      filtered = filtered.where((e) => e.userId == _selectedMemberId).toList();
    }

    // Date filter
    if (_selectedDateFilter != DateFilterOption.allTime) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      filtered = filtered.where((expense) {
        final expenseDate = DateTime(expense.date.year, expense.date.month, expense.date.day);

        switch (_selectedDateFilter) {
          case DateFilterOption.today:
            return expenseDate.isAtSameMomentAs(today);
          case DateFilterOption.yesterday:
            final yesterday = today.subtract(const Duration(days: 1));
            return expenseDate.isAtSameMomentAs(yesterday);
          case DateFilterOption.thisMonth:
            return expenseDate.year == now.year && expenseDate.month == now.month;
          case DateFilterOption.allTime:
            return true;
        }
      }).toList();
    }

    return filtered;
  }


  Widget _buildPlatformDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
    required Widget child,
  }) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return GestureDetector(
        onTap: () {
          _showCupertinoDropdown<T>(
            value: value,
            items: items,
            onChanged: onChanged,
          );
        },
        child: child,
      );
    } else {
      // Material dropdown for Android and other platforms
      return DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const SizedBox.shrink(), // Hide default arrow
          selectedItemBuilder: (context) {
            // Return the child widget for selected item
            return items.map((item) {
              return child;
            }).toList();
          },
          isDense: true,
          style: const TextStyle(color: Colors.transparent), // Hide text
          dropdownColor: Colors.transparent,
          elevation: 0,
          underline: const SizedBox.shrink(),
        ),
      );
    }
  }

  void _showCupertinoDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required ValueChanged<T?> onChanged,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          padding: const EdgeInsets.only(top: 20.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    CupertinoButton(
                      child: const Text('Done'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: MediaQuery.of(context).platformBrightness,
                    ),
                    child: CupertinoPicker(
                      itemExtent: 40,
                      scrollController: FixedExtentScrollController(
                        initialItem: items.indexWhere((item) => item.value == value),
                      ),
                      onSelectedItemChanged: (int index) {
                        onChanged(items[index].value);
                      },
                      children: items.map((item) {
                        return Center(
                          child: item.child,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategory = null;
      _selectedMemberId = null;
      _selectedDateFilter = DateFilterOption.allTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    
    // Fetch all expenses (increase limit for full list)
    final expensesParams = HouseholdExpensesParams(
      householdId: widget.household.id,
      limit: 500, // Fetch more for filtering
    );
    final expensesAsync = ref.watch(householdExpensesProvider(expensesParams));
    final splitsAsync = ref.watch(
      householdSplitsProvider(
        HouseholdSplitsParams(householdId: widget.household.id),
      ),
    );

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.foreground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.expenses,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.household.name,
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar and filter on same row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Search bar takes available space
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.searchExpenses,
                      hintStyle: TextStyle(color: colorScheme.mutedForeground),
                      prefixIcon: Icon(Icons.search, color: colorScheme.mutedForeground),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: colorScheme.mutedForeground),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: colorScheme.muted.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: colorScheme.foreground),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Filter icon button
                _buildFiltersTrigger(colorScheme, expensesAsync),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Expense list
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.destructive,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.errorLoadingExpenses,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (expenses) {
                final filteredExpenses = _filterExpenses(expenses);
                final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                final splits = splitsAsync.asData?.value ?? const <ExpenseSplitGroup>[];
                final personalExpenses = currentUserId != null
                    ? _personalShareExpenses(filteredExpenses, splits, currentUserId)
                    : const <ExpenseEntry>[];

                if (filteredExpenses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            expenses.isEmpty ? context.l10n.noExpensesYet : context.l10n.noMatchingExpenses,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            expenses.isEmpty
                                ? context.l10n.startLoggingExpenses
                                : context.l10n.tryAdjustingFilters,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(householdExpensesProvider(expensesParams));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredExpenses.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 16),
                          child: _buildChart(colorScheme, filteredExpenses),
                        );
                      }
                      final expense = filteredExpenses[index - 1];
                      int? shareCents;
                      if (currentUserId != null) {
                        final group = splits.firstWhere(
                          (g) => g.id == expense.splitGroupId,
                          orElse: () => ExpenseSplitGroup(
                            id: '',
                            householdId: '',
                            expenseId: '',
                            payerUserId: '',
                            splitType: SplitType.equal,
                            currency: 'USD',
                            totalAmountCents: 0,
                            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                          ),
                        );
                        if (group.id.isNotEmpty) {
                          final line = (group.splitLines ?? const <ExpenseSplitLine>[]) 
                              .firstWhere((l) => l.userId == currentUserId, orElse: () => ExpenseSplitLine(
                                    id: '',
                                    splitGroupId: '',
                                    userId: '',
                                    isSettled: false,
                                    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                                    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
                                  ));
                          if (line.userId == currentUserId) {
                            final val = line.amountCents ?? 0;
                            shareCents = val < 0 ? 0 : val;
                          }
                        }
                      }
                      return _ExpenseListItem(
                        expense: expense,
                        colorScheme: colorScheme,
                        userShareCents: shareCents,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Modern filter trigger using a bottom sheet with shadcn_flutter buttons
  Widget _buildFiltersTrigger(
    shadcnui.ColorScheme colorScheme,
    AsyncValue<List<ExpenseEntry>> expensesAsync,
  ) {
    final active = _activeFiltersCount();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        shadcnui.OutlineButton(
          onPressed: () {
            final expenses = expensesAsync.asData?.value ?? const <ExpenseEntry>[];
            _showFiltersSheet(expenses, colorScheme);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, color: colorScheme.foreground, size: 18),
              if (active > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$active',
                    style: TextStyle(
                      color: colorScheme.primaryForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  int _activeFiltersCount() {
    int c = 0;
    if (_selectedDateFilter != DateFilterOption.allTime) c++;
    if (_selectedCategory != null) c++;
    if (_selectedMemberId != null) c++;
    return c;
  }

  void _showFiltersSheet(List<ExpenseEntry> expenses, shadcnui.ColorScheme colorScheme) {
    // Prepare options
    final categories = expenses
        .where((e) => (e.category != null && e.category!.isNotEmpty))
        .map((e) => e.category!.trim())
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final membersMap = <String, String>{};
    for (final e in expenses) {
      if (e.userId != null && e.userName != null && e.userName!.trim().isNotEmpty) {
        membersMap[e.userId!] = e.userName!.trim();
      }
    }
    final members = membersMap.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    // Local working copies
    String? localCategory = _selectedCategory;
    String? localMemberId = _selectedMemberId;
    DateFilterOption localDateFilter = _selectedDateFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                    const SizedBox(height: 20),

                    // Date filter
                    Text(
                      context.l10n.dateRange,
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
                      children: [
                        _buildSelectableChip(
                          label: context.l10n.allTime,
                          selected: localDateFilter == DateFilterOption.allTime,
                          onTap: () => setModalState(() => localDateFilter = DateFilterOption.allTime),
                          colorScheme: colorScheme,
                        ),
                        _buildSelectableChip(
                          label: context.l10n.today,
                          selected: localDateFilter == DateFilterOption.today,
                          onTap: () => setModalState(() => localDateFilter = DateFilterOption.today),
                          colorScheme: colorScheme,
                        ),
                        _buildSelectableChip(
                          label: context.l10n.yesterday,
                          selected: localDateFilter == DateFilterOption.yesterday,
                          onTap: () => setModalState(() => localDateFilter = DateFilterOption.yesterday),
                          colorScheme: colorScheme,
                        ),
                        _buildSelectableChip(
                          label: context.l10n.thisMonth,
                          selected: localDateFilter == DateFilterOption.thisMonth,
                          onTap: () => setModalState(() => localDateFilter = DateFilterOption.thisMonth),
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Category
                    if (categories.isNotEmpty) ...[
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
                        children: [
                          _buildSelectableChip(
                            label: context.l10n.allCategories,
                            selected: localCategory == null,
                            onTap: () => setModalState(() => localCategory = null),
                            colorScheme: colorScheme,
                          ),
                          ...categories.map((cat) {
                            final sel = localCategory == cat;
                            return _buildSelectableChip(
                              label: getCategoryTranslation(context, cat),
                              selected: sel,
                              onTap: () => setModalState(() => localCategory = cat),
                              colorScheme: colorScheme,
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Member
                    if (members.isNotEmpty) ...[
                      Text(
                        context.l10n.member,
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
                        children: [
                          _buildSelectableChip(
                            label: context.l10n.allMembers,
                            selected: localMemberId == null,
                            onTap: () => setModalState(() => localMemberId = null),
                            colorScheme: colorScheme,
                          ),
                          ...members.map((entry) {
                            final sel = localMemberId == entry.key;
                            return _buildSelectableChip(
                              label: entry.value,
                              selected: sel,
                              onTap: () => setModalState(() => localMemberId = entry.key),
                              colorScheme: colorScheme,
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: shadcnui.OutlineButton(
                            onPressed: () {
                              setModalState(() {
                                localCategory = null;
                                localMemberId = null;
                                localDateFilter = DateFilterOption.allTime;
                              });
                            },
                            child: Text(context.l10n.reset),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: shadcnui.PrimaryButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = localCategory;
                                _selectedMemberId = localMemberId;
                                _selectedDateFilter = localDateFilter;
                              });
                              Navigator.pop(context);
                            },
                            child: Text(context.l10n.apply),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Styled selectable chip used in the filter sheet
  Widget _buildSelectableChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required shadcnui.ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.muted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colorScheme.primary : colorScheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colorScheme.primaryForeground : colorScheme.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses) {
    // Handle multi-currency by picking the dominant currency for aggregation
    String baseCurrency = 'USD';
    if (expenses.isNotEmpty) {
      final counts = <String, int>{};
      for (final e in expenses) {
        final code = (e.currency ?? 'USD').toUpperCase();
        counts[code] = (counts[code] ?? 0) + 1;
      }
      baseCurrency = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    final chartExpenses = expenses.where((e) => (e.currency ?? 'USD').toUpperCase() == baseCurrency).toList();
    final totalSpent = chartExpenses.fold(0.0, (sum, e) => sum + e.amount.abs());
    final displayText = formatCurrency(totalSpent, baseCurrency);

    // Get period label based on selected date filter
    final periodLabel = switch (_selectedDateFilter) {
      DateFilterOption.today => context.l10n.today,
      DateFilterOption.yesterday => context.l10n.yesterday,
      DateFilterOption.thisMonth => context.l10n.thisMonth,
      DateFilterOption.allTime => context.l10n.allTime,
    };

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.spent,
            style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 8),
          Text(
            displayText,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.foreground),
          ),
          Text(
            periodLabel,
            style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.1,
            child: PageView(
              controller: _chartPageController,
              onPageChanged: (index) {
                setState(() => _currentChartIndex = index);
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildLineChart(colorScheme, chartExpenses),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildBarChart(colorScheme, chartExpenses),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              final isActive = _currentChartIndex == index;
              return GestureDetector(
                onTap: () {
                  _chartPageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: isActive ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive ? colorScheme.primary : colorScheme.muted,
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

  Widget _buildLineChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses) {
    const interval = 'daily';
    final periodTotals = groupExpensesByInterval(expenses, interval);
    final sortedDates = periodTotals.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return Center(child: Text(context.l10n.noData, style: TextStyle(color: colorScheme.mutedForeground)));
    }

    double cumulative = 0;
    final cumulativeData = sortedDates.map((date) {
      cumulative += periodTotals[date] ?? 0;
      return FlSpot(sortedDates.indexOf(date).toDouble(), cumulative);
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: cumulative > 0 ? cumulative / 4 : 100,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.border.withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: cumulative > 0 ? cumulative / 4 : 100,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                      style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: sortedDates.length > 7 ? 2 : 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= sortedDates.length) return const SizedBox();
                  final date = sortedDates[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(fontSize: 9, color: colorScheme.mutedForeground),
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
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(radius: 0, color: Colors.transparent);
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

  Widget _buildBarChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses) {
    const interval = 'daily';
    final barData = groupExpensesForBarChart(expenses, interval);

    if (barData.periodTotals.isEmpty) {
      return Center(child: Text(context.l10n.noData, style: TextStyle(color: colorScheme.mutedForeground)));
    }

    final maxValue = barData.periodTotals.values.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2,
          barGroups: barData.sortedPeriods.asMap().entries.map((entry) {
            final index = entry.key;
            final period = entry.value;
            final value = barData.periodTotals[period] ?? 0;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: const Color(0xFF10B981),
                  width: 40,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: maxValue / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                      style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: barData.sortedPeriods.length > 7 ? 2 : 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= barData.sortedPeriods.length) return const SizedBox();
                  final periodLabel = barData.sortedPeriods[value.toInt()];
                  final periodDate = barData.periodDates[periodLabel];
                  if (periodDate == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${periodDate.day}/${periodDate.month}',
                      style: TextStyle(fontSize: 9, color: colorScheme.mutedForeground),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.border.withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(shadcnui.ColorScheme colorScheme, AsyncValue<List<ExpenseEntry>> expensesAsync) {
    return expensesAsync.maybeWhen(
      data: (expenses) {
        final categories = expenses
            .where((e) => e.category != null)
            .map((e) => e.category!)
            .toSet()
            .toList()
          ..sort();

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildPlatformDropdown<String?>(
          value: _selectedCategory,
          items: [
            if (_selectedCategory != null)
              DropdownMenuItem<String?>(
                value: null,
                child: Text(context.l10n.allCategories),
              ),
            ...categories.map((category) => DropdownMenuItem<String?>(
                  value: category,
                  child: Text(category),
                )),
          ],
          onChanged: (category) {
            setState(() {
              _selectedCategory = category;
            });
          },
          child: _FilterChip(
            label: _selectedCategory ?? context.l10n.category,
            icon: Icons.category_outlined,
            isSelected: _selectedCategory != null,
            onTap: null, // Handled by platform dropdown
            colorScheme: colorScheme,
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildMemberFilter(shadcnui.ColorScheme colorScheme, AsyncValue<List<ExpenseEntry>> expensesAsync) {
    return expensesAsync.maybeWhen(
      data: (expenses) {
        final members = <String, String>{};
        for (var expense in expenses) {
          if (expense.userId != null && expense.userName != null) {
            members[expense.userId!] = expense.userName!;
          }
        }

        if (members.isEmpty) {
          return const SizedBox.shrink();
        }

        final sortedMembers = members.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value));

        return _buildPlatformDropdown<String?>(
          value: _selectedMemberId,
          items: [
            if (_selectedMemberId != null)
              DropdownMenuItem<String?>(
                value: null,
                child: Text(context.l10n.allMembers),
              ),
            ...sortedMembers.map((entry) => DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value),
                )),
          ],
          onChanged: (memberId) {
            setState(() {
              _selectedMemberId = memberId;
            });
          },
          child: _FilterChip(
            label: _selectedMemberId != null
                ? members[_selectedMemberId]!
                : context.l10n.member,
            icon: Icons.person_outline,
            isSelected: _selectedMemberId != null,
            onTap: null, // Handled by platform dropdown
            colorScheme: colorScheme,
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final shadcnui.ColorScheme colorScheme;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.muted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.mutedForeground,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expense list item widget
class _ExpenseListItem extends StatelessWidget {
  final ExpenseEntry expense;
  final shadcnui.ColorScheme colorScheme;
  final int? userShareCents;

  const _ExpenseListItem({
    required this.expense,
    required this.colorScheme,
    this.userShareCents,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MMM d').format(expense.date);
    final timeLabel = DateFormat('h:mm a').format(expense.createdAt);
    final title = (expense.rawText ?? expense.category ?? 'Expense').trim();
    final totalAmountText = formatCurrency(expense.amount.abs(), expense.currency ?? 'USD');
    final shareAmountText = userShareCents != null
        ? formatCurrency((userShareCents!.abs()) / 100.0, expense.currency ?? 'USD')
        : null;
    final userPrefix = (expense.userName != null && expense.userName!.isNotEmpty)
        ? '${expense.userName} • '
        : '';
    final metaText = '$userPrefix$dateLabel • $timeLabel';
    final category = expense.category ?? 'uncategorized';
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);
    
    return GestureDetector(
      onTap: () {
        // Open unified transaction sheet for viewing/editing
        showUnifiedTransactionSheet(
          context,
          existingExpense: expense,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(categoryIcon, color: categoryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metaText,
                          style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (expense.splitGroupId != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colorScheme.border),
                          ),
                          child: Text(
                            context.l10n.split,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.4,
                              color: colorScheme.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  shareAmountText ?? totalAmountText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (shareAmountText != null && expense.splitGroupId != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.muted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colorScheme.border.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      totalAmountText,
                      style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
