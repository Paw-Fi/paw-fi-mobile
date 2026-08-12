import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/widgets/animated_amount_text.dart';

class DatePeriodRingStatus {
  const DatePeriodRingStatus({
    required this.progress,
    required this.color,
    this.percentage,
    this.hasTransactions = false,
  });

  final double progress;
  final Color color;
  final int? percentage;
  final bool hasTransactions;
}

class _DatePeriodSnapScrollPhysics extends ScrollPhysics {
  const _DatePeriodSnapScrollPhysics({
    required this.pageExtent,
    required this.pageAnchorOffset,
    required this.minimumScrollOffset,
    required this.dragStartOffset,
    super.parent,
  });

  final double pageExtent;
  final double pageAnchorOffset;
  final double minimumScrollOffset;
  final double? Function() dragStartOffset;

  static const _pageChangeThreshold = 0.6;

  @override
  _DatePeriodSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _DatePeriodSnapScrollPhysics(
      pageExtent: pageExtent,
      pageAnchorOffset: pageAnchorOffset,
      minimumScrollOffset: minimumScrollOffset,
      dragStartOffset: dragStartOffset,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (!pageExtent.isFinite ||
        pageExtent <= 0 ||
        !position.pixels.isFinite ||
        !position.maxScrollExtent.isFinite) {
      return super.createBallisticSimulation(position, velocity);
    }
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final simulation = ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
    );
    final endPixels = simulation.x(double.infinity);
    final startOffset = dragStartOffset();
    final pageNumber = startOffset != null &&
            (endPixels - startOffset).abs() < pageExtent * _pageChangeThreshold
        ? ((startOffset - pageAnchorOffset) / pageExtent).roundToDouble()
        : ((endPixels - pageAnchorOffset) / pageExtent).roundToDouble();
    final targetPixels = pageAnchorOffset + pageNumber * pageExtent;

    final lowerBound = minimumScrollOffset < position.maxScrollExtent
        ? minimumScrollOffset
        : position.maxScrollExtent;
    final upperBound = minimumScrollOffset > position.maxScrollExtent
        ? minimumScrollOffset
        : position.maxScrollExtent;
    final clampedTarget = targetPixels.clamp(lowerBound, upperBound);

