import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';
import 'package:moneko/features/accounts/presentation/providers/account_providers.dart';
import 'package:moneko/features/accounts/presentation/widgets/account_icon_resolver.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

class ArchivedAccountsPage extends ConsumerWidget {
  const ArchivedAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final archivedAsync = ref.watch(archivedScopedAccountsProvider);
    final actions = ref.watch(accountActionsProvider);
    final selectedCurrencyCode = ref.watch(selectedHomeCurrencyCodeProvider);

    Future<void> onRestore(AccountEntity account) async {
      final confirm = await MonekoAlertDialog.show(
        context: context,
        title: 'Restore account?',
        description:
            'This account will be moved back to active accounts and can be used in future transactions.',
        confirmLabel: 'Restore',
        cancelLabel: context.l10n.cancel,
      );
      if (confirm?.confirmed != true || !context.mounted) return;

      try {
        await actions.restoreAccount(account.id);
        if (!context.mounted) return;
        AppToast.success(context, 'Account restored');
      } catch (error) {
        if (!context.mounted) return;
        AppToast.error(context, ErrorHandler.getUserFriendlyMessage(error));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Accounts'),
      ),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString()),
          ),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Text(
                'No archived accounts',
                style: TextStyle(color: colorScheme.mutedForeground),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ArchivedAccountCard(
                  account: account,
                  currencyCode: selectedCurrencyCode,
                  onRestore: () => onRestore(account),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ArchivedAccountCard extends StatelessWidget {
  const _ArchivedAccountCard({
    required this.account,
    required this.currencyCode,
    required this.onRestore,
  });

  final AccountEntity account;
  final String currencyCode;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final symbol = resolveCurrencySymbol(currencyCode);
    final amount = account.currentBalanceCents / 100.0;
    final mutedSurface = colorScheme.muted.withValues(alpha: 0.35);

    final accountColorRaw = account.color.toUpperCase() == '#6B7280'
        ? colorScheme.primary
        : parseAccountColor(account.color, colorScheme.primary);
    final baseColor = AppTheme.tunedPocketBaseColor(
      accountColorRaw,
      colorScheme,
      hasCustomColor: account.color.toUpperCase() != '#6B7280',
    );

    return Opacity(
      opacity: 0.78,
      child: Container(
        decoration: BoxDecoration(
          color: mutedSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resolveAccountIcon(account.icon),
                  color: colorScheme.mutedForeground,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$symbol${formatLocalizedNumber(context, double.parse(formatAmount(amount.abs())))}',
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRestore,
                child: const Text('Restore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
