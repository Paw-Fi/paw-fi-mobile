import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:moneko/shared/widgets/user_avatar.dart';
import 'package:intl/intl.dart';

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
  DateTimeRange? _selectedDateRange;
  
  // Pagination (for future enhancement)
  // final int _pageSize = 50;
  // int _currentPage = 1;
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    // Date range filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((expense) {
        return expense.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
               expense.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategory = null;
      _selectedMemberId = null;
      _selectedDateRange = null;
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
              'Expenses',
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
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search expenses...',
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
                fillColor: colorScheme.muted.withOpacity(0.3),
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

          // Filters bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Date range filter
                  _FilterChip(
                    label: _selectedDateRange != null
                        ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}'
                        : 'Date Range',
                    icon: Icons.calendar_today,
                    isSelected: _selectedDateRange != null,
                    onTap: _selectDateRange,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 8),

                  // Category filter
                  _buildCategoryFilter(colorScheme, expensesAsync),
                  const SizedBox(width: 8),

                  // Member filter
                  _buildMemberFilter(colorScheme, expensesAsync),
                  const SizedBox(width: 8),

                  // Clear filters
                  if (_selectedCategory != null || 
                      _selectedMemberId != null || 
                      _selectedDateRange != null || 
                      _searchQuery.isNotEmpty)
                    _FilterChip(
                      label: 'Clear All',
                      icon: Icons.clear_all,
                      isSelected: false,
                      onTap: _clearFilters,
                      colorScheme: colorScheme,
                    ),
                ],
              ),
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
                        'Error Loading Expenses',
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
                            color: colorScheme.mutedForeground.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            expenses.isEmpty ? 'No Expenses Yet' : 'No Matching Expenses',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            expenses.isEmpty
                                ? 'Start logging expenses to see them here'
                                : 'Try adjusting your filters',
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
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      return _ExpenseListItem(
                        expense: filteredExpenses[index],
                        colorScheme: colorScheme,
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

        return PopupMenuButton<String>(
          onSelected: (category) {
            setState(() {
              _selectedCategory = category;
            });
          },
          itemBuilder: (context) => [
            if (_selectedCategory != null)
              const PopupMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
            ...categories.map((category) => PopupMenuItem(
                  value: category,
                  child: Text(category),
                )),
          ],
          child: _FilterChip(
            label: _selectedCategory ?? 'Category',
            icon: Icons.category_outlined,
            isSelected: _selectedCategory != null,
            onTap: null, // Handled by PopupMenuButton
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

        return PopupMenuButton<String>(
          onSelected: (memberId) {
            setState(() {
              _selectedMemberId = memberId;
            });
          },
          itemBuilder: (context) => [
            if (_selectedMemberId != null)
              const PopupMenuItem(
                value: null,
                child: Text('All Members'),
              ),
            ...sortedMembers.map((entry) => PopupMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                )),
          ],
          child: _FilterChip(
            label: _selectedMemberId != null
                ? members[_selectedMemberId]!
                : 'Member',
            icon: Icons.person_outline,
            isSelected: _selectedMemberId != null,
            onTap: null, // Handled by PopupMenuButton
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
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.muted.withOpacity(0.3),
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

  const _ExpenseListItem({
    required this.expense,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    
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
            color: colorScheme.border.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(expense.category),
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Expense details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description/Category
                  Text(
                    expense.rawText ?? expense.category ?? 'Expense',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Metadata row
                  Row(
                    children: [
                      // Who added it
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
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Date
                      Icon(Icons.calendar_today, size: 12, color: colorScheme.mutedForeground),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(expense.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.mutedForeground,
                        ),
                      ),

                      // Split badge
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
                              fontSize: 9,
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

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${expense.currency ?? 'USD'} ${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeFormat.format(expense.createdAt),
                  style: TextStyle(
                    fontSize: 11,
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

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.receipt_outlined;
    
    final categoryLower = category.toLowerCase();
    if (categoryLower.contains('food') || categoryLower.contains('restaurant')) {
      return Icons.restaurant_outlined;
    } else if (categoryLower.contains('transport') || categoryLower.contains('uber')) {
      return Icons.directions_car_outlined;
    } else if (categoryLower.contains('shop') || categoryLower.contains('retail')) {
      return Icons.shopping_bag_outlined;
    } else if (categoryLower.contains('entertainment') || categoryLower.contains('movie')) {
      return Icons.movie_outlined;
    } else if (categoryLower.contains('health') || categoryLower.contains('medical')) {
      return Icons.local_hospital_outlined;
    } else if (categoryLower.contains('utilities') || categoryLower.contains('bill')) {
      return Icons.receipt_long_outlined;
    }
    return Icons.receipt_outlined;
  }
}
