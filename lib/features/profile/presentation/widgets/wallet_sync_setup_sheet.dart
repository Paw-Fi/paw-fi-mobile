import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class WalletSyncSetupSheet extends StatelessWidget {
  final VoidCallback onFinish;
  final bool isSyncing;

  const WalletSyncSetupSheet({
    super.key,
    required this.onFinish,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colorScheme.sheetBorder, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHandle(colorScheme),
          _buildHeader(context, colorScheme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStep(
                  context: context,
                  step: 1,
                  title: 'Open the Shortcuts app',
                  description:
                      'Tap the Automations tab at the bottom of the screen.',
                ),
                _buildStep(
                  context: context,
                  step: 2,
                  title: 'Create a Personal Automation',
                  description:
                      'Tap + in the top right, then choose Personal Automation.',
                ),
                _buildStep(
                  context: context,
                  step: 3,
                  title: 'Select the Transaction trigger',
                  description:
                      'Scroll down to Wallet & Apple Pay, tap Transaction, then configure When I tap for the cards you want to track.',
                ),
                _buildStep(
                  context: context,
                  step: 4,
                  title: 'Create new shortcut and add Moneko action',
                  description:
                      'Tap Next, then tap Create New Shortcut (or New Blank Automation). Tap Add Action, search Moneko, and select "Log Wallet Transaction".',
                ),
                _buildStep(
                  context: context,
                  step: 5,
                  title: 'Map Amount from Shortcut Input',
                  description:
                      'In Amount, tap the field and choose Shortcut Input. Tap the inserted Shortcut Input token again, then select nested property Amount.',
                ),
                _buildStep(
                  context: context,
                  step: 6,
                  title: 'Map Merchant from Shortcut Input',
                  description:
                      'In Merchant, tap the field and choose Shortcut Input. Tap the token again, then select nested property Merchant.',
                ),
                _buildStep(
                  context: context,
                  step: 7,
                  title: 'Enable Run Immediately',
                  description:
                      'Turn on Run Immediately so transactions are logged silently, without confirmation.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: PrimaryAdaptiveButton(
                    onPressed: isSyncing ? null : onFinish,
                    child: isSyncing
                        ? const CircularProgressIndicator.adaptive()
                        : const Text(
                            'Open Shortcuts',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFooter(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.mutedForeground.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Up Wallet Sync',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Follow these steps in the Shortcuts app.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: colorScheme.foreground, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required BuildContext context,
    required int step,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? colorScheme.surfaceContainer : colorScheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.surfaceBorder, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_rounded, size: 14, color: colorScheme.mutedForeground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your credentials are stored securely in the iOS Keychain and only used to authenticate with your Moneko account. Moneko never accesses your bank, card, or wallet data directly.',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
