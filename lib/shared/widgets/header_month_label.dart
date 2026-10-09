import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class HeaderMonthLabel extends StatelessWidget {
  const HeaderMonthLabel({
    super.key,
    required this.month,
    this.textKey,
    this.fontSize = 12,
    this.leadingLabel,
  });

  final DateTime month;
  final Key? textKey;
  final double fontSize;
  final String? leadingLabel;

  static String format(BuildContext context, DateTime month) =>
      MaterialLocalizations.of(context).formatMonthYear(month);

  @override
  Widget build(BuildContext context) {
    final monthLabel = format(context, month);
    final animationLabel = '${leadingLabel ?? ''}|$monthLabel';
    final textStyle = TextStyle(
      color: Theme.of(context).colorScheme.mutedForeground,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      child: KeyedSubtree(
        key: ValueKey(animationLabel),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leadingLabel != null) ...[
              Text(leadingLabel!, style: textStyle),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: textStyle.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              monthLabel,
              key: textKey,
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }
}
