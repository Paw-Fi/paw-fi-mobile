import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class PlusLockedSheet extends HookConsumerWidget {
  const PlusLockedSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
      builder: (context) => const PlusLockedSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final subscription = ref.watch(subscriptionNotifierProvider).valueOrNull;
    final content = _LockedSheetContent.resolve(context, subscription);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(content.mode),
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: colorScheme.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: colorScheme.sheetBorder)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.paddingOf(context).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.mutedForeground.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SheetHero(content: content),
              const SizedBox(height: 20),
              _PlanComparisonTable(content: content.comparison),
              const SizedBox(height: 18),
              if (content.note != null) ...[
                _SheetNote(text: content.note!),
                const SizedBox(height: 18),
              ],
              PrimaryAdaptiveButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(
                    '/plan-selection?mode=trial&plan=premium&interval=yearly',
                  );
                },
                child: Text(content.ctaLabel),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.mutedForeground,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  context.l10n.plusLockedMaybeLaterCta,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

enum _LockedSheetMode { freeToPlus, trialToPlus, plusToPremium }

class _LockedSheetContent {
  const _LockedSheetContent({
    required this.mode,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.comparison,
    required this.ctaLabel,
    required this.ctaIcon,
    this.note,
  });

  final _LockedSheetMode mode;
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color Function(ColorScheme) iconBackground;
  final Color Function(ColorScheme) iconForeground;
  final _PlanComparisonContent comparison;
  final String ctaLabel;
  final IconData ctaIcon;
  final String? note;

  static _LockedSheetContent resolve(
      BuildContext context, Subscription? subscription) {
    if (isPlusPlan(subscription)) {
      return _premiumUpgrade(context);
    }
    if (isTrialingPlan(subscription)) {
      return _trialPlus(context);
    }
    return _freePlus(context);
  }

  static _LockedSheetContent _freePlus(BuildContext context) {
    return _LockedSheetContent(
      mode: _LockedSheetMode.freeToPlus,
      eyebrow: context.l10n.plusLockedUpgradeToPlusEyebrow,
      title: context.l10n.plusLockedTitle,
      description: context.l10n.plusLockedFreeDescription,
      icon: Icons.auto_awesome_rounded,
      iconBackground: (scheme) => scheme.primary.withValues(alpha: 0.12),
      iconForeground: (scheme) => scheme.primary,
      comparison: _plusPremiumComparison(
        context,
        highlightedColumn: 1,
        premiumBadge: context.l10n.plusLockedRecommendedBadge,
      ),
      ctaLabel: context.l10n.start7DayPremiumFreeTrial,
      ctaIcon: Icons.workspace_premium_rounded,
    );
  }

  static _LockedSheetContent _trialPlus(BuildContext context) {
    return _LockedSheetContent(
      mode: _LockedSheetMode.trialToPlus,
      eyebrow: context.l10n.plusLockedTrialEyebrow,
      title: context.l10n.plusLockedTrialTitle,
      description: context.l10n.plusLockedTrialRetentionDescription,
      icon: Icons.workspace_premium_rounded,
      iconBackground: (scheme) => scheme.warningSurface,
      iconForeground: (scheme) => scheme.warning,
      comparison: _plusPremiumComparison(
        context,
        featureHeader: context.l10n.plusLockedAfterTrialHeader,
        highlightedColumn: 0,
        plusBadge: context.l10n.plusLockedKeepAccessBadge,
      ),
      ctaLabel: context.l10n.start7DayPremiumFreeTrial,
      ctaIcon: Icons.check_circle_rounded,
      note: context.l10n.plusLockedTrialReviewPlansNote,
    );
  }

  static _LockedSheetContent _premiumUpgrade(BuildContext context) {
    return _LockedSheetContent(
      mode: _LockedSheetMode.plusToPremium,
      eyebrow: context.l10n.plusLockedPremiumFeatureEyebrow,
      title: context.l10n.plusLockedPremiumUpgradeTitle,
      description: context.l10n.plusLockedPremiumUpgradeDescription,
      icon: Icons.diamond_rounded,
      iconBackground: (scheme) => scheme.primary.withValues(alpha: 0.12),
      iconForeground: (scheme) => scheme.primary,
      comparison: _plusPremiumComparison(
        context,
        highlightedColumn: 1,
        plusBadge: context.l10n.plusLockedCurrentPlanBadge,
        premiumBadge: context.l10n.upgrade,
      ),
      ctaLabel: context.l10n.start7DayPremiumFreeTrial,
      ctaIcon: Icons.diamond_rounded,
      note: context.l10n.plusLockedPremiumSupportWithin12HoursNote,
    );
  }

