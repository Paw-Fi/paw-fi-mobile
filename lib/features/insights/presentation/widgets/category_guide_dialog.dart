import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';

import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

void showCategoryGuide(BuildContext context, ColorScheme colorScheme) {
  final slides = _scenarioCategorySlides(context);
  final controller = PageController();
  int currentPage = 0;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Theme(
            data: Theme.of(context),
            child: Dialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420, maxHeight: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.scenarioCategoriesGuide,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                color: colorScheme.onSurfaceVariant),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.categoryGuideIntro,
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: PageView.builder(
                          controller: controller,
                          itemCount: slides.length,
                          onPageChanged: (index) =>
                              setState(() => currentPage = index),
                          itemBuilder: (context, index) {
                            final slide = slides[index];
                            return _ScenarioHelpSlide(
                              colorScheme: colorScheme,
                              title: slide.title,
                              summary: slide.summary,
                              bullets: slide.points,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(slides.length, (index) {
                          final active = index == currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: active ? 20 : 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(context.l10n.close),
                          ),
                          const Spacer(),
                          PrimaryAdaptiveButton(
                            onPressed: () {
                              if (currentPage < slides.length - 1) {
                                controller.nextPage(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut);
                                setState(() => currentPage += 1);
                              } else {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: Text(currentPage < slides.length - 1
                                ? context.l10n.next
                                : context.l10n.done),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ScenarioSlideData {
  const _ScenarioSlideData(
      {required this.title, required this.summary, required this.points});

  final String title;
  final String summary;
  final List<String> points;
}

List<_ScenarioSlideData> _scenarioCategorySlides(BuildContext context) {
  return [
    _ScenarioSlideData(
      title: context.l10n.readTheBarChartLikeAPro,
      summary: context.l10n.categoryChartDesc,
      points: [
        context.l10n.leftHandChamps,
        context.l10n.smallButFrequent,
        context.l10n.colorMatches,
      ],
    ),
    _ScenarioSlideData(
      title: context.l10n.whyThisViewIsHelpful,
      summary: context.l10n.categoryWhyHelpfulDesc,
      points: [
        context.l10n.planningNewGoal,
        context.l10n.eyeingTreatYourself,
        context.l10n.doubleCheckTagging,
      ],
    ),
    _ScenarioSlideData(
      title: context.l10n.whatToDoWithTheInsight,
      summary: context.l10n.categoryWhatToDoDesc,
      points: [
        context.l10n.slideHighBar,
        context.l10n.nonNegotiable,
        context.l10n.revisitAfterScenario,
      ],
    ),
  ];
}

class _ScenarioHelpSlide extends StatelessWidget {
  const _ScenarioHelpSlide({
    required this.colorScheme,
    required this.title,
    required this.summary,
    required this.bullets,
  });

  final ColorScheme colorScheme;
  final String title;
  final String summary;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: TextStyle(
                fontSize: 14, height: 1.4, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.pie_chart, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
