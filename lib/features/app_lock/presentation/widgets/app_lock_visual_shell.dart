import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AppLockBackground extends StatelessWidget {
  const AppLockBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    if (!isIOS) {
      return Material(
        color: colorScheme.appBackground,
        child: child,
      );
    }

    return Material(
      color: colorScheme.appBackground,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: colorScheme.appBackground),
          ),
          Positioned(
            top: -100,
            left: -50,
            child: _AmbientGlow(
                color: colorScheme.primary.withValues(alpha: 0.15), size: 300),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: _AmbientGlow(
                color: colorScheme.secondary.withValues(alpha: 0.1), size: 400),
          ),
          child,
        ],
      ),
    );
  }
}

class AppLockLoadingOverlay extends StatelessWidget {
  const AppLockLoadingOverlay({required this.isLoading, super.key});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const Center(
                  key: ValueKey('app-lock-loading'),
                  child: SizedBox.square(
                    dimension: 56,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 5),
                  ),
                )
              : const SizedBox.shrink(
                  key: ValueKey('app-lock-not-loading'),
                ),
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          ),
        ],
      ),
    );
  }
}
