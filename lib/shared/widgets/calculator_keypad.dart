import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

Future<String?> showCalculatorKeypadSheet({
  required BuildContext context,
  String initialValue = '',
  ValueChanged<String>? onValueChange,
}) {
  return MonekoBottomSheet.show<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CalculatorKeypad(
      initialValue: initialValue,
      onValueChange: onValueChange,
      onConfirm: (value) {
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext, value);
        }
      },
    ),
  );
}

class CalculatorKeypad extends StatefulWidget {
  const CalculatorKeypad({
    super.key,
    required this.onConfirm,
    this.onValueChange,
    this.initialValue = '0',
  });

  final String initialValue;
  final ValueChanged<String>? onValueChange;
  final ValueChanged<String> onConfirm;

  @override
  State<CalculatorKeypad> createState() => _CalculatorKeypadState();
}

class _CalculatorKeypadState extends State<CalculatorKeypad> {
  late String _display;
  double? _lastValue;
  String? _operation;
  bool _shouldResetDisplay = false;
  late String _decimalSeparator;
  bool _isFirstInput = true;

  @override
  void initState() {
    super.initState();
    // Normalize initial value to use dot internally
    _display = widget.initialValue == '0'
        ? ''
        : widget.initialValue.replaceAll(',', '.');
    _decimalSeparator = '.';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _decimalSeparator =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
            .symbols
            .DECIMAL_SEP;
  }

  double _calculate(double first, double second, String op) {
    switch (op) {
      case '+':
        return first + second;
      case '-':
        return first - second;
      case '×':
        return first * second;
      case '÷':
        return second != 0 ? first / second : 0;
      default:
        return second;
    }
  }

  void _handleKeyPress(String key) {
    setState(() {
      if (RegExp(r'[0-9]').hasMatch(key)) {
        if (_shouldResetDisplay || _isFirstInput) {
          _display = key;
          _shouldResetDisplay = false;
          _isFirstInput = false;
        } else {
          _display = _display == '0' ? key : _display + key;
        }
      } else if (key == '.') {
        if (_shouldResetDisplay || _isFirstInput) {
          _display = '0.';
          _shouldResetDisplay = false;
          _isFirstInput = false;
        } else {
          if (!_display.contains('.')) {
            _display = '${_display.isEmpty ? '0' : _display}.';
          }
        }
      } else if (key == 'AC') {
        _display = '';
        _lastValue = null;
        _operation = null;
        _shouldResetDisplay = false;
        _isFirstInput = false;
      } else if (key == 'backspace') {
        _isFirstInput = false;
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1);
        }
      } else if (['+', '-', '×', '÷'].contains(key)) {
        _isFirstInput = false;
        final current = double.tryParse(_display) ?? 0.0;
        if (_lastValue != null && _operation != null && !_shouldResetDisplay) {
          final result = _calculate(_lastValue!, current, _operation!);
          _display = _formatDisplay(result);
          _lastValue = result;
        } else {
          _lastValue = current;
        }
        _operation = key;
        _shouldResetDisplay = true;
      } else if (key == '=' || key == 'Done') {
        _isFirstInput = false;
        final current = double.tryParse(_display) ?? 0.0;
        if (_lastValue != null && _operation != null) {
          final result = _calculate(_lastValue!, current, _operation!);
          _display = _formatDisplay(result);
          _lastValue = null;
          _operation = null;
          _shouldResetDisplay = true;
          if (key == 'Done') {
            widget.onConfirm(_display);
            return;
          }
        } else if (key == 'Done') {
          widget.onConfirm(_display.isEmpty ? '0' : _display);
          return;
        }
      }
    });
    widget.onValueChange?.call(_display.isEmpty ? '0' : _display);
  }

  String _getLocalizedDisplay(String value) {
    if (_decimalSeparator == '.') return value;
    return value.replaceAll('.', _decimalSeparator);
  }

  String _formatDisplay(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: scheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: Alignment.centerRight,
            height: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_lastValue != null && _operation != null)
                  Text(
                    '${_getLocalizedDisplay(_formatDisplay(_lastValue!))} $_operation ${_shouldResetDisplay ? '' : _getLocalizedDisplay(_display)}',
                    style: TextStyle(
                      color: scheme.mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _isFirstInput && _display.isNotEmpty
                        ? scheme.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _display.isEmpty ? '0' : _getLocalizedDisplay(_display),
                    style: TextStyle(
                      color: _isFirstInput && _display.isNotEmpty
                          ? scheme.primary
                          : scheme.foreground,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Keypad
          LayoutBuilder(builder: (context, constraints) {
            final keyWidth = (constraints.maxWidth - (3 * 12)) / 4;
            return Column(
              children: [
                _buildRow([
                  _buildKey('AC',
                      icon: Icons.refresh, variant: _KeyVariant.action),
                  _buildKey('÷', variant: _KeyVariant.operator),
                  _buildKey('×',
                      icon: Icons.close, variant: _KeyVariant.operator),
                  _buildKey('backspace',
                      icon: Icons.backspace_outlined,
                      variant: _KeyVariant.action),
                ]),
                const SizedBox(height: 12),
                _buildRow([
                  _buildKey('7'),
                  _buildKey('8'),
                  _buildKey('9'),
                  _buildKey('-',
                      icon: Icons.remove, variant: _KeyVariant.operator),
                ]),
                const SizedBox(height: 12),
                _buildRow([
                  _buildKey('4'),
                  _buildKey('5'),
                  _buildKey('6'),
                  _buildKey('+',
                      icon: Icons.add, variant: _KeyVariant.operator),
                ]),
                const SizedBox(height: 12),
                _buildRow([
                  _buildKey('1'),
                  _buildKey('2'),
                  _buildKey('3'),
                  _buildKey('=', variant: _KeyVariant.operator),
                ]),
                const SizedBox(height: 12),
                _buildRow([
                  _buildKey('.', label: _decimalSeparator),
                  _buildKey('0'),
                  _buildKey('Done',
                      icon: Icons.check,
                      variant: _KeyVariant.confirm,
                      width: keyWidth * 2 + 12),
                ]),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }

  Widget _buildKey(String value,
      {String? label,
      IconData? icon,
      _KeyVariant variant = _KeyVariant.standard,
      double? width}) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _operation == value && !_shouldResetDisplay;

    Color bgColor;
    Color fgColor;

    switch (variant) {
      case _KeyVariant.operator:
        bgColor =
            isSelected ? scheme.primary : scheme.primary.withValues(alpha: 0.1);
        fgColor = isSelected ? scheme.onPrimary : scheme.primary;
      case _KeyVariant.action:
        bgColor = scheme.muted.withValues(alpha: 0.5);
        fgColor = scheme.mutedForeground;
      case _KeyVariant.confirm:
        bgColor = scheme.primary;
        fgColor = scheme.onPrimary;
      case _KeyVariant.standard:
        bgColor = scheme.muted.withValues(alpha: 0.3);
        fgColor = scheme.foreground;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleKeyPress(value),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: width ?? (MediaQuery.of(context).size.width - 32 - 36) / 4,
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: fgColor, size: 24)
                : Text(
                    label ?? value,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

enum _KeyVariant { standard, operator, action, confirm }
