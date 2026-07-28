import 'package:flutter/material.dart';

import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

void _homeSpendTrace(String message) {
  assert(() {
    debugPrint('🧾 [HomeSpendTrace] $message');
    return true;
  }());
}

String _traceAmount(num value) => value.toStringAsFixed(2);

class AnimatedAmountText extends StatefulWidget {
  const AnimatedAmountText({
    super.key,
    required this.value,
    required this.symbol,
    required this.style,
    this.isNegative = false,
    this.duration = const Duration(milliseconds: 400),
    this.decimalDigits = 2,
    this.suffix = '',
  });

  final double value;
  final String symbol;
  final TextStyle style;
  final bool isNegative;
  final Duration duration;
  final int decimalDigits;
  final String suffix;

  @override
  State<AnimatedAmountText> createState() => _AnimatedAmountTextState();
}

class _AnimatedAmountTextState extends State<AnimatedAmountText> {
  late double _begin;
  late double _end;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _homeSpendTrace(
      'animated-amount-init symbol=${widget.symbol} value=${_traceAmount(widget.value)}',
    );
    _begin = _displayValue(widget.value);
    _end = _begin;
  }

  @override
  void didUpdateWidget(covariant AnimatedAmountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _displayValue(widget.value);
    final sameDisplay = _displayValue(oldWidget.value) == next;
    final sameSymbol = oldWidget.symbol == widget.symbol;
    final sameSign = oldWidget.isNegative == widget.isNegative;

    if (sameDisplay &&
        sameSymbol &&
        sameSign &&
        oldWidget.suffix == widget.suffix &&
        oldWidget.decimalDigits == widget.decimalDigits) {
      return;
    }

    _homeSpendTrace(
      'animated-amount-change symbol=${widget.symbol} '
      'from=${_traceAmount(oldWidget.value)} to=${_traceAmount(widget.value)} '
      'oldWidget=${_traceAmount(oldWidget.value)} newWidget=${_traceAmount(widget.value)}',
    );
    _begin = _end;
    _end = next;
    _animate = true;
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : (_animate ? widget.duration : Duration.zero);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _animate ? _begin : _end, end: _end),
      duration: duration,
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (_animate && mounted) setState(() => _animate = false);
      },
      builder: (context, value, _) => Text(
        _formatAmount(context, value),
        style: widget.style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _formatAmount(BuildContext context, double value) {
    final normalized = widget.decimalDigits == 2
        ? double.parse(formatAmount(value))
        : double.parse(value.toStringAsFixed(widget.decimalDigits));
    final formatted = formatLocalizedNumber(context, normalized);
    final prefix = widget.isNegative ? '-' : '';
    return '$prefix${widget.symbol}$formatted${widget.suffix}';
  }
}

int _displayCents(double value) => (value * 100).round();

double _displayValue(double value) => _displayCents(value) / 100;

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    required this.progress,
    required this.color,
    required this.height,
    required this.backgroundColor,
    required this.borderRadius,
    this.decoration,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double height;
  final BorderRadius borderRadius;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        height: height,
        color: backgroundColor,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: height,
              decoration: decoration ?? BoxDecoration(color: color),
            ),
          ),
        ),
      ),
    );
  }
}
