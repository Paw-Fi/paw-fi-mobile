import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Interactive spending card with swipeable chart and current point highlight
class SpendingCard extends StatefulWidget {
  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final UserContact? contact;
  final DateRangeFilter dateFilter;
  final String? selectedCurrency;

  const SpendingCard({
    super.key,
    required this.colorScheme,
    required this.expenses,
    required this.contact,
    required this.dateFilter,
    this.selectedCurrency,
  });

  @override
  State<SpendingCard> createState() => _SpendingCardState();
}

class _SpendingCardState extends State<SpendingCard> {
  int _currentWindowStart = 0;
  static const int _windowSize = 7; // Show 7 data points at a time
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final intervalType = getChartIntervalTypeFromFilter(widget.dateFilter);

    // Resolve date range for this card and filter expenses by date, currency, and type
    final range = getDateRangeFromFilter(
      widget.dateFilter,
      null,
      null,
    );
    final from = range['from']!;
    final to = range['to']!;
    final selectedCode = widget.selectedCurrency?.toUpperCase();

    final filteredExpenses = widget.expenses.where((expense) {
      final d =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
      final dateOk = !d.isBefore(from) && !d.isAfter(to);
      final rawCode = (expense.currency ?? '').trim().toUpperCase();
      final currencyOk =
          selectedCode == null || rawCode.isEmpty || rawCode == selectedCode;
      final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
      return dateOk && currencyOk && !isIncome;
    }).toList();

    // Group expenses by appropriate interval
    final periodTotals =
        groupExpensesByInterval(filteredExpenses, intervalType);
    final sortedDates = periodTotals.keys.toList()..sort();

    // Compute total spent robustly
    final bucketsTotal = periodTotals.values.fold(0.0, (a, b) => a + b);
    final directTotal = _getTotalSpent(filteredExpenses);
    final totalSpent = bucketsTotal > 0 ? bucketsTotal : directTotal;

    final displayText =
        formatCurrency(totalSpent, widget.selectedCurrency ?? 'USD');

    // If no data, synthesize a flat 0-line chart
    List<DateTime> effectiveDates = sortedDates;
    List<FlSpot> effectiveAllCumulativeData = const [];
    bool isFallback = false;

    if (sortedDates.isEmpty) {
      isFallback = true;
      final now = DateTime.now();
      effectiveDates = _generateFallbackDates(now, intervalType);
      effectiveAllCumulativeData =
          List.generate(effectiveDates.length, (i) => FlSpot(i.toDouble(), 0));
    }

    // Calculate cumulative spending
    double cumulative = 0;
    final allCumulativeData = isFallback
        ? effectiveAllCumulativeData
        : sortedDates.map((date) {
            cumulative += periodTotals[date] ?? 0;
            return FlSpot(
              sortedDates.indexOf(date).toDouble(),
              cumulative,
            );
          }).toList();

    // Ensure window doesn't exceed data bounds
    final sourceLength =
        isFallback ? effectiveDates.length : sortedDates.length;
    final maxWindowStart =
        (sourceLength - _windowSize).clamp(0, sourceLength - 1);
    _currentWindowStart = _currentWindowStart.clamp(0, maxWindowStart);

    // Get visible window of data
    final windowEnd =
        (_currentWindowStart + _windowSize).clamp(0, sourceLength);
    final visibleData =
        allCumulativeData.sublist(_currentWindowStart, windowEnd);
    final visibleDates = (isFallback ? effectiveDates : sortedDates)
        .sublist(_currentWindowStart, windowEnd);