    if ((clampedTarget - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      clampedTarget,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < minimumScrollOffset && position.pixels >= minimumScrollOffset) {
      return value - minimumScrollOffset;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class DatePeriodSelector extends StatefulWidget {
  const DatePeriodSelector({
    super.key,
    required this.mode,
    required this.selectedDate,
    required this.now,
    required this.financialMonthStartDay,
    required this.onDateSelected,
    this.statusForPeriod,
    this.minimumAvailableDate,
    this.maximumAvailableDate,
    this.onVisiblePeriodsChanged,
    this.ringAnimationRevision = 0,
  });

  final HomePeriodMode mode;
  final DateTime selectedDate;
  final DateTime now;
  final int financialMonthStartDay;
  final ValueChanged<DateTime> onDateSelected;
  final DatePeriodRingStatus? Function(DateTime period)? statusForPeriod;
  final DateTime? minimumAvailableDate;
  final DateTime? maximumAvailableDate;
  final ValueChanged<List<DateTime>>? onVisiblePeriodsChanged;
  final int ringAnimationRevision;

  @override
  State<DatePeriodSelector> createState() => _DatePeriodSelectorState();
}

class _DatePeriodSelectorState extends State<DatePeriodSelector> {
  late final ScrollController _scrollController;
  late DateTime _anchorDate;
  double _itemExtent = 52;
  static const _selectedIndex = 5000;
  static const _pageAnchorIndex =
      4995; // selectedIndex - 5 (now is 6th item of page 0)
  static const _pageCount = 2; // Current page plus one future page.
  bool _hasInitialScrolled = false;
  List<DateTime>? _lastVisiblePeriods;
  double? _dragStartOffset;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _anchorDate = normalizeHomePeriodDate(widget.now);
  }

  @override
  void didUpdateWidget(covariant DatePeriodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.financialMonthStartDay != widget.financialMonthStartDay) {
      _anchorDate = normalizeHomePeriodDate(widget.now);
      _hasInitialScrolled = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToSelected(false));
    } else if (oldWidget.minimumAvailableDate != widget.minimumAvailableDate ||
        oldWidget.maximumAvailableDate != widget.maximumAvailableDate) {
      _lastVisiblePeriods = null;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToSelected(false));
    } else if (oldWidget.selectedDate != widget.selectedDate) {
      _ensureSelectedVisible();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _pageExtent => _itemExtent * 7.0;

  int get _minimumAvailableIndex {
    final minimum = widget.minimumAvailableDate;
    if (minimum == null) return 0;
    return _indexForDate(minimum).clamp(0, _selectedIndex);
  }

  int get _firstPageIndex {
    final minimumIndex = _minimumAvailableIndex;
    return minimumIndex > _pageAnchorIndex ? minimumIndex : _pageAnchorIndex;
  }

  int get _maximumAvailableIndex {
    final maximum = widget.maximumAvailableDate;
    if (maximum == null) return _firstPageIndex + _pageCount * 7 - 1;
    return _indexForDate(maximum).clamp(_firstPageIndex, _selectedIndex + 9999);
  }

  int get _itemCount => _maximumAvailableIndex + 1;
  double get _pageAnchorOffset => _firstPageIndex * _itemExtent;
  double get _minimumScrollOffset => _minimumAvailableIndex * _itemExtent;

  int _indexForDate(DateTime date) {
    if (widget.mode == HomePeriodMode.daily) {
      final days = normalizeHomePeriodDate(date)
          .difference(normalizeHomePeriodDate(_anchorDate))
          .inDays;
      return _selectedIndex + days;
    }
    final anchorCycle = financialCycleStartForDate(
      _anchorDate,
      startDay: widget.financialMonthStartDay,
    );
    final targetCycle = financialCycleStartForMonth(
      date,
      startDay: widget.financialMonthStartDay,
    );
    final cycles = _cyclesBetween(anchorCycle, targetCycle);
    return _selectedIndex + cycles;
  }

  int _cyclesBetween(DateTime fromCycle, DateTime toCycle) {
    var count = 0;
    var current = fromCycle;
    if (toCycle.isAfter(fromCycle)) {
      while (current.isBefore(toCycle)) {
        current = addFinancialCycles(current, 1,
            startDay: widget.financialMonthStartDay);
        count++;
      }
      return count;
    } else if (toCycle.isBefore(fromCycle)) {
      while (current.isAfter(toCycle)) {
        current = addFinancialCycles(current, -1,
            startDay: widget.financialMonthStartDay);
        count--;
      }
      return count;
    }
    return 0;
  }

  DateTime _periodAt(int index) {
    final offset = index - _selectedIndex;
    if (widget.mode == HomePeriodMode.daily) {
      return normalizeHomePeriodDate(_anchorDate).add(Duration(days: offset));
    }
    final anchorCycle = financialCycleStartForDate(
      _anchorDate,
      startDay: widget.financialMonthStartDay,
    );
    return addFinancialCycles(
      anchorCycle,
      offset,
      startDay: widget.financialMonthStartDay,
    );
  }

  int _pageNumberForDate(DateTime date) {
    final itemIndex = _indexForDate(date);
    return ((itemIndex - _firstPageIndex) / 7.0).floor();
  }

  void _ensureSelectedVisible() {
    if (!_scrollController.hasClients || _itemExtent <= 0) return;
    final currentOffset = _scrollController.offset;
    final currentPageNumber =
        ((currentOffset - _pageAnchorOffset) / _pageExtent).round();
    final targetPageNumber = _pageNumberForDate(widget.selectedDate);

    if (targetPageNumber != currentPageNumber) {
      final targetOffset =
          (_pageAnchorOffset + targetPageNumber * _pageExtent).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToSelected(bool animate) {
    if (!_scrollController.hasClients || _itemExtent <= 0) return;
    final targetPageNumber = _pageNumberForDate(widget.selectedDate);
    final targetOffset =
        (_pageAnchorOffset + targetPageNumber * _pageExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
    _notifyVisiblePeriods();
  }

  void _notifyVisiblePeriods() {
    if (!_scrollController.hasClients ||
        widget.onVisiblePeriodsChanged == null ||
        _itemExtent <= 0) {
      return;
    }
    final page =
        ((_scrollController.offset - _pageAnchorOffset) / _pageExtent).round();
    final firstIndex = _firstPageIndex + page * 7;
    final periods = List<DateTime>.generate(
      7,
      (offset) => _periodAt(firstIndex + offset),
      growable: false,
    );
    if (_samePeriods(_lastVisiblePeriods, periods)) return;
    _lastVisiblePeriods = periods;
    widget.onVisiblePeriodsChanged!(periods);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _itemExtent = constraints.maxWidth / 7.0;

        if (!_hasInitialScrolled) {
          _hasInitialScrolled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToSelected(false);
          });
        }

        return Semantics(
          container: true,
          child: SizedBox(
            // Keep dedicated space below each item so the selected period's
            // blurred shadow remains inside the horizontal viewport.
            height: 78,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _dragStartOffset = notification.metrics.pixels;
                  } else if (notification is ScrollEndNotification) {
                    _notifyVisiblePeriods();
                    _dragStartOffset = null;
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 8),
                  physics: _DatePeriodSnapScrollPhysics(
                    pageExtent: _pageExtent,
                    pageAnchorOffset: _pageAnchorOffset,
                    minimumScrollOffset: _minimumScrollOffset,
                    dragStartOffset: () => _dragStartOffset,
                  ),
                  itemExtent: _itemExtent,
                  itemCount: _itemCount,
                  itemBuilder: (context, index) {
                    final item = _periodAt(index);
                    return _PeriodItem(
                      date: item,
                      mode: widget.mode,
                      selected: _sameDay(item, widget.selectedDate),
                      today: _sameDay(item, widget.now),
                      enabled: _isAvailable(item) &&
                          isHomePeriodSelectable(
                            item,
                            mode: widget.mode,
                            now: widget.now,
                            financialMonthStartDay:
                                widget.financialMonthStartDay,
                          ),
                      status: widget.statusForPeriod?.call(item),
                      ringAnimationRevision: widget.ringAnimationRevision,
                      onTap: () => widget.onDateSelected(item),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isAvailable(DateTime period) {
    final minimum = widget.minimumAvailableDate;
    final maximum = widget.maximumAvailableDate;
    final cycle = widget.mode == HomePeriodMode.monthly
        ? financialCycleForMonth(
            period,
            startDay: widget.financialMonthStartDay,
          )
        : null;
    if (minimum != null) {
      final firstAvailableDay = normalizeHomePeriodDate(minimum);
      final isBeforeMinimum = widget.mode == HomePeriodMode.daily
          ? normalizeHomePeriodDate(period).isBefore(firstAvailableDay)
          : cycle!.end.isBefore(firstAvailableDay);
      if (isBeforeMinimum) return false;
    }
    if (maximum != null) {
      final lastAvailableDay = normalizeHomePeriodDate(maximum);
      final isAfterMaximum = widget.mode == HomePeriodMode.daily
          ? normalizeHomePeriodDate(period).isAfter(lastAvailableDay)
          : cycle!.start.isAfter(lastAvailableDay);
      if (isAfterMaximum) return false;
    }
    return true;
  }
}

class _PeriodItem extends StatelessWidget {
  const _PeriodItem({
    required this.date,
    required this.mode,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.status,
    required this.ringAnimationRevision,
    required this.onTap,
  });

  final DateTime date;
  final HomePeriodMode mode;
  final bool selected;
  final bool today;
  final bool enabled;
  final DatePeriodRingStatus? status;
  final int ringAnimationRevision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final localeStr = Localizations.localeOf(context).toString();
    final monthStr = DateFormat.MMM(localeStr).format(date);
    final weekdayStr = DateFormat.E(localeStr).format(date);
    final fullLabel = mode == HomePeriodMode.daily
        ? DateFormat.MMMd(localeStr).format(date)
        : monthStr;
    final semanticLabel = enabled ? fullLabel : '$fullLabel, unavailable';

    final textForeground =
        enabled ? colors.onSurface : colors.onSurface.withValues(alpha: 0.35);

    return Semantics(
      label: semanticLabel,
      button: enabled,
      enabled: enabled,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(16),
              splashColor: colors.primary.withValues(alpha: 0.08),
              highlightColor: colors.primary.withValues(alpha: 0.04),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.surface
                      : colors.surface.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mode == HomePeriodMode.daily ? weekdayStr : monthStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? colors.onSurface
                            : textForeground.withValues(
                                alpha: enabled ? 0.6 : 0.35),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildRing(colors),
                          _buildCircleContent(colors, textForeground),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleContent(ColorScheme colors, Color textForeground) {
    if (mode == HomePeriodMode.monthly && status != null) {
      final pct = status!.percentage ?? (status!.progress * 100).round();
      return SizedBox(
        width: 26,
        height: 26,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AnimatedAmountText(
                value: pct.toDouble(),
                symbol: '',
                suffix: '%',
                decimalDigits: 0,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: enabled ? status!.color : textForeground,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Text(
      '${date.day}',
      style: TextStyle(
        fontSize: 14,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: textForeground,
      ),
    );
  }

  Widget _buildRing(ColorScheme colors) {
    if (!enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: const SizedBox.expand(),
      );
    }

    if (mode == HomePeriodMode.monthly && status != null) {
      final backgroundColor = colors.outline.withValues(alpha: 0.48);
      return KeyedSubtree(
        key: ValueKey(ringAnimationRevision),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(
            begin: backgroundColor,
            end: status!.color,
          ),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, ringColor, _) => TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: status!.progress.clamp(0.0, 1.0),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              strokeCap: StrokeCap.round,
              color: ringColor,
              backgroundColor: backgroundColor,
            ),
          ),
        ),
      );
    }

    if (selected) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.onSurface,
            width: 2.0,
          ),
        ),
        child: const SizedBox.expand(),
      );
    }

    if (today) {
      final yellowColor = colors.warning;
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: yellowColor,
            width: 2.0,
          ),
        ),
        child: const SizedBox.expand(),
      );
    }

    final greenColor = colors.success;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: greenColor,
          width: 2.0,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

bool _samePeriods(List<DateTime>? first, List<DateTime> second) {
  if (first == null || first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (!_sameDay(first[index], second[index])) return false;
  }
  return true;
}
