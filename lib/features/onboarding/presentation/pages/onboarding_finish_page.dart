import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class OnboardingFinishPage extends StatelessWidget {
  const OnboardingFinishPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlights = <_HighlightItemData>[
      _HighlightItemData(
        icon: Icons.auto_awesome_rounded,
        title: context.l10n.onboardingFinishHighlightCaptureTitle,
        body: context.l10n.onboardingFinishHighlightCaptureBody,
      ),
      _HighlightItemData(
        icon: Icons.inbox_rounded,
        title: context.l10n.onboardingFinishHighlightPocketsTitle,
        body: context.l10n.onboardingFinishHighlightPocketsBody,
      ),
      _HighlightItemData(
        icon: Icons.people_alt_rounded,
        title: context.l10n.onboardingFinishHighlightHouseholdTitle,
        body: context.l10n.onboardingFinishHighlightHouseholdBody,
      ),
      _HighlightItemData(
        icon: Icons.query_stats_rounded,
        title: context.l10n.onboardingFinishHighlightInsightsTitle,
        body: context.l10n.onboardingFinishHighlightInsightsBody,
      ),
    ];

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.startLoggingExpenses,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.startLoggingExpensesToSeeCategories,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 46,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const Spacer(),
                              _HighlightsSection(
                                highlights: highlights,
                                header: context.l10n.onboardingFinishNextUp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: PrimaryAdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      context.l10n.start,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.highlights, required this.header});

  final List<_HighlightItemData> highlights;
  final String header;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tiles = List<Widget>.generate(highlights.length * 2 - 1, (index) {
      if (index.isOdd) {
        return Padding(
          padding: const EdgeInsets.only(left: 76),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.border.withValues(alpha: 0.2),
          ),
        );
      }
      final item = highlights[index ~/ 2];
      return _HighlightTile(item: item);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          header.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: colorScheme.brightness == Brightness.dark
                ? null
                : [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.item});

  final _HighlightItemData item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 12,
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
}

class _HighlightItemData {
  const _HighlightItemData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
