import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

Future<void> showAppStoreAccessRestoredDialog(
  BuildContext context, {
  required String planName,
  required bool isFamilyShared,
}) {
  return MonekoAlertDialog.show(
    context: context,
    title: isFamilyShared
        ? context.l10n.paywallFamilySharing
        : context.l10n.paywallRestoreSuccess,
    description: isFamilyShared
        ? 'Good news — your $planName plan is shared through Apple Family Sharing. We restored access for this account.'
        : 'Good news — we restored your $planName plan from the App Store for this account.',
    confirmLabel: context.l10n.gotIt,
     showCancelButton:false
  );
}
