import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';

class CalculatorInput extends StatefulWidget {
  const CalculatorInput({
    super.key,
    required this.onChanged,
    this.value,
    this.label,
    this.placeholder = '0.00',
    this.errorText,
    this.prefix,
    this.suffix,
    this.required = false,
  });

  final double? value;
  final ValueChanged<double> onChanged;
  final String? label;
  final String placeholder;
  final String? errorText;
  final Widget? prefix;
  final Widget? suffix;
  final bool required;

  @override
  State<CalculatorInput> createState() => _CalculatorInputState();
}

class _CalculatorInputState extends State<CalculatorInput> {
  late String _displayValue;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value?.toString() ?? '';
  }

  @override
  void didUpdateWidget(CalculatorInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _displayValue = widget.value?.toString() ?? '';
    }
  }

  Future<void> _showCalculator() async {
    final value = await showCalculatorKeypadSheet(
      context: context,
      initialValue: _displayValue,
      onValueChange: (val) {
        setState(() {
          _displayValue = val;
        });
      },
    );
    if (value == null) return;

    setState(() {
      _displayValue = value;
    });
    final num = double.tryParse(value) ?? 0.0;
    widget.onChanged(num);
  }

  String _getLocalizedDisplay(BuildContext context, String value) {
    if (value.isEmpty) return value;
    final separator =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
            .symbols
            .DECIMAL_SEP;
    if (separator == '.') return value;
    return value.replaceAll('.', separator);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final localizedValue = _getLocalizedDisplay(context, _displayValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: RichText(
              text: TextSpan(
                text: widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.errorText != null
                      ? scheme.error
                      : scheme.foreground,
                ),
                children: [
                  if (widget.required)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: scheme.error),
                    ),
                ],
              ),
            ),
          ),
        ],
        GestureDetector(
          onTap: _showCalculator,
          child: MonekoInput(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (widget.prefix != null) ...[
                  widget.prefix!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    localizedValue.isEmpty
                        ? widget.placeholder
                        : localizedValue,
                    style: TextStyle(
                      fontSize: 17,
                      color: localizedValue.isEmpty
                          ? scheme.mutedForeground
                          : scheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.suffix != null) ...[
                  const SizedBox(width: 12),
                  widget.suffix!,
                ] else ...[
                  Icon(
                    Icons.calculate_outlined,
                    size: 20,
                    color: scheme.mutedForeground,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                fontSize: 12,
                color: scheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
