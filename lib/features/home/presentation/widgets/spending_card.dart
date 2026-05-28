import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/utils/chart_interval_utils.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/widgets/animated_amount_text.dart';

/// Interactive spending card with swipeable chart and current point highlight
void _homeSpendTrace(String message) {
  assert(() {
    debugPrint('🧾 [HomeSpendTrace] $message');
    return true;
  }());
}

double _traceExpenseTotal(Iterable<ExpenseEntry> entries) {
  return entries.fold<double>(0, (sum, entry) {
    final type = (entry.type ?? 'expense').toLowerCase();
    if (type == 'income') return sum;
    return sum + entry.amount.abs();
  });
}

String _traceAmount(num value) => value.toStringAsFixed(2);

class SpendingCard extends StatefulWidget {
  final ColorScheme colorScheme;
  final List<ExpenseEntry> expenses;
  final UserContact? contact;
  final DateRangeFilter dateFilter;
  final DateTime? referenceNow;
  final String? selectedCurrency;
  final List<String>? selectedCurrencies;
  final CurrencyRateTable? currencyRates;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? animationStorageKey;

  const SpendingCard({
    super.key,
    required this.colorScheme,
    required this.expenses,
    required this.contact,
    required this.dateFilter,
    this.referenceNow,
    this.selectedCurrency,
    this.selectedCurrencies,
    this.currencyRates,
    this.customStartDate,
    this.customEndDate,
    this.animationStorageKey,
  });

  @override
  State<SpendingCard> createState() => _SpendingCardState();
}

