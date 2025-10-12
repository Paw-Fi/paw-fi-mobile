import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:rsupa/features/home/presentation/pages/home_page.dart';
import 'package:rsupa/core/core.dart';
import 'package:rsupa/features/auth/auth.dart';
import 'package:rsupa/core/theme/app_theme.dart';
import '../widgets/scenario_result_sheet.dart';

// ============================================================================
// ADVANCED ANALYTICS PAGE
// ============================================================================

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Scenario UI state
  final TextEditingController _scenarioQuestionController = TextEditingController();
  DateTime? _scenarioDate;
  bool _scenarioLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scenarioQuestionController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Analytics data refresh will be handled by analyticsProvider
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Insights',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.foreground,
                ),
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: colorScheme.foreground,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                labelPadding: EdgeInsets.zero,
                tabs: const [
                  Tab(text: 'Running'),
                  Tab(text: '30-Day'),
                  Tab(text: 'Long-Term'),
                  Tab(text: 'Scenario'),
                ],
              ),
            ),

            const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRunningBalanceTab(colorScheme, analyticsData),
                    _build30DayLookAheadTab(colorScheme, analyticsData),
                    _buildLongTermProjectionTab(colorScheme, analyticsData),
                    _buildScenarioPlanningTab(colorScheme, analyticsData),
                  ],
                ),
              ),
            ],
          ),
        ),
      
      ),
    );
  }

  Widget _buildRunningBalanceTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Running & Daily Balances',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.help_outline, size: 16, color: colorScheme.mutedForeground),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Budget vs Spent per day with cumulative running balance.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: _buildRunningBalanceChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
                ),
                const SizedBox(height: 16),
                _buildChartLegend(
                  colorScheme,
                  [
                    {'label': 'Running Balance', 'color': const Color(0xFF8B5CF6)},
                    {'label': 'Budget', 'color': const Color(0xFF3B82F6)},
                    {'label': 'Spent', 'color': const Color(0xFFEF4444)},
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build30DayLookAheadTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '30-Day Look-Ahead',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.help_outline, size: 16, color: colorScheme.mutedForeground),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Projected from trailing 30-day averages.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: _build30DayProjectionChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
                ),
                const SizedBox(height: 16),
                _buildChartLegend(
                  colorScheme,
                  [
                    {'label': 'Projected Spending', 'color': const Color(0xFF10B981)},
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongTermProjectionTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Long-Term Projection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.help_outline, size: 16, color: colorScheme.mutedForeground),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on historical averages; updates automatically with your data.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: _buildLongTermProjectionChart(colorScheme, analyticsData.expenses, analyticsData.budgets),
                ),
                const SizedBox(height: 16),
                _buildChartLegend(
                  colorScheme,
                  [
                    {'label': '18-Month Projection', 'color': const Color(0xFF10B981)},
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioPlanningTab(shadcnui.ColorScheme colorScheme, AnalyticsData analyticsData) {
    final bool isDark = colorScheme.background == AppTheme.darkBackground;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scenario Planning Input
          Container(
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scenario Planning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Test if you can afford a future expense based on projections.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                 const SizedBox(height: 4),
                Text(
                  'Eg: "Can I buy a \$1,200 laptop before 2025-12-31?"',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text('Can I', style: TextStyle(color: colorScheme.foreground, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _scenarioQuestionController,
                            decoration: InputDecoration(
                              hintText: '',
                              hintStyle: TextStyle(color: colorScheme.mutedForeground),
                              filled: true,
                              fillColor: isDark ? AppTheme.darkInputBg : AppTheme.lightInputBg,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colorScheme.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: colorScheme.primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: TextStyle(color: colorScheme.foreground),
                            keyboardType: TextInputType.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text('before', style: TextStyle(color: colorScheme.foreground, fontWeight: FontWeight.w600)),
                        ),
                        shadcnui.OutlineButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _scenarioDate ?? now,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365 * 2)),
                              helpText: 'Select target date',
                            );
                            if (picked != null) {
                              setState(() {
                                _scenarioDate = DateTime(picked.year, picked.month, picked.day);
                              });
                            }
                          },
                          child: Text(
                            _scenarioDate == null
                              ? 'Pick date'
                              : '${_scenarioDate!.year}-${_scenarioDate!.month.toString().padLeft(2, '0')}-${_scenarioDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: shadcnui.PrimaryButton(
                              onPressed: _scenarioLoading ? null : () async {
                                final q = _scenarioQuestionController.text.trim();
                                final d = _scenarioDate == null
                                    ? ''
                                    : '${_scenarioDate!.year}-${_scenarioDate!.month.toString().padLeft(2, '0')}-${_scenarioDate!.day.toString().padLeft(2, '0')}' ;
                                if (q.isEmpty || d.isEmpty) {
                                  _showToast('Please enter a question and pick a date');
                                  return;
                                }

                                setState(() { _scenarioLoading = true; });

                                // Show persistent loading overlay
                                final overlayEntry = OverlayEntry(
                                  builder: (context) => Material(
                                    color: Colors.black54,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: shadcnui.Theme.of(context).colorScheme.background,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const CircularProgressIndicator(),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Analyzing scenario...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: shadcnui.Theme.of(context).colorScheme.foreground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                                Overlay.of(context).insert(overlayEntry);

                                try {
                                  final user = ref.read(authProvider);
                                  final resp = await supabase.functions.invoke('ai-scenario-planner', body: {
                                    'question': 'Can I $q',
                                    'targetDate': d,
                                    'userId': user.uid,
                                  });

                                  // Remove loading overlay
                                  overlayEntry.remove();

                                  if (!mounted) return;

                                  if (resp.data == null) throw Exception('AI scenario case not found');
                                  final data = resp.data as Map<String, dynamic>;
                                  final advice = data['advice'] as String? ?? 'No advice returned';

                                  // Show result in bottom sheet
                                  showScenarioResultSheet(
                                    context,
                                    question: q,
                                    targetDate: d,
                                    advice: advice,
                                  );

                                  // Show success toast
                                  _showToast('Scenario analyzed successfully');
                                } catch (e) {
                                  // Remove loading overlay
                                  overlayEntry.remove();

                                  if (!mounted) return;

                                  _showToast('Scenario analysis failed: $e');
                                } finally {
                                  if (mounted) {
                                    setState(() { _scenarioLoading = false; });
                                  }
                                }
                              },
                              child: _scenarioLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Check'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Where the Money Went
          Container(
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.border, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Where the Money Went',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.help_outline, size: 16, color: colorScheme.mutedForeground),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Category totals for the selected range.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: _buildCategoryBarChart(colorScheme, analyticsData.expenses),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Chart builders with real data
  Widget _buildRunningBalanceChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
    // Group by date
    final Map<String, double> dailySpent = {};
    final Map<String, double> dailyBudget = {};
    
    for (final expense in expenses) {
      final dateKey = expense.date.toIso8601String().substring(0, 10);
      dailySpent[dateKey] = (dailySpent[dateKey] ?? 0) + expense.amount;
    }
    
    for (final budget in budgets) {
      final dateKey = budget.date.toIso8601String().substring(0, 10);
      dailyBudget[dateKey] = (dailyBudget[dateKey] ?? 0) + budget.amount;
    }
    
    final dates = {...dailySpent.keys, ...dailyBudget.keys}.toList()..sort();
    
    if (dates.isEmpty) {
      return Center(
        child: Text('No data available', style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }
    
    // Calculate running balance
    double runningBalance = 0;
    final spots = <FlSpot>[];
    final budgetSpots = <FlSpot>[];
    final spentSpots = <FlSpot>[];
    
    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final spent = dailySpent[date] ?? 0;
      final budget = dailyBudget[date] ?? 0;
      runningBalance += (budget - spent);
      
      spots.add(FlSpot(i.toDouble(), runningBalance));
      budgetSpots.add(FlSpot(i.toDouble(), budget));
      spentSpots.add(FlSpot(i.toDouble(), spent));
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: runningBalance.abs() / 4,
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
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: dates.length > 10 ? 5 : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= dates.length) return const SizedBox();
                final date = DateTime.parse(dates[value.toInt()]);
                return Text(
                  '${date.month}/${date.day}',
                  style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF8B5CF6), // Purple for running
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: budgetSpots,
            isCurved: true,
            color: const Color(0xFF3B82F6), // Blue for budget
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: spentSpots,
            isCurved: true,
            color: const Color(0xFFEF4444), // Red for spent
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _build30DayProjectionChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
    // Calculate 30-day average
    final avgDaily = expenses.isEmpty ? 0.0 : expenses.fold(0.0, (sum, e) => sum + e.amount) / 30;
    
    // Project next 30 days
    final projectionSpots = List.generate(30, (i) {
      return FlSpot(i.toDouble(), avgDaily * (i + 1));
    });
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  'Day ${value.toInt() + 1}',
                  style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: projectionSpots,
            isCurved: true,
            color: const Color(0xFF10B981),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withOpacity(0.2),
                  const Color(0xFF10B981).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongTermProjectionChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, List<DailyBudgetEntry> budgets) {
    // Project 18 months based on current average
    final avgMonthly = expenses.isEmpty ? 0.0 : expenses.fold(0.0, (sum, e) => sum + e.amount);
    
    final projectionSpots = List.generate(18, (i) {
      return FlSpot(i.toDouble(), avgMonthly * (i + 1));
    });
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (value, meta) {
                return Text(
                  'M${value.toInt() + 1}',
                  style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: projectionSpots,
            isCurved: true,
            color: const Color(0xFF10B981),
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBarChart(shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses) {
    // Group by category
    final Map<String, double> categoryTotals = {};
    for (final expense in expenses) {
      final cat = expense.category ?? 'uncategorized';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + expense.amount;
    }
    
    final categories = categoryTotals.keys.toList()..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));
    final maxValue = categoryTotals.values.isEmpty ? 100.0 : categoryTotals.values.reduce((a, b) => a > b ? a : b);
    
    if (categories.isEmpty) {
      return Center(
        child: Text('No data available', style: TextStyle(color: colorScheme.mutedForeground)),
      );
    }
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barGroups: categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final value = categoryTotals[category] ?? 0;
          final color = getCategoryColor(category);
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: value,
                color: color,
                width: 40,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= categories.length) return const SizedBox();
                return Text(
                  categories[value.toInt()],
                  style: TextStyle(fontSize: 10, color: colorScheme.mutedForeground),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  // Helper method to build chart legends
  Widget _buildChartLegend(shadcnui.ColorScheme colorScheme, List<Map<String, dynamic>> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: item['color'] as Color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item['label'] as String,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
