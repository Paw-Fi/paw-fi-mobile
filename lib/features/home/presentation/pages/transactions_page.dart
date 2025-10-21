import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:intl/intl.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import '../widgets/transaction_detail_sheet.dart';

// ============================================================================
// TRANSACTIONS PAGE
// ============================================================================

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String searchQuery = '';
  String selectedCategory = 'all';
  String selectedPeriod = '1M';
  int currentChartIndex = 0;
  
  final TextEditingController _searchController = TextEditingController();
  final PageController _chartPageController = PageController();

  @override
  void dispose() {
    _searchController.dispose();
    _chartPageController.dispose();
    super.dispose();
  }

  List<ExpenseEntry> get filteredExpenses {
    final analyticsData = ref.watch(analyticsProvider);
    final filterState = ref.watch(homeFilterProvider);
    var expenses = analyticsData.expenses;

    // Filter by currency if selected
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    if (selectedCurrency != null) {
      expenses = expenses.where((e) {
        return (e.currency?.toUpperCase() == selectedCurrency);
      }).toList();
    }

    // Filter by period
    if (selectedPeriod != 'All') {
      final now = DateTime.now();
      DateTime startDate;
      switch (selectedPeriod) {
        case '1W':
          startDate = DateTime(now.year, now.month, now.day - 7);
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
      
      // Filter expenses that are on or after the start date
      expenses = expenses.where((e) => !e.date.isBefore(startDate)).toList();
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

    // Sort by date, newest first
    expenses.sort((a, b) => b.date.compareTo(a.date));

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

  String get periodLabel {
    switch (selectedPeriod) {
      case '1W':
        return 'This week';
      case '1M':
        return 'This month';
      case '6M':
        return 'Last 6 months';
      case '1Y':
        return 'This year';
      case 'All':
        return 'All time';
      default:
        return 'This month';
    }
  }

  String get chartIntervalType => getChartIntervalTypeFromPeriod(selectedPeriod);

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
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.chevron_left,
                        color: colorScheme.foreground,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
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
                    children: ['1W', '1M', '6M', '1Y', 'All'].map((period) {
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

  Widget _buildChart(shadcnui.ColorScheme colorScheme, UserContact? contact) {
    final totalSpent = filteredExpenses.where((e) => e.amountCents > 0).fold(0.0, (sum, e) => sum + e.amount);
    final filterState = ref.watch(homeFilterProvider);
    
    // selectedCurrency is never null (defaults to USD)
    final displayText = formatCurrency(totalSpent, filterState.selectedCurrency ?? 'USD');

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
            'Spent',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 32,
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
                  child: _buildLineChart(colorScheme),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildBarChart(colorScheme),
                ),
                _buildPieChart(colorScheme, totalSpent, displayText),
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

  Widget _buildLineChart(shadcnui.ColorScheme colorScheme) {
    // Group expenses using utility function
    final periodTotals = groupExpensesByInterval(filteredExpenses, chartIntervalType);
    final sortedDates = periodTotals.keys.toList()..sort();
    if (sortedDates.isEmpty) {
      return Center(
        child: Text('No data', style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }

    // Calculate cumulative spending
    double cumulative = 0;
    final cumulativeData = sortedDates.map((date) {
      cumulative += periodTotals[date] ?? 0;
      return FlSpot(
        sortedDates.indexOf(date).toDouble(),
        cumulative,
      );
    }).toList();

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
                interval: 1, // Show all data points (already bucketed to 6-7 points)
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= sortedDates.length) return const SizedBox();
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
                    const Color(0xFF10B981).withValues(alpha: 0.3),
                    const Color(0xFF10B981).withValues(alpha: 0.0),
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

  Widget _buildBarChart(shadcnui.ColorScheme colorScheme) {
    // Group expenses using utility function
    final barData = groupExpensesForBarChart(filteredExpenses, chartIntervalType);

    if (barData.periodTotals.isEmpty) {
      return Center(
        child: Text('No data', style: TextStyle(color: colorScheme.mutedForeground)),
      );
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  formatAmount(value / 100),
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
                if (value.toInt() >= barData.sortedPeriods.length) return const SizedBox();
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
          horizontalInterval: maxValue / 4,
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

  Widget _buildPieChart(shadcnui.ColorScheme colorScheme, double totalSpent, String displayText) {
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
              color: categoryColor.withValues(alpha: 0.2),
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
            '-${formatCurrency(expense.amount, expense.currency)}',
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