class _SpendingCardState extends State<SpendingCard> {
  int _currentWindowStart = 0;
  static const int _windowSize = 7; // Show 7 data points at a time
  static const Duration _entranceAnimationDuration =
      Duration(milliseconds: 800);
  int? _touchedIndex;
  bool _hasPlayedEntranceAnimation = false;
  String? _restoredAnimationStorageKey;
  List<ExpenseEntry>? _cachedExpensesIdentity;
  int? _cachedExpensesSignature;
  _SpendingCardCacheConfig? _cachedConfig;
  _SpendingCardDerivedData? _cachedDerivedData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreEntranceAnimationState();
  }

  @override
  void didUpdateWidget(covariant SpendingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationStorageKey != widget.animationStorageKey) {
      _restoreEntranceAnimationState(force: true);
    }
  }

  void _restoreEntranceAnimationState({bool force = false}) {
    final key = widget.animationStorageKey;
    if (!force && _restoredAnimationStorageKey == key) return;
    _restoredAnimationStorageKey = key;
    if (key == null) return;

    final hasPlayed = PageStorage.maybeOf(context)?.readState(
          context,
          identifier: key,
        ) ==
        true;
    _hasPlayedEntranceAnimation = hasPlayed;
  }

  void _markEntranceAnimationPlayed() {
    final key = widget.animationStorageKey;
    if (key != null) {
      PageStorage.maybeOf(context)?.writeState(
        context,
        true,
        identifier: key,
      );
    }
    if (!_hasPlayedEntranceAnimation && mounted) {
      setState(() => _hasPlayedEntranceAnimation = true);
    }
  }

  void _persistEntranceAnimationStarted() {
    final key = widget.animationStorageKey;
    if (key == null || _hasPlayedEntranceAnimation) return;
    PageStorage.maybeOf(context)?.writeState(
      context,
      true,
      identifier: key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final intervalType = getChartIntervalTypeFromFilter(widget.dateFilter);
    final now = widget.referenceNow ?? DateTime.now();
    final derivedData = _derivedDataFor(intervalType, now);
    final sortedDates = derivedData.sortedDates;
    final totalSpent = derivedData.totalSpent;
    _homeSpendTrace(
      'spending-card-render expenses=${widget.expenses.length} '
      'inputTotal=${_traceAmount(_traceExpenseTotal(widget.expenses))} '
      'derivedTotal=${_traceAmount(totalSpent)} '
      'filter=${widget.dateFilter.name} currency=${widget.selectedCurrency ?? '<none>'} '
      'signature=${_expenseListSignature(widget.expenses)}',
    );

    final currencyCode = widget.selectedCurrency ?? 'USD';
    final symbol = resolveCurrencySymbol(currencyCode);

    // If no data, synthesize a flat 0-line chart
    List<DateTime> effectiveDates = sortedDates;
    List<FlSpot> effectiveAllCumulativeData = const [];
    bool isFallback = false;

    if (sortedDates.isEmpty) {
      isFallback = true;
      effectiveDates = _generateFallbackDates(now, intervalType);
      effectiveAllCumulativeData =
          List.generate(effectiveDates.length, (i) => FlSpot(i.toDouble(), 0));
    }

    final allCumulativeData =
        isFallback ? effectiveAllCumulativeData : derivedData.allCumulativeData;

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
    final animationStart = _hasPlayedEntranceAnimation ? 1.0 : 0.0;
    final animationDuration = _hasPlayedEntranceAnimation
        ? Duration.zero
        : _entranceAnimationDuration;
    if (animationDuration != Duration.zero) {
      _persistEntranceAnimationStarted();
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.homeCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.colorScheme.homeCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.colorScheme.homeCardShadow,
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
                  RepaintBoundary(
                    child: AnimatedAmountText(
                      value: totalSpent,
                      symbol: symbol,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: widget.colorScheme.foreground,
                        height: 1.1,
                      ),
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
          RepaintBoundary(
            child: SizedBox(
              height: 160,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: animationStart, end: 1),
                duration: animationDuration,
                curve: Curves.easeOutCubic,
                onEnd: () {
                  if (!_hasPlayedEntranceAnimation) {
                    _markEntranceAnimationPlayed();
                  }
                },
                builder: (context, animationValue, child) {
                  // Interpolate spots from 0 to actual values
                  final animatedSpots = adjustedVisibleData.map((spot) {
                    return FlSpot(
                      spot.x,
                      spot.y * animationValue,
                    );
                  }).toList();

                  return LineChart(
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
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= visibleDates.length ||
                                  value.toInt() < 0) {
                                return const SizedBox();
                              }
                              final date = visibleDates[value.toInt()];
                              final locale = Localizations.localeOf(context);
                              final localeName = intlSafeLocaleName(locale);

                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: widget.dateFilter ==
                                        DateRangeFilter.thisMonth
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            DateFormat('d', localeName)
                                                .format(date),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: widget
                                                  .colorScheme.mutedForeground,
                                              height: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateFormat('MMM', localeName)
                                                .format(date),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: widget
                                                  .colorScheme.mutedForeground,
                                              height: 1.0,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        formatDateForInterval(
                                            date, intervalType),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: widget
                                              .colorScheme.mutedForeground,
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
                        touchSpotThreshold: 24,
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
                              final locale = Localizations.localeOf(context);
                              final localeName = intlSafeLocaleName(locale);
                              final formattedDate = widget.dateFilter ==
                                          DateRangeFilter.thisMonth &&
                                      intervalType == 'daily'
                                  ? DateFormat('d MMM', localeName).format(date)
                                  : formatDateForInterval(date, intervalType);
                              final currencyCode =
                                  widget.selectedCurrency ?? 'USD';
                              final symbol =
                                  resolveCurrencySymbol(currencyCode);
                              final localizedY =
                                  formatLocalizedNumber(context, spot.y);
                              final amount = '$symbol$localizedY';
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
                        touchCallback: (FlTouchEvent event,
                            LineTouchResponse? touchResponse) {
                          setState(() {
                            if (event is FlPanEndEvent ||
                                event is FlPanCancelEvent ||
                                event is FlTapUpEvent ||
                                event is FlTapCancelEvent ||
                                event is FlLongPressEnd) {
                              _touchedIndex = null;
                              return;
                            }
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
                          spots: animatedSpots,
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
                                  index == animatedSpots.length - 1 &&
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
                              if (_touchedIndex != null &&
                                  index == _touchedIndex) {
                                return FlDotCirclePainter(
                                  radius: 6,
                                  color: widget.colorScheme.primary,
                                  strokeWidth: 4,
                                  strokeColor: widget.colorScheme.surface,
                                );
                              }
                              return FlDotCirclePainter(
                                  radius: 0,
                                  color: widget.colorScheme.surface
                                      .withValues(alpha: 0.0));
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                widget.colorScheme.primary
                                    .withValues(alpha: 0.2 * animationValue),
                                widget.colorScheme.primary
                                    .withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: maxY > 0 ? (maxY * 1.2).ceilToDouble() : 100,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  _SpendingCardDerivedData _derivedDataFor(String intervalType, DateTime now) {
    final config = _SpendingCardCacheConfig.fromWidget(
      widget,
      intervalType: intervalType,
      now: now,
    );
    final cached = _cachedDerivedData;
    if (cached != null &&
        _cachedConfig == config &&
        identical(_cachedExpensesIdentity, widget.expenses)) {
      return cached;
    }

    final expensesSignature = _expenseListSignature(widget.expenses);
    if (cached != null &&
        _cachedConfig == config &&
        _cachedExpensesSignature == expensesSignature) {
      _cachedExpensesIdentity = widget.expenses;
      return cached;
    }

    final next = _computeDerivedData(intervalType, now);
    _cachedConfig = config;
    _cachedExpensesIdentity = widget.expenses;
    _cachedExpensesSignature = expensesSignature;
    _cachedDerivedData = next;
    return next;
  }

  _SpendingCardDerivedData _computeDerivedData(
    String intervalType,
    DateTime now,
  ) {
    final range = getDateRangeFromFilter(
      widget.dateFilter,
      widget.customStartDate,
      widget.customEndDate,
      now: now,
    );
    final from = range['from']!;
    final to = range['to']!;
    final selectedCode = widget.selectedCurrency?.trim().toUpperCase();
    final selectedCurrencies =
        _normalizedCurrencySet(widget.selectedCurrencies);
    final shouldConvertCurrencies =
        widget.currencyRates != null && (selectedCurrencies?.length ?? 0) > 1;
    final sourceExpenses = shouldConvertCurrencies
        ? convertTransactionsToCurrency(
            widget.expenses,
            targetCurrency: widget.selectedCurrency ?? 'USD',
            rates: widget.currencyRates!,
          )
        : widget.expenses;

    final filteredExpenses = <ExpenseEntry>[];
    double directTotal = 0;
    for (final expense in sourceExpenses) {
      final date =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
      final dateOk = !date.isBefore(from) && !date.isAfter(to);
      final rawCode = (expense.currency ?? '').trim().toUpperCase();
      final currencyOk = shouldConvertCurrencies ||
          selectedCode == null ||
          rawCode.isEmpty ||
          rawCode == selectedCode;
      final isIncome = (expense.type ?? 'expense').toLowerCase() == 'income';
      if (dateOk && currencyOk && !isIncome) {
        filteredExpenses.add(expense);
        directTotal += expense.amount.abs();
      }
    }

    final periodTotals = groupExpensesByInterval(
      filteredExpenses,
      intervalType,
      rangeStart: from,
      rangeEnd: to,
    );
    final sortedDates = periodTotals.keys.toList()..sort();
    final bucketsTotal = periodTotals.values.fold(0.0, (a, b) => a + b);
    final totalSpent = bucketsTotal > 0 ? bucketsTotal : directTotal;
    final allCumulativeData = <FlSpot>[];
    double cumulative = 0;
    for (var index = 0; index < sortedDates.length; index++) {
      final date = sortedDates[index];
      cumulative += periodTotals[date] ?? 0;
      allCumulativeData.add(FlSpot(index.toDouble(), cumulative));
    }

    return _SpendingCardDerivedData(
      sortedDates: sortedDates,
      allCumulativeData: allCumulativeData,
      totalSpent: totalSpent,
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
}

class _SpendingCardDerivedData {
  const _SpendingCardDerivedData({
    required this.sortedDates,
    required this.allCumulativeData,
    required this.totalSpent,
  });

  final List<DateTime> sortedDates;
  final List<FlSpot> allCumulativeData;
  final double totalSpent;
}

class _SpendingCardCacheConfig {
  const _SpendingCardCacheConfig({
    required this.intervalType,
    required this.dateFilter,
    required this.referenceNowKey,
    required this.nowDayKey,
    required this.selectedCurrency,
    required this.selectedCurrenciesKey,
    required this.currencyRatesKey,
    required this.customStartDateKey,
    required this.customEndDateKey,
  });

  factory _SpendingCardCacheConfig.fromWidget(
    SpendingCard widget, {
    required String intervalType,
    required DateTime now,
  }) {
    return _SpendingCardCacheConfig(
      intervalType: intervalType,
      dateFilter: widget.dateFilter,
      referenceNowKey: _dateMicrosKey(widget.referenceNow),
      nowDayKey: widget.referenceNow == null ? _dateDayKey(now) : null,
      selectedCurrency: widget.selectedCurrency?.trim().toUpperCase(),
      selectedCurrenciesKey: _normalizedCurrenciesKey(
        widget.selectedCurrencies,
      ),
      currencyRatesKey: _currencyRatesIdentityKey(widget.currencyRates),
      customStartDateKey: _dateMicrosKey(widget.customStartDate),
      customEndDateKey: _dateMicrosKey(widget.customEndDate),
    );
  }

  final String intervalType;
  final DateRangeFilter dateFilter;
  final int? referenceNowKey;
  final int? nowDayKey;
  final String? selectedCurrency;
  final String selectedCurrenciesKey;
  final int currencyRatesKey;
  final int? customStartDateKey;
  final int? customEndDateKey;

  @override
  bool operator ==(Object other) {
    return other is _SpendingCardCacheConfig &&
        other.intervalType == intervalType &&
        other.dateFilter == dateFilter &&
        other.referenceNowKey == referenceNowKey &&
        other.nowDayKey == nowDayKey &&
        other.selectedCurrency == selectedCurrency &&
        other.selectedCurrenciesKey == selectedCurrenciesKey &&
        other.currencyRatesKey == currencyRatesKey &&
        other.customStartDateKey == customStartDateKey &&
        other.customEndDateKey == customEndDateKey;
  }

  @override
  int get hashCode => Object.hash(
        intervalType,
        dateFilter,
        referenceNowKey,
        nowDayKey,
        selectedCurrency,
        selectedCurrenciesKey,
        currencyRatesKey,
        customStartDateKey,
        customEndDateKey,
      );
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

Widget buildSpendingCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> expenses,
  UserContact? contact,
  DateRangeFilter dateFilter, {
  Key? key,
  DateTime? referenceNow,
  String? selectedCurrency,
  List<String>? selectedCurrencies,
  CurrencyRateTable? currencyRates,
  DateTime? customStartDate,
  DateTime? customEndDate,
  String? animationStorageKey,
}) {
  return SpendingCard(
    key: key,
    colorScheme: colorScheme,
    expenses: expenses,
    contact: contact,
    dateFilter: dateFilter,
    referenceNow: referenceNow,
    selectedCurrency: selectedCurrency,
    selectedCurrencies: selectedCurrencies,
    currencyRates: currencyRates,
    customStartDate: customStartDate,
    customEndDate: customEndDate,
    animationStorageKey: animationStorageKey,
  );
}

Set<String>? _normalizedCurrencySet(List<String>? currencies) {
  final normalized = currencies
      ?.map((currency) => currency.trim().toUpperCase())
      .where((currency) => currency.isNotEmpty)
      .toSet();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _normalizedCurrenciesKey(List<String>? currencies) {
  final normalized = _normalizedCurrencySet(currencies)?.toList();
  normalized?.sort();
  return normalized?.join('|') ?? '';
}

int _expenseListSignature(List<ExpenseEntry> expenses) {
  var hash = expenses.length;
  for (final expense in expenses) {
    hash = Object.hash(
      hash,
      expense.date.millisecondsSinceEpoch,
      expense.amountCents,
      expense.currency,
      expense.type,
    );
  }
  return hash;
}

int _currencyRatesIdentityKey(CurrencyRateTable? table) {
  if (table == null) return 0;
  return Object.hash(
    identityHashCode(table),
    table.baseCurrency,
    table.fetchedAt?.millisecondsSinceEpoch,
    table.source,
    table.isStale,
  );
}

int? _dateMicrosKey(DateTime? value) => value?.microsecondsSinceEpoch;

int _dateDayKey(DateTime value) {
  return DateTime(value.year, value.month, value.day).millisecondsSinceEpoch;
}