    // Adjust spot x-values for visible window
    final adjustedVisibleData = visibleData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.y);
    }).toList();

    final maxY = allCumulativeData.isEmpty ? 100.0 : allCumulativeData.last.y;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          setState(() {
            if (details.primaryVelocity! < 0) {
              _currentWindowStart =
                  (_currentWindowStart + 1).clamp(0, maxWindowStart);
            } else if (details.primaryVelocity! > 0) {
              _currentWindowStart =
                  (_currentWindowStart - 1).clamp(0, maxWindowStart);
            }
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.colorScheme.outline.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dateFilter.getSpentLabel(context).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: widget.colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: widget.colorScheme.foreground,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                if (sortedDates.length > _windowSize)
                  _buildNavigationControls(maxWindowStart),
              ],
            ),

            const SizedBox(height: 32),

            // Chart Section
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= visibleDates.length ||
                              value.toInt() < 0) {
                            return const SizedBox();
                          }
                          final date = visibleDates[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              formatDateForInterval(date, intervalType),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: widget.colorScheme.mutedForeground,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) =>
                          widget.colorScheme.surface,
                      tooltipBorder: BorderSide(
                          color: widget.colorScheme.outline
                              .withValues(alpha: 0.1)),
                      tooltipRoundedRadius: 12,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          if (spot.spotIndex >= visibleDates.length) {
                            return null;
                          }
                          final date = visibleDates[spot.spotIndex];
                          final formattedDate =
                              formatDateForInterval(date, intervalType);
                          final amount = formatCurrency(
                              spot.y, widget.selectedCurrency ?? 'USD');
                          return LineTooltipItem(
                            '$formattedDate\n',
                            TextStyle(
                              color: widget.colorScheme.mutedForeground,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: amount,
                                style: TextStyle(
                                  color: widget.colorScheme.foreground,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      setState(() {
                        if (touchResponse == null ||
                            touchResponse.lineBarSpots == null) {
                          _touchedIndex = null;
                          return;
                        }
                        _touchedIndex =
                            touchResponse.lineBarSpots!.first.spotIndex;
                      });
                    },
                    handleBuiltInTouches: true,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: adjustedVisibleData,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: widget.colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          // Highlight the last point (current/most recent)
                          final isLastPoint =
                              index == adjustedVisibleData.length - 1 &&
                                  _currentWindowStart + index ==
                                      allCumulativeData.length - 1;

                          if (isLastPoint) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: widget.colorScheme.primary,
                              strokeWidth: 4,
                              strokeColor: widget.colorScheme.surface,
                            );
                          }
                          // Show dots on touch
                          if (_touchedIndex != null && index == _touchedIndex) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: widget.colorScheme.primary,
                              strokeWidth: 4,
                              strokeColor: widget.colorScheme.surface,
                            );
                          }
                          return FlDotCirclePainter(
                              radius: 0, color: Colors.transparent);
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.colorScheme.primary.withValues(alpha: 0.2),
                            widget.colorScheme.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  minY: 0,
                  maxY: maxY > 0 ? (maxY * 1.2).ceilToDouble() : 100,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationControls(int maxWindowStart) {
    return Container(
      decoration: BoxDecoration(
        color:
            widget.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onTap: _currentWindowStart > 0
                ? () => setState(() => _currentWindowStart =
                    (_currentWindowStart - 1).clamp(0, maxWindowStart))
                : null,
            colorScheme: widget.colorScheme,
          ),
          Container(
            width: 1,
            height: 16,
            color: widget.colorScheme.outline.withValues(alpha: 0.2),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onTap: _currentWindowStart < maxWindowStart
                ? () => setState(() => _currentWindowStart =
                    (_currentWindowStart + 1).clamp(0, maxWindowStart))
                : null,
            colorScheme: widget.colorScheme,
          ),
        ],
      ),
    );
  }

  List<DateTime> _generateFallbackDates(DateTime now, String intervalType) {
    switch (intervalType) {
      case 'hourly':
        return [0, 4, 8, 12, 16, 20]
            .map((h) => DateTime(now.year, now.month, now.day, h))
            .toList();
      case 'monthly':
        return [1, 3, 5, 7, 9, 11].map((m) => DateTime(now.year, m)).toList();
      case 'yearly':
        return List.generate(7, (i) => DateTime(now.year - (6 - i)));
      case 'daily':
      default:
        return List.generate(7, (i) {
          final d = now.subtract(Duration(days: 6 - i));
          return DateTime(d.year, d.month, d.day);
        });
    }
  }

  double _getTotalSpent(List<ExpenseEntry> expenses) {
    return expenses.fold(0.0, (sum, e) => sum + e.amount.abs());
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null
              ? colorScheme.onSurfaceVariant
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Legacy function wrapper for backward compatibility
Widget buildSpendingCard(
    BuildContext context,
    ColorScheme colorScheme,
    List<ExpenseEntry> expenses,
    UserContact? contact,
    DateRangeFilter dateFilter,
    {String? selectedCurrency}) {
  return SpendingCard(
    colorScheme: colorScheme,
    expenses: expenses,
    contact: contact,
    dateFilter: dateFilter,
    selectedCurrency: selectedCurrency,
  );
}
