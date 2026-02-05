import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

double getTopPadding(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final topInset = mediaQuery.padding.top + 65;
  return topInset;
}

double getBottomPadding() {
  return PlatformInfo.isIOS26OrHigher() ? 60 : 5;
}
