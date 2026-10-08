import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class HeaderMonthLabel extends StatelessWidget {
  const HeaderMonthLabel({
    super.key,
    required this.month,
    this.textKey,
  });

  final DateTime month;
  final Key? textKey;

  static String format(BuildContext context, DateTime month) =>
      MaterialLocalizations.of(context).formatMonthYear(month);

  @override
  Widget build(BuildContext context) {
    final label = format(context, month);
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      child: KeyedSubtree(
        key: ValueKey(label),
        child: Text(
          label,
          key: textKey,
          style: TextStyle(
            color: Theme.of(context).colorScheme.mutedForeground,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
