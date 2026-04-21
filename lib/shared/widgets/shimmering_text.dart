import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:moneko/core/theme/app_theme.dart';

class ShimmeringText extends HookWidget {
  const ShimmeringText({
    super.key,
    required this.text,
    required this.style,
    this.shimmering = true,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final bool shimmering;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1500),
    );

    useEffect(() {
      if (shimmering) {
        controller.repeat();
      } else {
        controller.stop();
      }
      return null;
    }, [shimmering]);

    final animation = useAnimation(
      Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutSine),
      ),
    );

    if (!shimmering) {
      return Text(
        text,
        key: key,
        textAlign: textAlign,
        style: style,
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final highlightColor = colorScheme.primary.withValues(alpha: 0.8);
        final baseColor = style.color ?? colorScheme.mutedForeground;

        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [
            (animation - 0.3).clamp(0.0, 1.0),
            animation.clamp(0.0, 1.0),
            (animation + 0.3).clamp(0.0, 1.0),
          ],
          colors: [
            baseColor,
            highlightColor,
            baseColor,
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        key: key,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
