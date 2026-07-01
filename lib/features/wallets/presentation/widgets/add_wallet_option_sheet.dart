import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

enum AddWalletOption { manual, bank }

Future<AddWalletOption?> showAddWalletOptionSheet(
  BuildContext context, {
  required bool showBankConnectionOption,
}) {
  return MonekoBottomSheet.show<AddWalletOption>(
    context: context,
    title: context.l10n.newWallet,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.chooseHowYouWantToAddThisWallet,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              _AddWalletOptionTile(
                icon: Icons.edit_note_rounded,
                title: context.l10n.manualTrackingAccount,
                subtitle: context.l10n.createWalletUpdateBalanceYourself,
                onTap: () => Navigator.of(context).pop(AddWalletOption.manual),
              ),
              if (showBankConnectionOption) ...[
                const SizedBox(height: 8),
                _AddWalletOptionTile(
                  icon: Icons.account_balance_rounded,
                  title: context.l10n.connectBank,
                  subtitle: context.l10n.connectBankAccountAutomaticSyncing,
                  onTap: () => Navigator.of(context).pop(AddWalletOption.bank),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _AddWalletOptionTile extends StatelessWidget {
  const _AddWalletOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.mutedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
