import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// A reusable toggle widget for switching between expense and income types.
///
/// Displays as a pill-shaped badge that changes color based on the current type.
/// Tapping the widget triggers the [onToggle] callback.
class TransactionTypeToggle extends StatelessWidget {
  const TransactionTypeToggle({
    super.key,
    required this.isIncome,
    required this.onToggle,
  });

  /// Whether the current type is income (true) or expense (false)
  final bool isIncome;

  /// Called when the user taps to toggle the type
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isIncome ? scheme.successSurface : scheme.errorSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (isIncome ? scheme.success : scheme.errorAccent)
                .withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          isIncome ? context.l10n.income : context.l10n.expense,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isIncome ? scheme.success : scheme.errorAccent,
          ),
        ),
      ),
    );
  }
}
