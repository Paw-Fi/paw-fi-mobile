import 'package:flutter/material.dart';

class CircularImageAvatar extends StatelessWidget {
  const CircularImageAvatar({
    super.key,
    required this.size,
    required this.child,
    this.backgroundColor,
    this.imageSize,
  });

  final double size;
  final Widget child;
  final Color? backgroundColor;
  final double? imageSize;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: backgroundColor,
        child: imageSize == null
            ? child
            : Center(
                child: ClipOval(
                  child: SizedBox.square(
                    dimension: imageSize!,
                    child: child,
                  ),
                ),
              ),
      ),
    );
  }
}
