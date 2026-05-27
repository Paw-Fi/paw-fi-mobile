import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

const String amountAnimationTraceTag = '[AmountAnimationTrace]';

bool get amountAnimationTraceEnabled => kDebugMode;

void debugAmountAnimationTrace(String event, Map<String, Object?> fields) {
  if (!amountAnimationTraceEnabled) return;
  final details = fields.entries
      .map((entry) => '${entry.key}=${_formatTraceValue(entry.value)}')
      .join(' ');
  debugPrint('$amountAnimationTraceTag event=$event $details');
}

class AnimatedAmountText extends StatefulWidget {
  const AnimatedAmountText({
    super.key,
    required this.value,
    required this.symbol,
    required this.style,
    this.isNegative = false,
    this.duration = const Duration(milliseconds: 800),
    this.traceLabel = 'amount',
  });

  final double value;
  final String symbol;
  final TextStyle style;
  final bool isNegative;
  final Duration duration;
  final String traceLabel;

  @override
  State<AnimatedAmountText> createState() => _AnimatedAmountTextState();
}

class _AnimatedAmountTextState extends State<AnimatedAmountText> {
  late double _begin;
  late double _end;
  bool _animate = false;
  late final int _traceStateId;

  @override
  void initState() {
    super.initState();
    _traceStateId = identityHashCode(this);
    _begin = _displayAmount(widget.value);
    _end = _begin;
    debugAmountAnimationTrace(
        'AnimatedAmountText.initState',
        _traceFields(
          rawValue: widget.value,
          displayValue: _end,
          displayCents: _displayCents(_end),
          animate: _animate,
        ));
  }

  @override
  void didUpdateWidget(covariant AnimatedAmountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _displayAmount(widget.value);
    final previous = _end;
    final sameDisplay = _displayCents(previous) == _displayCents(next);
    final sameSymbol = oldWidget.symbol == widget.symbol;
    final sameSign = oldWidget.isNegative == widget.isNegative;

    if (sameDisplay && sameSymbol && sameSign) {
      _begin = next;
      _end = next;
      _animate = false;
      debugAmountAnimationTrace(
        'AnimatedAmountText.didUpdateWidget.noAnimation',
        _traceFields(
          rawValue: widget.value,
          oldRawValue: oldWidget.value,
          previousDisplayValue: previous,
          displayValue: next,
          previousDisplayCents: _displayCents(previous),
          displayCents: _displayCents(next),
          sameDisplay: sameDisplay,
          sameSymbol: sameSymbol,
          sameSign: sameSign,
          animate: _animate,
        ),
      );
      return;
    }

    _begin = previous;
    _end = next;
    _animate = true;
    debugAmountAnimationTrace(
      'AnimatedAmountText.didUpdateWidget.animate',
      _traceFields(
        rawValue: widget.value,
        oldRawValue: oldWidget.value,
        previousDisplayValue: previous,
        displayValue: next,
        previousDisplayCents: _displayCents(previous),
        displayCents: _displayCents(next),
        sameDisplay: sameDisplay,
        sameSymbol: sameSymbol,
        sameSign: sameSign,
        animate: _animate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugAmountAnimationTrace(
        'AnimatedAmountText.build',
        _traceFields(
          rawValue: widget.value,
          displayValue: _end,
          begin: _begin,
          end: _end,
          displayCents: _displayCents(_end),
          animate: _animate,
          durationMs:
              (_animate ? widget.duration : Duration.zero).inMilliseconds,
        ));
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _animate ? _begin : _end,
        end: _end,
      ),
      duration: _animate ? widget.duration : Duration.zero,
      curve: Curves.easeOutCubic,
      onEnd: () {
        debugAmountAnimationTrace(
            'AnimatedAmountText.onEnd',
            _traceFields(
              rawValue: widget.value,
              displayValue: _end,
              begin: _begin,
              end: _end,
              displayCents: _displayCents(_end),
              animate: _animate,
              mounted: mounted,
            ));
        if (_animate && mounted) {
          setState(() => _animate = false);
        }
      },
      builder: (context, value, child) {
        return Text(
          _formatAmount(context, value),
          style: widget.style,
        );
      },
    );
  }

  @override
  void dispose() {
    debugAmountAnimationTrace(
        'AnimatedAmountText.dispose',
        _traceFields(
          rawValue: widget.value,
          displayValue: _end,
          begin: _begin,
          end: _end,
          displayCents: _displayCents(_end),
          animate: _animate,
        ));
    super.dispose();
  }

  String _formatAmount(BuildContext context, double value) {
    final normalized = double.parse(formatAmount(value));
    final formatted = formatLocalizedNumber(context, normalized);
    final prefix = widget.isNegative ? '-' : '';
    return '$prefix${widget.symbol}$formatted';
  }

  Map<String, Object?> _traceFields({
    required double rawValue,
    double? oldRawValue,
    double? previousDisplayValue,
    required double displayValue,
    int? previousDisplayCents,
    required int displayCents,
    double? begin,
    double? end,
    bool? sameDisplay,
    bool? sameSymbol,
    bool? sameSign,
    required bool animate,
    int? durationMs,
    bool? mounted,
  }) {
    return {
      'label': widget.traceLabel,
      'stateId': _traceStateId,
      'widgetKey': widget.key,
      'rawValue': rawValue,
      if (oldRawValue != null) 'oldRawValue': oldRawValue,
      if (previousDisplayValue != null)
        'previousDisplayValue': previousDisplayValue,
      'displayValue': displayValue,
      if (previousDisplayCents != null)
        'previousDisplayCents': previousDisplayCents,
      'displayCents': displayCents,
      if (begin != null) 'begin': begin,
      if (end != null) 'end': end,
      'symbol': widget.symbol,
      'isNegative': widget.isNegative,
      if (sameDisplay != null) 'sameDisplay': sameDisplay,
      if (sameSymbol != null) 'sameSymbol': sameSymbol,
      if (sameSign != null) 'sameSign': sameSign,
      'animate': animate,
      if (durationMs != null) 'durationMs': durationMs,
      if (mounted != null) 'mounted': mounted,
    };
  }
}

double _displayAmount(double value) => _displayCents(value) / 100;

int _displayCents(double value) => (value * 100).round();

String _formatTraceValue(Object? value) {
  if (value == null) return '<null>';
  if (value is DateTime) return value.toIso8601String();
  if (value is Iterable) {
    return '[${value.map(_formatTraceValue).join(',')}]';
  }
  return value.toString().replaceAll('\n', r'\n');
}
