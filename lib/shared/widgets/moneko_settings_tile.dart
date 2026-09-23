import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';

class MonekoSettingsTile extends StatelessWidget {
  const MonekoSettingsTile({
    super.key,
    this.icon,
    this.customIcon,
    required this.label,
    this.labelColor,
    this.value,
    this.valueWidget,
    this.trailing,
    this.iconColor,
    this.onTap,
    this.showChevron = true,
    this.isLocked = false,
  });

  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final Color? labelColor;
  final String? value;
  final Widget? valueWidget;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLargeText = MonekoTextScale.isAtLeast(context, 1.5);

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: isLargeText
              ? _buildLargeTextLayout(context, colorScheme)
              : _buildDefaultLayout(context, colorScheme),
        ),
      ),
    );
  }

  Widget _buildDefaultLayout(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        _buildIcon(colorScheme),
        const SizedBox(width: 16),
        Expanded(
          flex: label == 'Email' ? 1 : 4,
          child: _buildLabel(colorScheme),
        ),
        if (valueWidget != null)
          SizedBox(width: 140, child: valueWidget!)
        else if (value != null && value!.isNotEmpty)
          Expanded(
            flex: 3,
            child: _buildValue(colorScheme, maxLines: 1),
          ),
        _buildTrailing(colorScheme),
      ],
    );
  }

  Widget _buildLargeTextLayout(BuildContext context, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIcon(colorScheme),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(colorScheme),
              if (valueWidget != null) ...[
                const SizedBox(height: 8),
                valueWidget!,
              ] else if (value != null && value!.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildValue(colorScheme),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildTrailing(colorScheme),
      ],
    );
  }

  Widget _buildIcon(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: customIcon ??
          Icon(icon, size: 20, color: iconColor ?? colorScheme.onSurface),
    );
  }

  Widget _buildLabel(ColorScheme colorScheme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: labelColor ?? colorScheme.onSurface,
      ),
    );
  }

  Widget _buildValue(ColorScheme colorScheme, {int? maxLines}) {
    return Text(
      value!,
      textAlign: maxLines == 1 ? TextAlign.right : TextAlign.start,
      style: TextStyle(fontSize: 14, color: colorScheme.mutedForeground),
      overflow: maxLines == 1 ? TextOverflow.ellipsis : null,
      maxLines: maxLines,
    );
  }

  Widget _buildTrailing(ColorScheme colorScheme) {
    if (trailing != null) return trailing!;
    if (isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Text(
          'PLUS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
            letterSpacing: 0.3,
          ),
        ),
      );
    }
    if (showChevron && onTap != null) {
      return Icon(
        Icons.chevron_right,
        size: 20,
        color: colorScheme.mutedForeground.withValues(alpha: 0.6),
      );
    }
    return const SizedBox.shrink();
  }
}
