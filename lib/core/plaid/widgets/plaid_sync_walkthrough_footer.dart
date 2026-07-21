import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

class PlaidSyncWalkthroughFooter extends StatelessWidget {
  const PlaidSyncWalkthroughFooter({
    super.key,
    required this.connectLabel,
    required this.isLastPage,
    required this.isConnecting,
    required this.providerName,
    required this.onContinue,
    required this.onConnect,
    this.loadingMessage,
    this.connectingHint,
  });

  final String connectLabel;
  final bool isLastPage;
  final bool isConnecting;
  final String providerName;
  final VoidCallback onContinue;
  final VoidCallback onConnect;
  final String? loadingMessage;
  final String? connectingHint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed:
                  isConnecting ? null : (isLastPage ? onConnect : onContinue),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                disabledBackgroundColor: colorScheme.primary,
                disabledForegroundColor: colorScheme.onPrimary,
                elevation: 0,
                shadowColor: colorScheme.shadow.withValues(alpha: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: isLastPage && isConnecting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          loadingMessage ?? context.l10n.loading,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      isLastPage ? connectLabel : context.l10n.continueButton,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: !isLastPage
                  ? const SizedBox.shrink()
                  : (isConnecting
                      ? (connectingHint != null
                          ? Text(
                              connectingHint!,
                              key: const ValueKey('plaid-connecting-hint'),
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('plaid-empty-hint')))
                      : Row(
                          key: const ValueKey('plaid-secure-lock'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.securedByProviderName(providerName),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )),
            ),
          ),
        ],
      ),
    );
  }
}
