import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class PlaidSyncWalkthroughHeader extends StatelessWidget {
  const PlaidSyncWalkthroughHeader({
    super.key,
    required this.currentPage,
    required this.numPages,
    required this.isConnecting,
    required this.onClose,
  });

  final int currentPage;
  final int numPages;
  final bool isConnecting;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        height: 44,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: isConnecting
              ? Center(
                  key: const ValueKey('plaid-sync-loading-header'),
                  child: Text(
                    'Preparing your bank connection...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.mutedForeground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Row(
                  key: const ValueKey('plaid-sync-progress-header'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        numPages,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 8),
                          height: 6,
                          width: currentPage == index ? 24 : 6,
                          decoration: BoxDecoration(
                            color: currentPage == index
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
