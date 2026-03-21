import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
import 'package:moneko/features/home/presentation/state/period_filter_provider.dart';
import 'package:moneko/features/home/presentation/state/period_selection.dart';

class PeriodSelectorBar extends ConsumerWidget {
  const PeriodSelectorBar({super.key, this.padding});

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selection = ref.watch(periodFilterProvider);
    final notifier = ref.read(periodFilterProvider.notifier);

    final title = _resolveTitle(context, selection);
    final items = _buildMenuItems(context, selection);

    final isMonthSelection = selection.kind == PeriodSelectionKind.month;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.border.withValues(alpha: 0.4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: colorScheme.foreground),
              onPressed:
                  isMonthSelection ? () => notifier.shiftMonth(-1) : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: colorScheme.foreground),
              onPressed: isMonthSelection ? () => notifier.shiftMonth(1) : null,
            ),
            AdaptivePopupMenuButton.widget(
              items: items,
              onSelected: (index, item) async {
                final value = item.value as String;
                if (value.startsWith('preset_')) {
                  final name = value.substring(7);
                  final preset = DateRangeFilter.values.firstWhere(
                    (e) => e.name == name,
                    orElse: () => DateRangeFilter.thisMonth,
                  );
                  await notifier.setPreset(preset);
                  return;
                }

                if (value == 'pick_month') {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDate: selection.month ?? DateTime.now(),
                  );
                  if (picked != null) {
                    await notifier.setMonth(picked);
                  }
                  return;
                }

                if (value == 'custom_range') {
                  final initial = _resolveCustomRange(selection);
                  final result = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDateRange: initial,
                  );
                  if (result != null) {
                    await notifier.setCustomRange(result.start, result.end);
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.tune_rounded, color: colorScheme.foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveTitle(BuildContext context, PeriodSelection selection) {
    switch (selection.kind) {
      case PeriodSelectionKind.month:
        final month = selection.month ?? DateTime.now();
        return DateFormat('MMMM yyyy').format(month);
      case PeriodSelectionKind.custom:
        final start = selection.customStart;
        final end = selection.customEnd;
        if (start == null || end == null) return context.l10n.customRange;
        final sameYear = start.year == end.year;
        final fmt = sameYear ? DateFormat('MMM d') : DateFormat('MMM d, yyyy');
        return '${fmt.format(start)} – ${fmt.format(end)}';
      case PeriodSelectionKind.preset:
        final preset = selection.preset ?? DateRangeFilter.thisMonth;
        return preset.getLabel(context);
    }
  }

  DateTimeRange? _resolveCustomRange(PeriodSelection selection) {
    if (selection.kind != PeriodSelectionKind.custom) return null;
    if (selection.customStart == null || selection.customEnd == null) {
      return null;
    }
    return DateTimeRange(
      start: selection.customStart!,
      end: selection.customEnd!,
    );
  }

  List<AdaptivePopupMenuItem> _buildMenuItems(
    BuildContext context,
    PeriodSelection selection,
  ) {
    final presets = [
      DateRangeFilter.thisMonth,
      DateRangeFilter.lastMonth,
      DateRangeFilter.last30Days,
      DateRangeFilter.thisYear,
      DateRangeFilter.allTime,
    ];

    return [
      ...presets.map((preset) {
        final isSelected = selection.kind == PeriodSelectionKind.preset &&
            selection.preset == preset;
        return AdaptivePopupMenuItem(
          label: preset.getLabel(context),
          icon: isSelected
              ? (PlatformInfo.isIOS26OrHigher() ? 'checkmark' : Icons.check)
              : null,
          value: 'preset_${preset.name}',
        );
      }),
      AdaptivePopupMenuItem(
        label: context.l10n.customRange,
        icon: selection.kind == PeriodSelectionKind.custom
            ? (PlatformInfo.isIOS26OrHigher() ? 'checkmark' : Icons.check)
            : null,
        value: 'custom_range',
      ),
      AdaptivePopupMenuItem(
        label: context.l10n.selectDateRange,
        icon:
            PlatformInfo.isIOS26OrHigher() ? 'calendar' : Icons.calendar_today,
        value: 'pick_month',
      ),
    ];
  }
}
