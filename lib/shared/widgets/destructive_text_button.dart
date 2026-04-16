import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DestructiveAdaptiveButton extends StatelessWidget {
  const DestructiveAdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.isExpanded = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: isExpanded ? double.infinity : null,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        color: scheme.destructive.withValues(alpha: 0.1),
        disabledColor: scheme.destructive.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        pressedOpacity: 0.7,
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    scheme.destructive,
                  ),
                ),
              )
            : DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.destructive,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
                child: child,
              ),
      ),
    );
  }
}
