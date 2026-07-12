import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AppLockBackground extends HookWidget {
  const AppLockBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final animationController = useAnimationController(
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    return Material(
      color: colorScheme.appBackground,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: colorScheme.appBackground),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: animationController,
                builder: (context, _) {
                  final moveX =
                      Curves.easeInOutSine.transform(animationController.value);
                  final moveY = Curves.easeInOutSine
                      .transform(1.0 - animationController.value);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -200 + (moveY * 300),
                        left: -100 + (moveX * 250),
                        child: _AmbientGlow(
                          color: colorScheme.primary.withValues(alpha: 0.65),
                          size: 320,
                        ),
                      ),
                      Positioned(
                        bottom: -250 + (moveX * 350),
                        right: -150 + (moveY * 250),
                        child: _AmbientGlow(
                          color: colorScheme.secondary.withValues(alpha: 0.60),
                          size: 420,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: ColoredBox(
                  color: colorScheme.appBackground.withValues(alpha: 0.1),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class AppLockLoadingOverlay extends StatelessWidget {
  const AppLockLoadingOverlay({
    required this.isLoading,
    this.message,
    super.key,
  });

  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? Center(
                  key: const ValueKey('app-lock-loading'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 56,
                        child:
                            CircularProgressIndicator.adaptive(strokeWidth: 5),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          message!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
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
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: size / 4, sigmaY: size / 4),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
