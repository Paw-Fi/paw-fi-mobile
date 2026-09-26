import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

/// Explains that WhatsApp is temporarily unavailable and offers Telegram as
/// the supported messaging alternative.
Future<bool> showWhatsAppUnavailableModal(BuildContext context) async {
  final result = await MonekoAlertDialog.show(
    context: context,
    title: context.l10n.whatsappIsTemporarilyUnavailable,
    description: context.l10n.whatsappUnavailableUseTelegram,
    confirmLabel: context.l10n.useTelegram,
    cancelLabel: context.l10n.close,
  );

  return result?.action == MonekoAlertDialogAction.confirm;
}
