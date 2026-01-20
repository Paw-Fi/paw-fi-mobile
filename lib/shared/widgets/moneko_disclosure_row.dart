import 'package:flutter/material.dart';

class MonekoDisclosureRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;
  final bool multiline;
  final bool isValuePlaceholder;

  const MonekoDisclosureRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.multiline = false,
    this.isValuePlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment:
              multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: multiline ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isValuePlaceholder
                      ? colorScheme.onSurface.withValues(alpha: 0.4)
                      : colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
