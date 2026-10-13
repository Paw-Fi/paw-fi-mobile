import 'package:flutter/material.dart';

/// Supplies ink painting for Material controls inside adaptive Cupertino routes.
class AppMaterialSurface extends StatelessWidget {
  const AppMaterialSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        // Keep the adaptive app's inherited typography unchanged.
        textStyle: DefaultTextStyle.of(context).style,
        child: child,
      );
}
