import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

const _kTrialWelcomePendingPrefix = 'trial_welcome_pending:';

String trialWelcomePendingKey(String userId) =>
    '$_kTrialWelcomePendingPrefix$userId';

class TrialWelcomeDialog extends StatelessWidget {
  const TrialWelcomeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'trial_welcome_dialog',
      barrierColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: const TrialWelcomeDialog(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double dialogWidth =
              constraints.maxWidth > 480 ? 420 : constraints.maxWidth - 32;

          return Material(
            color: colorScheme.surface.withValues(alpha: 0.0),
            child: Container(
              width: dialogWidth,
              constraints: const BoxConstraints(maxHeight: 640),
              decoration: BoxDecoration(
                color: colorScheme.sheetBackground,
                borderRadius: BorderRadius.circular(isIOS ? 20 : 28),
                border: Border.all(
                  color: colorScheme.sheetBorder,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isIOS ? 20 : 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TrialWelcomeHeader(colorScheme: colorScheme),
                            const SizedBox(height: 20),
                            Text(
                              l10n.trialWelcomeTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.foreground,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.trialWelcomeSubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.mutedForeground,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _FeatureRow(
                              icon: Icons.chat_bubble_rounded,
                              color: colorScheme.primary,
                              title: l10n.trialWelcomeFeatureMessagingTitle,
                              description:
                                  l10n.trialWelcomeFeatureMessagingBody,
                            ),
                            const SizedBox(height: 12),
                            _FeatureRow(
                              icon: Icons.email_rounded,
                              color: colorScheme.primary,
                              title: l10n.trialWelcomeFeatureEmailTitle,
                              description:
                                  l10n.trialWelcomeFeatureEmailBody,
                            ),
                            const SizedBox(height: 12),
                            _FeatureRow(
                              icon: Icons.multitrack_audio_rounded,
                              color: colorScheme.primary,
                              title:
                                  l10n.trialWelcomeFeatureMultiCurrencyTitle,
                              description:
                                  l10n.trialWelcomeFeatureMultiCurrencyBody,
                            ),
                            const SizedBox(height: 12),
                            _FeatureRow(
                              icon: Icons.insights_rounded,
                              color: colorScheme.primary,
                              title: l10n.trialWelcomeFeatureInsightsTitle,
                              description:
                                  l10n.trialWelcomeFeatureInsightsBody,
                            ),
                            const SizedBox(height: 24),
                            _FaqSection(colorScheme: colorScheme, l10n: l10n),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: SizedBox(
                        height: 52,
                        child: PrimaryAdaptiveButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.trialWelcomeCta),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrialWelcomeHeader extends StatelessWidget {
  const _TrialWelcomeHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Image.asset(
          'lib/assets/mascots/moneko.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(icon, size: 20, color: color),
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
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.colorScheme, required this.l10n});

  final ColorScheme colorScheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: colorScheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.trialWelcomeFaqHeader,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FaqItem(
            question: l10n.trialWelcomeFaqNoChargeQuestion,
            answer: l10n.trialWelcomeFaqNoChargeAnswer,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 10),
          _FaqItem(
            question: l10n.trialWelcomeFaqAfterTrialQuestion,
            answer: l10n.trialWelcomeFaqAfterTrialAnswer,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
    required this.colorScheme,
  });

  final String question;
  final String answer;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: TextStyle(
            fontSize: 12.5,
            color: colorScheme.mutedForeground,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