  static _PlanComparisonContent _plusPremiumComparison(
    BuildContext context, {
    String? featureHeader,
    required int highlightedColumn,
    String? plusBadge,
    String? premiumBadge,
  }) {
    return _PlanComparisonContent(
      featureHeader: featureHeader ?? context.l10n.plusLockedFeatureHeader,
      columns: [
        _PlanColumn(title: context.l10n.plus, badge: plusBadge),
        _PlanColumn(title: context.l10n.premium, badge: premiumBadge),
      ],
      highlightedColumn: highlightedColumn,
      rows: [
        _ComparisonRowData(
          feature: context.l10n.plusLockedAiExpenseCapture,
          values: [
            _ComparisonValue.included(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.plusLockedMessagingAppCapture,
          values: [
            _ComparisonValue.included(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.plusLockedEmailReceiptImport,
          values: [
            _ComparisonValue.included(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.plusLockedSharedBudgets,
          values: [
            _ComparisonValue.included(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.plusLockedBankSync,
          values: [
            _ComparisonValue.excluded(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.multipleCurrencies,
          values: [
            _ComparisonValue.excluded(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.currencyConverter,
          values: [
            _ComparisonValue.excluded(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.plusLockedLiveExchangeRates,
          values: [
            _ComparisonValue.excluded(),
            _ComparisonValue.included(),
          ],
        ),
        _ComparisonRowData(
          feature: context.l10n.customerSupport,
          values: [
            _ComparisonValue.text(context.l10n.plusLockedStandardSupport),
            _ComparisonValue.text(context.l10n.plusLockedPrioritySupport),
          ],
        ),
      ],
    );
  }
}

class _SheetHero extends StatelessWidget {
  const _SheetHero({required this.content});

  final _LockedSheetContent content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.sheetElementBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorScheme.border),
          ),
          child: Text(
            content.eyebrow,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: content.iconBackground(colorScheme),
            shape: BoxShape.circle,
          ),
          child: Icon(
            content.icon,
            size: 34,
            color: content.iconForeground(colorScheme),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          content.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colorScheme.foreground,
            height: 1.12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          content.description,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: colorScheme.mutedForeground,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.infoSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.infoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: colorScheme.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: colorScheme.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanComparisonContent {
  const _PlanComparisonContent({
    required this.featureHeader,
    required this.columns,
    required this.rows,
    required this.highlightedColumn,
  });

  final String featureHeader;
  final List<_PlanColumn> columns;
  final List<_ComparisonRowData> rows;
  final int highlightedColumn;
}

class _PlanColumn {
  const _PlanColumn({required this.title, this.badge});

  final String title;
  final String? badge;
}

class _ComparisonRowData {
  const _ComparisonRowData({
    required this.feature,
    required this.values,
  });

  final String feature;
  final List<_ComparisonValue> values;
}

class _ComparisonValue {
  const _ComparisonValue._({
    this.label,
    required this.included,
  });

  factory _ComparisonValue.included() => const _ComparisonValue._(
        included: true,
      );

  factory _ComparisonValue.excluded() => const _ComparisonValue._(
        included: false,
      );

  factory _ComparisonValue.text(String label) => _ComparisonValue._(
        label: label,
        included: null,
      );

  final String? label;
  final bool? included;
}

class _PlanComparisonTable extends StatelessWidget {
  const _PlanComparisonTable({required this.content});

  final _PlanComparisonContent content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.sheetElementBackground,
          border: Border.all(color: colorScheme.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            _PlanComparisonHeader(content: content),
            for (var index = 0; index < content.rows.length; index++)
              _PlanComparisonRow(
                data: content.rows[index],
                highlightedColumn: content.highlightedColumn,
                isLast: index == content.rows.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanComparisonHeader extends StatelessWidget {
  const _PlanComparisonHeader({required this.content});

  final _PlanComparisonContent content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.border.withValues(alpha: 0.7)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Text(
                  content.featureHeader,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
            for (var index = 0; index < content.columns.length; index++)
              Expanded(
                flex: 3,
                child: _PlanHeaderCell(
                  column: content.columns[index],
                  highlighted: index == content.highlightedColumn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanHeaderCell extends StatelessWidget {
  const _PlanHeaderCell({
    required this.column,
    required this.highlighted,
  });

  final _PlanColumn column;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = highlighted
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surface.withValues(alpha: 0.0);

    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            column.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: highlighted ? colorScheme.primary : colorScheme.foreground,
            ),
          ),
          if (column.badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: highlighted
                    ? colorScheme.primary
                    : colorScheme.muted.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                column.badge!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: highlighted
                      ? colorScheme.primaryForeground
                      : colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanComparisonRow extends StatelessWidget {
  const _PlanComparisonRow({
    required this.data,
    required this.highlightedColumn,
    required this.isLast,
  });

  final _ComparisonRowData data;
  final int highlightedColumn;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: colorScheme.border.withValues(alpha: 0.5),
                ),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                child: Text(
                  data.feature,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            for (var index = 0; index < data.values.length; index++)
              Expanded(
                flex: 3,
                child: _ComparisonValueCell(
                  value: data.values[index],
                  highlighted: index == highlightedColumn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonValueCell extends StatelessWidget {
  const _ComparisonValueCell({
    required this.value,
    required this.highlighted,
  });

  final _ComparisonValue value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = highlighted
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surface.withValues(alpha: 0.0);

    final child = switch (value.included) {
      true => Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: highlighted ? colorScheme.primary : colorScheme.success,
        ),
      false => Icon(
          Icons.cancel_rounded,
          size: 19,
          color: colorScheme.mutedForeground.withValues(alpha: 0.55),
        ),
      null => Text(
          value.label ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color:
                highlighted ? colorScheme.primary : colorScheme.mutedForeground,
          ),
        ),
    };

    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      alignment: Alignment.center,
      child: child,
    );
  }
}
