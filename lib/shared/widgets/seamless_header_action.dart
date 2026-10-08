import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';

class SeamlessHeaderAction extends ConsumerWidget {
  const SeamlessHeaderAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(previewModeProvider.select((state) => state.isActive))) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.foreground.withValues(
      alpha: onPressed == null && !isLoading ? 0.45 : 1.0,
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.cardSurface,
        shape: StadiumBorder(side: BorderSide(color: colors.controlBorder)),
      ),
      child: AdaptiveButton.child(
        onPressed: onPressed,
        useNative: false,
        style: AdaptiveButtonStyle.plain,
        borderRadius: BorderRadius.circular(100),
        minSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: isLoading
                    ? CircularProgressIndicator(
                        key: const ValueKey('saving'),
                        strokeWidth: 2,
                        color: foreground,
                      )
                    : Icon(
                        icon,
                        key: const ValueKey('icon'),
                        size: 18,
                        color: foreground,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
