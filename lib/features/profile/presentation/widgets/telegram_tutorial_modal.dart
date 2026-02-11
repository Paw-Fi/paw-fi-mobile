import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';

class TelegramTutorialModal extends HookWidget {
  const TelegramTutorialModal({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentPage = useState(0);
    final pageController = usePageController();

    final tutorialSteps = [
      _TutorialStep(
        title: context.l10n.naturalLanguage,
        description: context.l10n.describeExpenseAutomatically,
        icon: Icons.chat_bubble_outline,
      ),
      _TutorialStep(
        title: context.l10n.snapReceipt,
        description: context.l10n.snapReceiptDescription,
        icon: Icons.receipt_long,
      ),
    ];

    useEffect(() {
      void listener() {
        if (pageController.hasClients) {
          currentPage.value = pageController.page?.round() ?? 0;
        }
      }

      pageController.addListener(listener);
      return () => pageController.removeListener(listener);
    }, [pageController]);

    Future<void> handleBindTelegram() async {
      final Uri url = Uri.parse('https://t.me/moneko_ai_bot');
      try {
        bool launched =
            await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!launched) {
          launched = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        }
        if (!launched) {
          launched = await launchUrl(url, mode: LaunchMode.inAppWebView);
        }
        if (launched && context.mounted) {
          Navigator.of(context).pop(true);
        } else if (!launched && context.mounted) {
          AppToast.error(
            context,
            'Unable to open Telegram. Please install Telegram or a browser.',
          );
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.error(context, 'Could not launch Telegram link.');
        }
      }
    }

    return Dialog(
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connect Telegram',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: tutorialSteps.length,
                itemBuilder: (context, index) {
                  return _buildTutorialPage(
                    context,
                    tutorialSteps[index],
                    colorScheme,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  tutorialSteps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: currentPage.value == index ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentPage.value == index
                          ? colorScheme.primary
                          : colorScheme.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (currentPage.value > 0)
                    Expanded(
                      child: AdaptiveButton(
                        onPressed: () {
                          pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        label: context.l10n.previous,
                        style: AdaptiveButtonStyle.bordered,
                      ),
                    ),
                  if (currentPage.value > 0) const SizedBox(width: 12),
                  Expanded(
                    child: currentPage.value < tutorialSteps.length - 1
                        ? AdaptiveButton(
                            onPressed: () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            label: context.l10n.next,
                            style: AdaptiveButtonStyle.filled,
                          )
                        : Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.monekoPrimary,
                                  AppTheme.monekoSecondary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.monekoPrimary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: colorScheme.surface.withValues(alpha: 0.0),
                              child: InkWell(
                                onTap: handleBindTelegram,
                                borderRadius: BorderRadius.circular(12),
                                child: Center(
                                  child: Text(
                                    'Connect Telegram',
                                    style: TextStyle(
                                      color: colorScheme.primaryForeground,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialPage(
    BuildContext context,
    _TutorialStep step,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 250,
            height: 300,
            alignment: Alignment.center,
            child: Icon(
              step.icon,
              size: 120,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            step.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.mutedForeground,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  _TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
