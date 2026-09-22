import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';

class SubtleAdaptiveButton extends StatelessWidget {
  const SubtleAdaptiveButton({
    super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isLargeText = MonekoTextScale.isAtLeast(context, 1.5);

    if (isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: scheme.inputBackground,
        borderRadius: BorderRadius.circular(10),
        onPressed: onPressed,
        minimumSize: const Size(0, 0),
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              maxLines: isLargeText ? 3 : 1,
              overflow: isLargeText ? null : TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.foreground,
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.inputBackground,
            border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Center(
            child: Text(
              label,
              maxLines: isLargeText ? 3 : 1,
              overflow: isLargeText ? null : TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.foreground,
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
