import 'package:flutter/material.dart';

class PlaidSyncWalkthroughFooter extends StatelessWidget {
  const PlaidSyncWalkthroughFooter({
    super.key,
    required this.isLastPage,
    required this.isConnecting,
    required this.providerName,
    required this.onContinue,
    required this.onConnect,
  });

  final bool isLastPage;
  final bool isConnecting;
  final String providerName;
  final VoidCallback onContinue;
  final VoidCallback onConnect;

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
                elevation: 0,
                shadowColor: colorScheme.shadow.withValues(alpha: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: isLastPage && isConnecting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      isLastPage ? 'Connect Bank' : 'Continue',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isLastPage && !isConnecting ? 1 : 0,
            child: SizedBox(
              height: 16,
              child: isLastPage && !isConnecting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 12,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Secured by $providerName',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
