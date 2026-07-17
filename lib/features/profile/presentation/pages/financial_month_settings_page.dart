import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/financial_period.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_cache_store.dart';
import 'package:moneko/features/utils/sub_page_top_padding.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_cache_store.dart';
import 'package:moneko/features/wallets/presentation/providers/wallets_lazy_providers.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinancialMonthSettingsPage extends HookConsumerWidget {
  const FinancialMonthSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(authProvider.select((user) => user.uid));
    final currentDay = ref.watch(financialMonthStartDayProvider);
    final isSaving = useState(false);

    // Page entrance animation controller
    final showAnimation = useAnimationController(
      duration: const Duration(milliseconds: 650),
    );

    useEffect(() {
      showAnimation.forward();
      return null;
    }, []);

    Future<void> saveStartDay(int day) async {
      if (isSaving.value || day == currentDay) return;

      final l10n = context.l10n;
      isSaving.value = true;
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'update-financial-month-start-day',
          body: {
            'userId': userId,
            'financialMonthStartDay': day,
          },
        );
        final data = response.data;
        final isSuccessful = response.status < 400 &&
            data is Map<String, dynamic> &&
            (data['ok'] == true || data['success'] == true);
        if (!isSuccessful) {
          throw Exception(l10n.serverRejectedFinancialMonthUpdate);
        }

        ref.read(analyticsProvider.notifier).updateFinancialMonthStartDay(day);
        ref.read(dashboardRefreshSignalProvider.notifier).state++;
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state++;
        ref.read(walletsRefreshSignalProvider.notifier).state++;
        ref.read(pocketsPersistedCacheBypassCountProvider.notifier).state++;
        ref.read(walletsPageStatePersistedCacheBypassProvider.notifier).state++;
        ref.read(analyticsProvider.notifier).refresh(userId);

        if (context.mounted) {
          AppToast.success(context, l10n.financialMonthStartUpdated);
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.error(
            context,
            l10n.couldNotUpdateFinancialMonth,
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    Future<void> editStartDay() async {
      if (isSaving.value) return;
      final day = await _showFinancialMonthDayPicker(
        context: context,
        selectedDay: currentDay,
      );
      if (day == null || day == currentDay) return;
      await saveStartDay(day);
    }

    final previewPeriod = financialCycleForDate(
      DateTime.now(),
      startDay: currentDay,
    );
    final localizations = MaterialLocalizations.of(context);
    final previewRange =
        '${localizations.formatMediumDate(previewPeriod.start)}'
        ' – ${localizations.formatMediumDate(previewPeriod.end)}';

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: context.l10n.financialMonth),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(16, getSubPageTopPadding(context), 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FadeInSlide(
                    controller: showAnimation,
                    index: 0,
                    child: _PageIntroduction(colorScheme: colorScheme),
                  ),
                  const SizedBox(height: 28),
                  _FadeInSlide(
                    controller: showAnimation,
                    index: 1,
                    child: _PeriodPreviewCard(
                      colorScheme: colorScheme,
                      selectedDay: currentDay,
                      previewRange: previewRange,
                      isSaving: isSaving.value,
                      onEdit: editStartDay,
                      previewPeriod: previewPeriod,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FadeInSlide(
                    controller: showAnimation,
                    index: 2,
                    child: _WhatChangesCard(colorScheme: colorScheme),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: currentDay > 28
                        ? _FadeInSlide(
                            controller: showAnimation,
                            index: 3,
                            child: _ShortMonthNote(
                              key: const ValueKey('short-month-note'),
                              colorScheme: colorScheme,
                              selectedDay: currentDay,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeInSlide extends StatelessWidget {
  const _FadeInSlide({
    required this.controller,
    required this.index,
    required this.child,
  });

  final AnimationController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final opacityAnimation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ));

    return FadeTransition(
      opacity: opacityAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }
}

class _PageIntroduction extends StatelessWidget {
  const _PageIntroduction({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer decorative shape with subtle rotation for premium design depth
            Transform.rotate(
              angle: 0.15,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            // Inner gradient icon circle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.16),
                    colorScheme.secondary.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.makeMonthMatchMoney,
          style: TextStyle(
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.financialMonthIntroDescription,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: colorScheme.mutedForeground,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PeriodPreviewCard extends StatelessWidget {
  const _PeriodPreviewCard({
    required this.colorScheme,
    required this.selectedDay,
    required this.previewRange,
    required this.isSaving,
    required this.onEdit,
    required this.previewPeriod,
  });

  final ColorScheme colorScheme;
  final int selectedDay;
  final String previewRange;
  final bool isSaving;
  final VoidCallback onEdit;
  final FinancialPeriod previewPeriod;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: colorScheme.brightness == Brightness.dark ? 0.0 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tear-off Calendar Sheet Widget
              _CalendarMockup(
                selectedDay: selectedDay,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.yourCurrentFinancialMonth,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        previewRange,
                        key: ValueKey(selectedDay),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.treatDatesAsOneMonth,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              // Interactive edit button with morphing loading state
              Semantics(
                button: true,
                label: context.l10n.editFinancialMonthStartDay,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isSaving
                        ? Padding(
                            key: const ValueKey('saving'),
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary,
                              ),
                            ),
                          )
                        : IconButton(
                            key: const ValueKey('edit'),
                            tooltip: context.l10n.editFinancialMonthStartDay,
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_rounded),
                            color: colorScheme.primary,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  colorScheme.primary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            iconSize: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 20),
          _CycleTimeline(
            colorScheme: colorScheme,
            start: previewPeriod.start,
            end: previewPeriod.end,
          ),
        ],
      ),
    );
  }
}

class _CalendarMockup extends StatelessWidget {
  const _CalendarMockup({
    required this.selectedDay,
    required this.colorScheme,
  });

  final int selectedDay;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 76,
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Spiral binder header line
          Container(
            height: 16,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (index) => Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$selectedDay',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleTimeline extends StatelessWidget {
  const _CycleTimeline({
    required this.colorScheme,
    required this.start,
    required this.end,
  });

  final ColorScheme colorScheme;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final totalDays = end.difference(start).inDays + 1;

    final today = dateOnly(DateTime.now());
    final elapsedDays = today.difference(start).inDays.clamp(0, totalDays - 1);

    // Progress calculation for timeline slider
    final progress = totalDays > 1 ? elapsedDays / (totalDays - 1) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations.formatMediumDate(start),
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              localizations.formatMediumDate(end),
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            // Align center of the dot with progress
            final dotPosition = progress * (trackWidth - 12);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Timeline Track
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.pocketProgressTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Active timeline progress fill
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Pulse dot indicating today
                Positioned(
                  left: dotPosition,
                  top: -3,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: colorScheme.cardSurface, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Day ${elapsedDays + 1} of $totalDays',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _WhatChangesCard extends StatelessWidget {
  const _WhatChangesCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: colorScheme.brightness == Brightness.dark ? 0.0 : 0.03,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.whatThisChanges,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          _ImpactTile(
            colorScheme: colorScheme,
            icon: Icons.donut_large_rounded,
            title: context.l10n.monthlyBudgetsAndPockets,
          ),
          _ImpactTile(
            colorScheme: colorScheme,
            icon: Icons.bar_chart_rounded,
            title: context.l10n.dashboardTotalsAndMonthlyCharts,
          ),
          _ImpactTile(
            colorScheme: colorScheme,
            icon: Icons.trending_up_rounded,
            title: context.l10n.walletSummariesInsightsAndReports,
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.savedTransactionsUnchangedNote,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactTile extends StatelessWidget {
  const _ImpactTile({
    required this.colorScheme,
    required this.icon,
    required this.title,
  });

  final ColorScheme colorScheme;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortMonthNote extends StatelessWidget {
  const _ShortMonthNote({
    super.key,
    required this.colorScheme,
    required this.selectedDay,
  });

  final ColorScheme colorScheme;
  final int selectedDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.warningSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.warningBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.shortMonthNote(selectedDay),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<int?> _showFinancialMonthDayPicker({
  required BuildContext context,
  required int selectedDay,
}) async {
  return await MonekoBottomSheet.show<int>(
    context: context,
    title: context.l10n.startFinancialMonthOn,
    onClose: () => Navigator.of(context).pop(),
    builder: (sheetContext) {
      return _DayPickerGrid(
        initialSelectedDay: selectedDay,
      );
    },
  );
}

class _DayPickerGrid extends HookWidget {
  const _DayPickerGrid({required this.initialSelectedDay});

  final int initialSelectedDay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedDay = useState(initialSelectedDay);
    final tappedDay = useState<int?>(null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  context.l10n.financialMonthStartDayLabel(selectedDay.value),
                  key: ValueKey(selectedDay.value),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.choiceSavesOnSelectDay,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = day == selectedDay.value;
              final isTapping = day == tappedDay.value;

              return _CalendarDayCell(
                day: day,
                isSelected: isSelected,
                isTapping: isTapping,
                colorScheme: colorScheme,
                onTap: () async {
                  if (tappedDay.value != null) return;
                  tappedDay.value = day;
                  selectedDay.value = day;
                  // Satisfying mobile physical haptics
                  await HapticFeedback.selectionClick();

                  // Pause briefly for high-end micro-interaction feedback before pop
                  await Future.delayed(const Duration(milliseconds: 220));
                  if (context.mounted) {
                    Navigator.of(context).pop(day);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isSelected,
    required this.isTapping,
    required this.colorScheme,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isTapping;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scaleVal = isSelected ? 1.05 : (isTapping ? 0.92 : 1.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(scaleVal, scaleVal, 1.0),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.primary.withValues(alpha: isTapping ? 0.08 : 0.0),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.15),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? colorScheme.primaryForeground
                : colorScheme.foreground,
          ),
        ),
      ),
    );
  }
}
