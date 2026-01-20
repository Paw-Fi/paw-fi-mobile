import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

double getSubPageTopPadding(BuildContext context) {
  return PlatformInfo.isIOS26OrHigher() ? 65.0 : 0;
}
