import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Interactive spending card with swipeable chart and current point highlight
class SpendingCard extends StatefulWidget {
  final shadcnui.ColorScheme colorScheme;
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
    return _buildCard();
  }

  Widget _buildCard() {
    final intervalType = getChartIntervalTypeFromFilter(widget.dateFilter);

    // Group expenses by appropriate interval
    final periodTotals = groupExpensesByInterval(widget.expenses, intervalType);
    final sortedDates = periodTotals.keys.toList()..sort();

    // Compute total spent robustly: prefer bucket sum, fallback to direct sum
    final bucketsTotal = periodTotals.values.fold(0.0, (a, b) => a + b);
    final directTotal = _getTotalSpent(widget.expenses);
    final totalSpent = bucketsTotal > 0 ? bucketsTotal : directTotal;

    // selectedCurrency is never null (defaults to USD)
    final displayText = formatCurrency(totalSpent, widget.selectedCurrency ?? 'USD');

    // If no data, synthesize a flat 0-line chart with sensible x-axis labels
    List<DateTime> effectiveDates = sortedDates;
    List<FlSpot> effectiveAllCumulativeData = const [];
    bool isFallback = false;
    if (sortedDates.isEmpty) {
      isFallback = true;
      final now = DateTime.now();
      switch (intervalType) {
        case 'hourly':
          effectiveDates = [0, 4, 8, 12, 16, 20]
              .map((h) => DateTime(now.year, now.month, now.day, h))
              .toList();
          break;
        case 'monthly':
          effectiveDates = [1, 3, 5, 7, 9, 11]
              .map((m) => DateTime(now.year, m))
              .toList();
          break;
        case 'yearly':
          effectiveDates = List.generate(7, (i) => DateTime(now.year - (6 - i)));
          break;
        case 'daily':
        default:
          effectiveDates = List.generate(7, (i) {
            final d = now.subtract(Duration(days: 6 - i));
            return DateTime(d.year, d.month, d.day);
          });
          break;
      }
      effectiveAllCumulativeData = List.generate(effectiveDates.length, (i) => FlSpot(i.toDouble(), 0));
    }

    // Calculate cumulative spending for all data points
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
    final sourceLength = isFallback ? effectiveDates.length : sortedDates.length;
    final maxWindowStart = (sourceLength - _windowSize).clamp(0, sourceLength - 1);
    _currentWindowStart = _currentWindowStart.clamp(0, maxWindowStart);

    // Get visible window of data
    final windowEnd = (_currentWindowStart + _windowSize).clamp(0, sourceLength);
    final visibleData = allCumulativeData.sublist(_currentWindowStart, windowEnd);
    final visibleDates = (isFallback ? effectiveDates : sortedDates).sublist(_currentWindowStart, windowEnd);

    // Adjust spot x-values for visible window
    final adjustedVisibleData = visibleData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.y);
    }).toList();

    final maxY = allCumulativeData.isEmpty ? 100.0 : allCumulativeData.last.y;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        setState(() {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < 0) {
              // Swipe left - show next period
              _currentWindowStart = (_currentWindowStart + 1).clamp(0, maxWindowStart);
            } else if (details.primaryVelocity! > 0) {
              // Swipe right - show previous period
              _currentWindowStart = (_currentWindowStart - 1).clamp(0, maxWindowStart);
            }
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.colorScheme.border, width: 1),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.dateFilter.getSpentLabel(context),
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: widget.colorScheme.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (sortedDates.length > _windowSize)
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          color: _currentWindowStart > 0
                              ? widget.colorScheme.foreground
                              : widget.colorScheme.mutedForeground.withValues(alpha: 0.3),
                        ),
                        onPressed: _currentWindowStart > 0
                            ? () {
                                setState(() {
                                  _currentWindowStart = (_currentWindowStart - 1).clamp(0, maxWindowStart);
                                });
                              }
                            : null,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: _currentWindowStart < maxWindowStart
                              ? widget.colorScheme.foreground
                              : widget.colorScheme.mutedForeground.withValues(alpha: 0.3),
                        ),
                        onPressed: _currentWindowStart < maxWindowStart
                            ? () {
                                setState(() {
                                  _currentWindowStart = (_currentWindowStart + 1).clamp(0, maxWindowStart);
                                });
                              }
                            : null,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 120,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY > 0 ? maxY / 4 : 100,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: widget.colorScheme.border.withValues(alpha: 0.3),
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
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= visibleDates.length || value.toInt() < 0) {
                              return const SizedBox();
                            }
                            final date = visibleDates[value.toInt()];
                            return Text(
                              formatDateForInterval(date, intervalType),
                              style: TextStyle(
                                fontSize: 10,
                                color: widget.colorScheme.mutedForeground,
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
                        getTooltipColor: (touchedSpot) => widget.colorScheme.popover,
                        tooltipBorder: BorderSide(color: widget.colorScheme.border),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            if (spot.spotIndex >= visibleDates.length) return null;
                            final date = visibleDates[spot.spotIndex];
                            final formattedDate = formatDateForInterval(date, intervalType);
                            final amount = formatCurrency(spot.y, widget.selectedCurrency ?? 'USD');
                            return LineTooltipItem(
                              '$formattedDate\n$amount',
                              TextStyle(
                                color: widget.colorScheme.foreground,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                        setState(() {
                          if (touchResponse == null || touchResponse.lineBarSpots == null) {
                            _touchedIndex = null;
                            return;
                          }
                          _touchedIndex = touchResponse.lineBarSpots!.first.spotIndex;
                        });
                      },
                      handleBuiltInTouches: true,
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: adjustedVisibleData,
                        isCurved: true,
                        color: AppTheme.monekoPrimary,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            // Highlight the last point (current/most recent) with red dot
                            if (index == adjustedVisibleData.length - 1 && _currentWindowStart + index == allCumulativeData.length - 1) {
                              return FlDotCirclePainter(
                                radius: 7,
                                color: AppTheme.danger,
                                strokeWidth: 3,
                                strokeColor: Colors.white,
                              );
                            }
                            // Show dots on touch
                            if (_touchedIndex != null && index == _touchedIndex) {
                              return FlDotCirclePainter(
                                radius: 6,
                                color: AppTheme.monekoPrimary,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            }
                            // Hide other dots
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
                    maxY: maxY > 0 ? (maxY * 1.25).ceilToDouble() : 100,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getTotalSpent(List<ExpenseEntry> expenses) {
    return widget.expenses.fold(0.0, (sum, e) => sum + e.amount.abs());
  }
}

/// Legacy function wrapper for backward compatibility
Widget buildSpendingCard(BuildContext context, shadcnui.ColorScheme colorScheme, List<ExpenseEntry> expenses, UserContact? contact, DateRangeFilter dateFilter, {String? selectedCurrency}) {
  return SpendingCard(
    colorScheme: colorScheme,
    expenses: expenses,
    contact: contact,
    dateFilter: dateFilter,
    selectedCurrency: selectedCurrency,
  );
}
