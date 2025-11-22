import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DestructiveAdaptiveButton extends StatelessWidget {
  const DestructiveAdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    // Return different widgets based on platform
    if (PlatformInfo.isIOS) {
      if (PlatformInfo.isIOS26OrHigher()) {
        // iOS 26+ - Use native iOS 26 button with red destructive styling
        return AdaptiveButton.child(
          onPressed: onPressed,
          color: scheme.destructive,
          style: AdaptiveButtonStyle.filled,
          child: child,
        );
      } else {
        // iOS <26 - Use Cupertino button with explicit red styling
        return CupertinoButton.filled(
          onPressed: onPressed,
          color: scheme.destructive,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: child,
          ),
        );
      }
    } else if (PlatformInfo.isAndroid) {
      // Android - Use Material ElevatedButton with red styling
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.destructive,
          foregroundColor: Colors.white,
        ),
        child: child,
      );
    } else {
      // Other platforms (web, desktop) - Use Material as fallback
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.destructive,
          foregroundColor: Colors.white,
        ),
        child: child,
      );
    }
  }
}