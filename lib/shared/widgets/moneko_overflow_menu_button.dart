import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

class MonekoOverflowMenuButton<T> extends StatelessWidget {
  const MonekoOverflowMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon,
    this.tint,
    this.size = 44,
    this.buttonStyle = PopupButtonStyle.glass,
  });

  final List<AdaptivePopupMenuEntry> items;
  final void Function(int index, AdaptivePopupMenuItem<T> item) onSelected;
  final dynamic icon;
  final Color? tint;
  final double size;
  final PopupButtonStyle buttonStyle;

  @override
  Widget build(BuildContext context) {
    return AdaptivePopupMenuButton.icon<T>(
      icon: icon ??
          (PlatformInfo.isIOS26OrHigher()
              ? 'ellipsis.circle'
              : Icons.more_horiz),
      items: items,
      onSelected: onSelected,
      tint: tint,
      size: size,
      buttonStyle: buttonStyle,
    );
  }
}
