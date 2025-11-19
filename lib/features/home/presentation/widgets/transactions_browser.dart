import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import '../widgets/unified_transaction_sheet.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

class TransactionsBrowser extends StatefulWidget {
  final List<ExpenseEntry> transactions;
  final String? selectedCurrency; // null = all currencies
  final Future<void> Function() onRefresh;
  final UserContact? contact;
  final VoidCallback? onBack;
  final String title;
  final bool showTypeChips;

  const TransactionsBrowser({
    super.key,
    required this.transactions,
    required this.selectedCurrency,
    required this.onRefresh,
    this.contact,
    this.onBack,
    this.title = 'Transactions',
    this.showTypeChips = true,
  });

  @override
  State<TransactionsBrowser> createState() => _TransactionsBrowserState();
}

class _TransactionsBrowserState extends State<TransactionsBrowser> {
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedPeriod = '1M';
  String _selectedType = 'all'; // all | expense | income
  int _currentChartIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  final PageController _chartPageController = PageController();

  @override
  void dispose() {
    _searchController.dispose();
    _chartPageController.dispose();
    super.dispose();
  }

  List<ExpenseEntry> get _filtered {
    var expenses = widget.transactions;

    // Currency
    final setCurrency = widget.selectedCurrency?.toUpperCase();
    if (setCurrency != null && setCurrency.isNotEmpty) {
      expenses = expenses.where((e) => (e.currency ?? '').toUpperCase() == setCurrency).toList();
    }

    // Period (relative)
    if (_selectedPeriod != 'All') {
      final now = DateTime.now();
      DateTime startDate;
      switch (_selectedPeriod) {
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
      expenses = expenses.where((e) => !e.date.isBefore(startDate)).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      expenses = expenses.where((e) {
        final cat = (e.category ?? 'uncategorized').toLowerCase();
        final amt = e.amount.toString();
        final raw = (e.rawText ?? '').toLowerCase();
        return cat.contains(q) || amt.contains(q) || raw.contains(q);
      }).toList();
    }

    // Category
    if (_selectedCategory != 'all') {
      expenses = expenses.where((e) => (e.category ?? 'uncategorized').toLowerCase() == _selectedCategory).toList();
    }

    // Type
    if (_selectedType != 'all') {
      expenses = expenses.where((e) => (e.type ?? 'expense').toLowerCase() == _selectedType).toList();
    }

    expenses.sort((a, b) => b.date.compareTo(a.date));
    return expenses;
  }

  List<String> get _categories {
    final cats = widget.transactions
        .map((e) => (e.category ?? 'uncategorized').toLowerCase())
        .toSet()
        .toList()
      ..sort();
    return ['all', ...cats];
  }

  String _periodLabel(BuildContext context) {
    switch (_selectedPeriod) {
      case '1W':
        return context.l10n.thisWeek;
      case '1M':
        return context.l10n.last30Days;
      case '6M':
        return context.l10n.last6Months;
      case '1Y':
        return context.l10n.thisYear;
      case 'All':
        return context.l10n.allTime;
      default:
        return context.l10n.last30Days;
    }
  }

  String get _chartInterval => getChartIntervalTypeFromPeriod(_selectedPeriod);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (widget.onBack != null) ...[
                        IconButton(
                          onPressed: widget.onBack,
                          icon: Icon(Icons.chevron_left, color: colorScheme.foreground, size: 28),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.foreground),
                            ),
                            Text(
                              '${_filtered.length} ${context.l10n.transactions.toLowerCase()}',
                              style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search + filter trigger
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: colorScheme.muted, borderRadius: BorderRadius.circular(12)),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: TextStyle(color: colorScheme.foreground),
                            decoration: InputDecoration(
                              hintText: context.l10n.search,
                              hintStyle: TextStyle(color: colorScheme.mutedForeground),
                              prefixIcon: Icon(Icons.search, color: colorScheme.mutedForeground),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.tune, color: _selectedCategory != 'all' ? colorScheme.primary : colorScheme.mutedForeground),
                        onPressed: () => _showFilterSheet(context, colorScheme),
                      )
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Period chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['1W','1M','6M','1Y','All'].map((period) {
                        final isSelected = _selectedPeriod == period;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedPeriod = period),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primary : colorScheme.muted,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _periodText(context, period),
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

              // Chart
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildChart(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Type chips
              if (widget.showTypeChips)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final type in const ['all','expense','income'])
                          ChoiceChip(
                            label: Text(type[0].toUpperCase() + type.substring(1)),
                            selected: _selectedType == type,
                            onSelected: (v) { if (v) setState(() => _selectedType = type); },
                          ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // List
              _filtered.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 64, color: colorScheme.mutedForeground),
                              const SizedBox(height: 16),
                              Text(context.l10n.noTransactionsFound, style: TextStyle(fontSize: 16, color: colorScheme.mutedForeground)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = _filtered[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildTransactionItem(context, expense),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _periodText(BuildContext context, String p) {
    switch (p) {
      case '1W': return context.l10n.thisWeek;
      case '1M': return context.l10n.last30Days;
      case '6M': return context.l10n.last6Months;
      case '1Y': return context.l10n.thisYear;
      case 'All': return context.l10n.allTime;
      default: return p;
    }
  }

  Widget _buildChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final spendOnly = _filtered.where((e) => (e.type ?? 'expense').toLowerCase() != 'income').toList();
    final totalSpent = spendOnly.fold(0.0, (sum, e) => sum + e.amount.abs());
    // Determine base currency for display: prefer selectedCurrency else dominant currency in filtered set
    String baseCurrency = (widget.selectedCurrency ?? '').toUpperCase();
    if (baseCurrency.isEmpty) {
      if (_filtered.isNotEmpty) {
        final counts = <String, int>{};
        for (final e in _filtered) {
          final code = (e.currency ?? 'USD').toUpperCase();
          counts[code] = (counts[code] ?? 0) + 1;
        }
        baseCurrency = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      } else {
        baseCurrency = 'USD';
      }
    }
    final displayText = formatCurrency(totalSpent, baseCurrency);

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
          Text(context.l10n.spent, style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground)),
          const SizedBox(height: 8),
          Text(displayText, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.foreground)),
          Text(_periodLabel(context), style: TextStyle(fontSize: 12, color: colorScheme.mutedForeground)),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.1,
            child: PageView(
              controller: _chartPageController,
              onPageChanged: (idx) => setState(() => _currentChartIndex = idx),
              children: [
                Padding(padding: const EdgeInsets.only(right: 8), child: _buildLineChart(context)),
                Padding(padding: const EdgeInsets.only(right: 8), child: _buildBarChart(context)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              return GestureDetector(
                onTap: () => _chartPageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                child: Container(
                  width: _currentChartIndex == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _currentChartIndex == index ? colorScheme.primary : colorScheme.muted,
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

  String _formatYAxisValue(double value) {
    if (value == 0) return '0';
    final absValue = value.abs();
    if (absValue >= 1000000) {
      final millions = value / 1000000;
      if (millions == millions.truncate()) return '${millions.truncate()}M';
      return '${millions.toStringAsFixed(1)}M';
    }
    if (absValue >= 1000) {
      final thousands = value / 1000;
      if (thousands == thousands.truncate()) return '${thousands.truncate()}k';
      return '${thousands.toStringAsFixed(1)}k';
    }
    if (value == value.truncate()) return value.truncate().toString();
    var s = value.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  Widget _buildLineChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final periodTotals = groupExpensesByInterval(_filtered, _chartInterval);
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
            getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.border.withValues(alpha: 0.3), strokeWidth: 1, dashArray: [5, 5]),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(_formatYAxisValue(value), style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= sortedDates.length) return const SizedBox();
                  final date = sortedDates[value.toInt()];
                  return Text(formatDateForInterval(date, _chartInterval), style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground));
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
                    return FlDotCirclePainter(radius: 7, color: AppTheme.danger, strokeWidth: 3, strokeColor: Colors.white);
                  }
                  return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [AppTheme.monekoPrimary.withValues(alpha: 0.28), AppTheme.monekoPrimary.withValues(alpha: 0.0)],
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

  Widget _buildBarChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barData = groupExpensesForBarChart(_filtered, _chartInterval);
    if (barData.periodTotals.isEmpty) {
      return Center(child: Text(context.l10n.noData, style: TextStyle(color: colorScheme.mutedForeground)));
    }
    final maxValue = barData.periodTotals.values.reduce((a, b) => a > b ? a : b);

    double chartMaxY;
    double interval;
    if (maxValue <= 0) {
      chartMaxY = 10; interval = 2;
    } else if (maxValue <= 50) {
      chartMaxY = ((maxValue / 10).ceil() * 10).toDouble(); interval = chartMaxY / 5;
    } else if (maxValue <= 100) {
      chartMaxY = ((maxValue / 20).ceil() * 20).toDouble(); interval = chartMaxY / 5;
    } else if (maxValue <= 500) {
      chartMaxY = ((maxValue / 100).ceil() * 100).toDouble(); interval = chartMaxY / 5;
    } else if (maxValue <= 1000) {
      chartMaxY = ((maxValue / 200).ceil() * 200).toDouble(); interval = chartMaxY / 5;
    } else {
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
                reservedSize: 50,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if ((value % interval).abs() > 0.01) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(_formatYAxisValue(value), style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground)),
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
                  return Text(barData.sortedPeriods[value.toInt()], style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground));
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.border.withValues(alpha: 0.3), strokeWidth: 1, dashArray: [5, 5]),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, ExpenseEntry expense) {
    final colorScheme = Theme.of(context).colorScheme;
    final category = expense.category ?? 'uncategorized';
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);
    final dateFormat = DateFormat('MMM d, yyyy');

    return GestureDetector(
      onTap: () => showUnifiedTransactionSheet(context, existingExpense: expense, contact: widget.contact),
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(categoryIcon, color: categoryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getCategoryTranslation(context, category),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.foreground),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(expense.date),
                    style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground),
                  ),
                ],
              ),
            ),
            Builder(builder: (_) {
            final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
              final sign = isIncome ? '+' : '-';
            final txt = '$sign${formatCurrency(expense.amount.abs(), expense.currency ?? (widget.selectedCurrency ?? 'USD'))}';
              return Text(
                txt,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF10B981) : colorScheme.foreground),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.appBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      Text(context.l10n.filterTransactions, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.foreground)),
                      IconButton(icon: Icon(Icons.close, color: colorScheme.foreground), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(context.l10n.category, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.foreground)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = category);
                          setModalState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? colorScheme.primary : colorScheme.muted,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.border),
                          ),
                          child: Text(
                            category.toLowerCase() == 'all' ? context.l10n.allCategories : getCategoryTranslation(context, category),
                            style: TextStyle(color: isSelected ? Colors.white : colorScheme.foreground, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: AdaptiveButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = 'all';
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            Navigator.pop(context);
                          },
                          style: AdaptiveButtonStyle.bordered,
                          label: context.l10n.reset,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AdaptiveButton(
                          onPressed: () => Navigator.pop(context),
                          label: context.l10n.apply,
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
