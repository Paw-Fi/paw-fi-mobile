import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/profile/presentation/providers/financial_reset_provider.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/moneko_settings_tile.dart';

class FinancialResetTile extends HookConsumerWidget {
  const FinancialResetTile(
      {super.key,
      required this.userId,
      required this.ownsActor,
      required this.isPreview});

  final String userId;
  final bool Function() ownsActor;
  final bool Function() isPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = useState(false);
    final l10n = context.l10n;
    final color = Theme.of(context).colorScheme.destructive;
    Future<void> start() async {
      if (busy.value) return;
      if (isPreview()) {
        AppToast.info(
            context, l10n.previewResetFinancialDataDisabledInDemoMode);
        return;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      final route = ModalRoute.of(context);
      bool current() =>
          context.mounted &&
          route?.isCurrent == true &&
          !isPreview() &&
          ownsActor();
      busy.value = true;
      try {
        final answer = await MonekoAlertDialog.show(
            context: context,
            title: l10n.resetDataCannotBeUndone,
            description: l10n.resetDataConfirmationMessage,
            confirmLabel: l10n.resetData,
            cancelLabel: l10n.cancel,
            isDestructive: true,
            inputConfig: MonekoAlertDialogInputConfig(
                placeholder: l10n.reset,
                isRequired: true,
                validationPattern: RegExp(r'^RESET$'),
                validationMessage: l10n.typeResetToConfirm));
        if (answer?.confirmed != true ||
            answer?.text != 'RESET' ||
            !current()) {
          return;
        }
        await container.read(financialResetProvider).prepare(userId, current);
        container.invalidate(resetRecoveryProvider(userId));
      } catch (_) {
        if (context.mounted && current()) {
          AppToast.error(context, l10n.resetCheckRetry);
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return MonekoSettingsTile(
        icon: Icons.restart_alt_rounded,
        label: l10n.resetData,
        iconColor: color,
        labelColor: color,
        onTap: busy.value ? null : start);
  }
}
