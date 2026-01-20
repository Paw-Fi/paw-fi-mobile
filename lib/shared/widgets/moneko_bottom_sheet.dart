import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MonekoBottomSheet {
  const MonekoBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    bool useRootNavigator = false,
  }) {
    if (Platform.isIOS) {
      return showCupertinoModalPopup<T>(
        context: context,
        barrierDismissible: isDismissible,
        useRootNavigator: useRootNavigator,
        builder: (context) {
          // Wrap content to simulate bottom sheet behavior if needed,
          // or just rely on child's layout (which is standard for Cupertino)
          // Usually Cupertino sheets are transparent and child handles decoration.
          return builder(context);
        },
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        builder: builder,
        backgroundColor: backgroundColor,
        elevation: elevation,
        shape: shape ??
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
        clipBehavior: clipBehavior,
        constraints: constraints,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        useRootNavigator: useRootNavigator,
      );
    }
  }
}
