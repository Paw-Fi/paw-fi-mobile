import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:rsupa/features/auth/presentation/states/auth.dart';
import 'home_page.dart' show ExpenseEntry, UserContact, getCategoryColor, getCategoryIcon, analyticsProvider;
import '../widgets/transaction_detail_sheet.dart';

// ============================================================================
// TRANSACTIONS PAGE
// ============================================================================

enum ChartType { line, bar, pie }

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String searchQuery = '';
  String selectedCategory = 'all';
  String selectedPeriod = '1M';
  ChartType selectedChartType = ChartType.line;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseEntry> get filteredExpenses {
    final analyticsData = ref.watch(analyticsProvider);
    var expenses = analyticsData.expenses;

    // Filter by period
    final now = DateTime.now();
    DateTime startDate;
    switch (selectedPeriod) {
      case '1W':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '6M':
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case '1Y':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month - 1, now.day);
    }
    expenses = expenses.where((e) => e.date.isAfter(startDate)).toList();

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

    return expenses;
  }

  List<String> get categories {
    final analyticsData = ref.watch(analyticsProvider);
    final cats = analyticsData.expenses
        .map((e) => (e.category ?? 'uncategorized').toLowerCase())
        .toSet()
        .toList()
      ..sort();
    return ['all', ...cats];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(analyticsProvider.notifier).refresh(user.uid);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [                
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transactions',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                          Text(
                            '${filteredExpenses.length} transactions',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chart type toggle buttons
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildChartToggle(Icons.show_chart, selectedChartType == ChartType.line, colorScheme, () {
                            setState(() => selectedChartType = ChartType.line);
                          }),
                          _buildChartToggle(Icons.bar_chart, selectedChartType == ChartType.bar, colorScheme, () {
                            setState(() => selectedChartType = ChartType.bar);
                          }),
                          _buildChartToggle(Icons.pie_chart, selectedChartType == ChartType.pie, colorScheme, () {
                            setState(() => selectedChartType = ChartType.pie);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.muted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                            });
                          },
                          style: TextStyle(color: colorScheme.foreground),
                          decoration: InputDecoration(
                            hintText: 'Search',
                            hintStyle: TextStyle(color: colorScheme.mutedForeground),
                            prefixIcon: Icon(Icons.search, color: colorScheme.mutedForeground),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.tune, color: Colors.white),
                        onPressed: () => _showFilterSheet(context, colorScheme),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Period Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['1W', '1M', '6M', '1Y'].map((period) {
                      final isSelected = selectedPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPeriod = period;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? colorScheme.primary : colorScheme.muted,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              period,
                              style: TextStyle(
                                color: isSelected ? Colors.white : colorScheme.foreground,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Chart Display
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildChart(colorScheme, analyticsData.contact),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Category Filter Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _showFilterSheet(context, colorScheme),
                      child: Row(
                        children: [
                          Text(
                            'By Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.keyboard_arrow_down, color: colorScheme.foreground),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Transactions List
            filteredExpenses.isEmpty
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
                              'No transactions found',
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
                        final expense = filteredExpenses[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildTransactionItem(expense, colorScheme, analyticsData.contact),
                        );
                      },
                      childCount: filteredExpenses.length,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartToggle(IconData icon, bool isActive, shadcnui.ColorScheme colorScheme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.background : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? colorScheme.foreground : colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildChart(shadcnui.ColorScheme colorScheme, UserContact? contact) {
    final totalSpent = filteredExpenses.where((e) => e.amountCents > 0).fold(0.0, (sum, e) => sum + e.amount);
    final currencySymbol = _getCurrencySymbol(contact);

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spent',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$currencySymbol${totalSpent.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Icon(
                    Icons.arrow_upward,
                    color: const Color(0xFF10B981),
                    size: 16,
                  ),
                  Text(
                    ' €686',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            'This month',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: selectedChartType == ChartType.line
                ? _buildLineChart(colorScheme)
                : selectedChartType == ChartType.bar
                    ? _buildBarChart(colorScheme)
                    : _buildPieChart(colorScheme, totalSpent, currencySymbol),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(shadcnui.ColorScheme colorScheme) {
    // Group expenses by day
    final Map<DateTime, double> dailyTotals = {};
    for (final expense in filteredExpenses) {
      final dateOnly = DateTime(expense.date.year, expense.date.month, expense.date.day);
      dailyTotals[dateOnly] = (dailyTotals[dateOnly] ?? 0) + expense.amount;
    }

    final sortedDates = dailyTotals.keys.toList()..sort();
    if (sortedDates.isEmpty) {
      return Center(
        child: Text('No data', style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }

    // Calculate cumulative spending
    double cumulative = 0;
    final cumulativeData = sortedDates.map((date) {
      cumulative += dailyTotals[date] ?? 0;
      return FlSpot(
        sortedDates.indexOf(date).toDouble(),
        cumulative,
      );
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: cumulative > 0 ? cumulative / 4 : 100,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.border.withOpacity(0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${(value / 1000).toStringAsFixed(1)}k',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.mutedForeground,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: sortedDates.length > 10 ? 5 : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedDates.length) return const SizedBox();
                final date = sortedDates[value.toInt()];
                return Text(
                  date.day.toString(),
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
            color: const Color(0xFF10B981),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                if (index == cumulativeData.length - 1) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: const Color(0xFF10B981),
                    strokeWidth: 2,
                    strokeColor: colorScheme.background,
                  );
                }
                return FlDotCirclePainter(
                  radius: 0,
                  color: Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.3),
                  const Color(0xFF10B981).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minY: 0,
        maxY: cumulative > 0 ? (cumulative * 1.2).ceilToDouble() : 100,
      ),
    );
  }

  Widget _buildBarChart(shadcnui.ColorScheme colorScheme) {
    // Group expenses by week
    final Map<String, double> weeklyTotals = {};
    for (final expense in filteredExpenses) {
      final weekStart = expense.date.subtract(Duration(days: expense.date.weekday - 1));
      final weekKey = '${weekStart.day}-${weekStart.add(const Duration(days: 6)).day}';
      weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0) + expense.amount;
    }

    if (weeklyTotals.isEmpty) {
      return Center(
        child: Text('No data', style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }

    final sortedWeeks = weeklyTotals.keys.toList();
    final maxValue = weeklyTotals.values.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barGroups: sortedWeeks.asMap().entries.map((entry) {
          final index = entry.key;
          final week = entry.value;
          final value = weeklyTotals[week] ?? 0;
          
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${(value / 100).toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.mutedForeground,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedWeeks.length) return const SizedBox();
                return Text(
                  sortedWeeks[value.toInt()],
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
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.border.withOpacity(0.3),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPieChart(shadcnui.ColorScheme colorScheme, double totalSpent, String currencySymbol) {
    // Group expenses by category
    final Map<String, double> categoryTotals = {};
    for (final expense in filteredExpenses) {
      if (expense.amountCents > 0) {
        final cat = (expense.category ?? 'uncategorized').toLowerCase();
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount;
      }
    }

    if (categoryTotals.isEmpty) {
      return Center(
        child: Text('No data', style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Stack(
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 70,
            sections: sortedCategories.map((entry) {
              final category = entry.key;
              final amount = entry.value;
              final color = getCategoryColor(category);

              return PieChartSectionData(
                color: color,
                value: amount,
                title: '',
                radius: 40,
              );
            }).toList(),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Spent',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              ),
              Text(
                '$currencySymbol${totalSpent.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
              ),
              Text(
                'This month',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(ExpenseEntry expense, shadcnui.ColorScheme colorScheme, UserContact? contact) {
    final category = expense.category ?? 'uncategorized';
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);
    final currencySymbol = _getCurrencySymbol(contact);
    final dateFormat = DateFormat('MMM d, yyyy');

    return GestureDetector(
      onTap: () => showTransactionDetailSheet(context, expense, contact: contact),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.border, width: 1),
        ),
        child: Row(
          children: [
          // Category Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              categoryIcon,
              color: categoryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.substring(0, 1).toUpperCase() + category.substring(1),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(expense.date),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.mutedForeground,
                  ),
                ),
               
              ],
            ),
          ),
          // Amount
          Text(
            '-$currencySymbol${expense.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
        ],
      ),
    ),
    );
  }


  String _getCurrencySymbol(UserContact? contact) {
    final cur = contact?.preferredCurrency ?? 'USD';
    switch (cur.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'USD':
      default:
        return '\$';
    }
  }

  void _showFilterSheet(BuildContext context, shadcnui.ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.background,
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
                        'Filter Transactions',
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
                    'Category',
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? colorScheme.primary : colorScheme.muted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.border,
                            ),
                          ),
                          child: Text(
                            category.substring(0, 1).toUpperCase() + category.substring(1),
                            style: TextStyle(
                              color: isSelected ? Colors.white : colorScheme.foreground,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                        child: shadcnui.OutlineButton(
                          onPressed: () {
                            setState(() {
                              selectedCategory = 'all';
                              searchQuery = '';
                              _searchController.clear();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: shadcnui.PrimaryButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply'),
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
