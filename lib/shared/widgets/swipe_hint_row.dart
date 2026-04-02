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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swipe_rounded,
            size: 13,
            color: colorScheme.mutedForeground.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.mutedForeground.withValues(alpha: 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
