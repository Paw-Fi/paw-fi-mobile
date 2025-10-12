import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:url_launcher/url_launcher.dart';

class WhatsAppTutorialModal extends HookWidget {
  const WhatsAppTutorialModal({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final currentPage = useState(0);
    final pageController = usePageController();

    final tutorialSteps = [
      _TutorialStep(
        title: 'Natural Language',
        description: 'Describe your expense. We’ll log it automatically.',
        icon: null,
        imagePath: 'lib/assets/images/whatsapp/text.png',
      ),
      _TutorialStep(
        title: 'Snap Receipt',
        description: 'Snap your receipt. AI extracts and logs it.',
        icon: null,
        imagePath: 'lib/assets/images/whatsapp/receipt.png',
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

    Future<void> handleBindWhatsApp() async {
      final Uri url = Uri.parse('https://wa.link/67a9gl');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          Navigator.of(context).pop(true); // Return true to refresh status
        }
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connect WhatsApp',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                    ),
                  ),
                
                ],
              ),
            ),

            // Carousel
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

            // Page indicators
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

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  if (currentPage.value > 0)
                    Expanded(
                      child: shadcnui.OutlineButton(
                        onPressed: () {
                          pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Previous'),
                      ),
                    ),
                  if (currentPage.value > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: currentPage.value == 0 ? 1 : 1,
                    child: currentPage.value < tutorialSteps.length - 1
                        ? shadcnui.PrimaryButton(
                            onPressed: () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: const Text('Next'),
                          )
                        : Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF25D366).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: handleBindWhatsApp,
                                borderRadius: BorderRadius.circular(12),
                                child: const Center(
                                  child: Text(
                                    'Connect',
                                    style: TextStyle(
                                      color: Colors.white,
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
    shadcnui.ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon or Image placeholder
          Container(
            width: 250,
            height: 300,
            decoration: const BoxDecoration(
             
            ),
            child: Image.asset(step.imagePath, fit: BoxFit.contain),
          ),
          const SizedBox(height: 15),

          // Title
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

          // Description
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
  final IconData? icon;
  final String imagePath;

  _TutorialStep({
    required this.title,
    required this.description,
    this.icon,
    required this.imagePath,
  });
}
