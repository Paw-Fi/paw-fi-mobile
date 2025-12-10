import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

/// Platform-adaptive switch that uses CupertinoSwitch on iOS and Material Switch on other platforms
class MonekoSwitch extends StatelessWidget {
  const MonekoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.trackColor,
    this.thumbColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? trackColor;
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: activeColor,
        inactiveTrackColor: trackColor,
        thumbColor: thumbColor,
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor,
      activeTrackColor: trackColor,
      thumbColor:
          thumbColor != null ? WidgetStateProperty.all(thumbColor) : null,
    );
  }
}
