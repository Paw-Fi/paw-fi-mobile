import 'package:flutter/material.dart';

import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

class AnimatedAmountText extends StatefulWidget {
  const AnimatedAmountText({
    super.key,
    required this.value,
    required this.symbol,
    required this.style,
    this.isNegative = false,
    this.duration = const Duration(milliseconds: 800),
  });

  final double value;
  final String symbol;
  final TextStyle style;
  final bool isNegative;
  final Duration duration;

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
    _begin = _displayAmount(widget.value);
    _end = _begin;
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
      return;
    }

    _begin = previous;
    _end = next;
    _animate = true;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _animate ? _begin : _end,
        end: _end,
      ),
      duration: _animate ? widget.duration : Duration.zero,
      curve: Curves.easeOutCubic,
      onEnd: () {
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

  String _formatAmount(BuildContext context, double value) {
    final normalized = double.parse(formatAmount(value));
    final formatted = formatLocalizedNumber(context, normalized);
    final prefix = widget.isNegative ? '-' : '';
    return '$prefix${widget.symbol}$formatted';
  }
}

double _displayAmount(double value) => _displayCents(value) / 100;

int _displayCents(double value) => (value * 100).round();
