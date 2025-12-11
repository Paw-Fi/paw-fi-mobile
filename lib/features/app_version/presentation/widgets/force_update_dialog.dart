import 'dart:io';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/l10n/l10n.dart';

Future<void> showForceUpdateDialog({
  required BuildContext context,
  required String currentVersion,
  String? message,
  String? appStoreUrl,
}) async {
  Future<void> openStore() async {
    String? storeUrl = appStoreUrl;

    // Default URLs if not provided
    if (storeUrl == null || storeUrl.isEmpty) {
      if (Platform.isIOS) {
        // TestFlight public link (replace with your actual link)
        storeUrl = 'https://testflight.apple.com/join/Q9rNbkN5';
        // OR App Store link:
        // storeUrl = 'https://apps.apple.com/app/idYOUR_APP_ID';
      } else if (Platform.isAndroid) {
        storeUrl =
            'https://play.google.com/store/apps/details?id=com.moneko.app';
      }
    }

    if (storeUrl != null) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  await AdaptiveAlertDialog.show(
    context: context,
    title: context.l10n.updateRequiredTitle,
    message: message ?? context.l10n.updateRequiredMessage,
    actions: [
      AlertAction(
        title: context.l10n.updateNow,
        style: AlertActionStyle.primary,
        onPressed: openStore,
      ),
    ],
  );
}
