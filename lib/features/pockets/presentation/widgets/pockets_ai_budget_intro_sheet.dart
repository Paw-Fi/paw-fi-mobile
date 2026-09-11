import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/presentation/pages/pockets_ai_budget_suggestions_page.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PocketsAiBudgetIntroSheet extends HookConsumerWidget {
  const PocketsAiBudgetIntroSheet({
    super.key,
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required PocketsScopeParams scopeParams,
    required String currency,
  }) =>
      MonekoBottomSheet.show<void>(
        context: context,
        title: context.l10n.pocketsAiIntroTitle,
        isScrollControlled: true,
        onClose: () => Navigator.of(context).pop(),
        builder: (_) => PocketsAiBudgetIntroSheet(
          scopeParams: scopeParams,
          currency: currency,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pageController = usePageController(viewportFraction: 0.94);
    final currentPage = useState(0);
    final pageHeights = useState<Map<int, double>>({});

    String? rawCreatedAt;
    try {
      rawCreatedAt = Supabase.instance.client.auth.currentUser?.createdAt;
    } catch (_) {}
    final createdAt =
        rawCreatedAt != null ? DateTime.tryParse(rawCreatedAt) : null;
    final now = DateTime.now();
    final monthsJoined = createdAt != null
        ? ((now.year - createdAt.year) * 12 + now.month - createdAt.month)
        : 0;

    final cardData = useMemoized<List<_FlashCardItem>>(() {
      final String card1Title;
      final String card1Body;
      final String card1Highlight;
      if (monthsJoined <= 0) {
        card1Title = context.l10n.pocketsAiIntroCard1TitleNew;
        card1Body = context.l10n.pocketsAiIntroCard1BodyNew;
        card1Highlight = context.l10n.pocketsAiIntroCard1HighlightNew;
      } else if (monthsJoined == 1) {
        card1Title = context.l10n.pocketsAiIntroCard1TitleOneMonth;
        card1Body = context.l10n.pocketsAiIntroCard1BodyOneMonth;
        card1Highlight = context.l10n.pocketsAiIntroCard1HighlightMonths;
      } else {
        card1Title = context.l10n.pocketsAiIntroCard1TitleMonths(monthsJoined);
        card1Body = context.l10n.pocketsAiIntroCard1BodyMonths(monthsJoined);
        card1Highlight = context.l10n.pocketsAiIntroCard1HighlightMonths;
      }

      return [
        _FlashCardItem(
          tag: context.l10n.pocketsAiIntroMilestoneTag,
          tagIcon: Icons.military_tech_rounded,
          heroIcon: Icons.celebration_rounded,
          title: card1Title,
          body: card1Body,
          highlight: card1Highlight,
        ),
        _FlashCardItem(
          tag: context.l10n.pocketsAiIntroCard2Tag,
          tagIcon: Icons.insights_rounded,
          heroIcon: Icons.calendar_month_rounded,
          title: context.l10n.pocketsAiIntroCard2Title,
          body: context.l10n.pocketsAiIntroCard2Body,
          highlight: context.l10n.pocketsAiIntroCard2Highlight,
        ),
        _FlashCardItem(
          tag: context.l10n.pocketsAiIntroCard3Tag,
          tagIcon: Icons.auto_awesome_rounded,
          heroIcon: Icons.auto_awesome_rounded,
          title: context.l10n.pocketsAiIntroCard3Title,
          body: context.l10n.pocketsAiIntroCard3Body,
          highlight: context.l10n.pocketsAiIntroCard3Highlight,
        ),
      ];
    }, [monthsJoined, context.l10n]);

    useEffect(() {
      void onPageChange() {
        if (!pageController.hasClients) return;
        final page = pageController.page?.round() ?? 0;
        if (currentPage.value != page) {
          currentPage.value = page;
        }
      }

      pageController.addListener(onPageChange);
      return () => pageController.removeListener(onPageChange);
    }, [pageController]);

    final activeHeight = pageHeights.value[currentPage.value] ?? 320.0;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: activeHeight,
                child: PageView.builder(
                  controller: pageController,
                  itemCount: cardData.length,
                  onPageChanged: (index) => currentPage.value = index,
                  itemBuilder: (context, index) {
                    final item = cardData[index];
                    return OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: _MeasureSize(
                        onChange: (size) {
                          if (pageHeights.value[index] != size.height) {
                            pageHeights.value = {
                              ...pageHeights.value,
                              index: size.height,
                            };
                          }
                        },
                        child: _FlashCardView(
                          item: item,
                          index: index,
                          totalCount: cardData.length,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cardData.length, (index) {
                final isSelected = currentPage.value == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.25),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            PrimaryAdaptiveButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (!context.mounted) return;
                await PocketsAiBudgetSuggestionsPage.openIfEntitled(
                  context,
                  ref,
                  scopeParams: scopeParams,
                  currency: currency,
                );
              },
              child: Text(
                context.l10n.pocketsAiIntroAction(
                  formatLocalizedMonth(
                    context,
                    DateTime.now(),
                    abbreviated: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            PlainAdaptiveButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.pocketsAiIntroManualAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashCardItem {
  const _FlashCardItem({
    required this.tag,
    required this.tagIcon,
    required this.heroIcon,
    required this.title,
    required this.body,
    required this.highlight,
  });

  final String tag;
  final IconData tagIcon;
  final IconData heroIcon;
  final String title;
  final String body;
  final String highlight;
}

class _FlashCardView extends StatelessWidget {
  const _FlashCardView({
    required this.item,
    required this.index,
    required this.totalCount,
    required this.colorScheme,
    required this.textTheme,
  });

  final _FlashCardItem item;
  final int index;
  final int totalCount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.tag.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              Text(
                '${index + 1} / $totalCount',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.48,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.highlight,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required this.onChange,
    required super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderMeasureSize renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_oldSize != newSize) {
      _oldSize = newSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onChange(newSize);
      });
    }
  }
}
