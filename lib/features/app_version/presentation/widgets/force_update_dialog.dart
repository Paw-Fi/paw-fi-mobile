import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

Future<void> showForceUpdateDialog({
  required BuildContext context,
  required String currentVersion,
  String? message,
  String? appStoreUrl,
}) async {
  final dialogContext = rootNavigatorKey.currentContext ?? context;

  Future<void> openStore() async {
    String? storeUrl = appStoreUrl;

    if (storeUrl == null || storeUrl.isEmpty) {
      if (Platform.isIOS) {
        storeUrl = 'https://apps.apple.com/app/moneko/id6753925279';
      } else if (Platform.isAndroid) {
        storeUrl =
            'https://play.google.com/store/apps/details?id=com.moneko.mobile';
      }
    }

    if (storeUrl != null) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  while (true) {
    final result = await MonekoAlertDialog.show(
      context: dialogContext,
      title: dialogContext.l10n.updateRequiredTitle,
      description: message ?? dialogContext.l10n.updateRequiredMessage,
      confirmLabel: dialogContext.l10n.updateNow,
      showCancelButton: false,
      barrierDismissible: false,
    );

    if (result?.confirmed == true) {
      await openStore();
    }
  }
}
