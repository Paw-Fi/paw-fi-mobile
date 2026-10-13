import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'moneko_input.dart';

class MonekoTextFormField extends StatelessWidget {
  const MonekoTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.placeholder,
    this.enabled = true,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.style,
    this.onChanged,
    this.validator,
    this.autovalidateMode,
    this.compact = false,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;
  final bool enabled;
  final TextInputType? keyboardType;
  final int? minLines;
  final int maxLines;
  final TextAlign textAlign;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = style ??
        TextStyle(
            fontSize: compact ? 14 : 17,
            fontWeight: compact ? FontWeight.w400 : null,
            color: compact ? scheme.onSurface : scheme.foreground,
            letterSpacing: compact ? 0 : -0.3);
    return MonekoInput.space(
      compact: compact,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20, vertical: 8),
      child: AdaptiveTextFormField(
        controller: controller,
        initialValue: initialValue,
        placeholder: placeholder,
        enabled: enabled,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        textAlign: textAlign,
        style: textStyle,
        onChanged: onChanged,
        validator: validator,
        autovalidateMode: autovalidateMode,
        padding: compact ? EdgeInsets.zero : null,
        decoration: InputDecoration(
          isDense: compact,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: compact ? 0 : 16),
          hintStyle: textStyle.copyWith(
              fontWeight: compact ? FontWeight.w400 : FontWeight.w500,
              color: scheme.mutedForeground.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
