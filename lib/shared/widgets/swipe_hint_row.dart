import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class SwipeHintRow extends StatelessWidget {
  const SwipeHintRow({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.hand_draw,
              size: 12,
              color: colorScheme.mutedForeground.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(
                color: colorScheme.mutedForeground.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

