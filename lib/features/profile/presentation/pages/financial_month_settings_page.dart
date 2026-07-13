import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
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
import 'package:moneko/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinancialMonthSettingsPage extends HookConsumerWidget {
  const FinancialMonthSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(authProvider.select((user) => user.uid));
    final currentDay = ref.watch(financialMonthStartDayProvider);
    final isSaving = useState(false);

    Future<void> saveStartDay(int day) async {
      if (isSaving.value || day == currentDay) return;

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
          throw Exception(context.l10n.serverRejectedFinancialMonthUpdate);
        }

        ref.read(analyticsProvider.notifier).updateFinancialMonthStartDay(day);
        ref.read(dashboardRefreshSignalProvider.notifier).state++;
        ref.read(transactionsFeedRefreshSignalProvider.notifier).state++;
        ref.read(walletsRefreshSignalProvider.notifier).state++;
        ref.read(pocketsPersistedCacheBypassCountProvider.notifier).state++;
        ref.read(walletsPageStatePersistedCacheBypassProvider.notifier).state++;
        ref.read(analyticsProvider.notifier).refresh(userId);

        if (context.mounted) {
          AppToast.success(context, context.l10n.financialMonthStartUpdated);
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.error(
            context,
            context.l10n.couldNotUpdateFinancialMonth,
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
          padding:  EdgeInsets.fromLTRB(16, getSubPageTopPadding(context), 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageIntroduction(colorScheme: colorScheme),
                  const SizedBox(height: 28),
                  _PeriodPreviewCard(
                    colorScheme: colorScheme,
                    selectedDay: currentDay,
                    previewRange: previewRange,
                    isSaving: isSaving.value,
                    onEdit: editStartDay,
                  ),
                  const SizedBox(height: 16),
                  _WhatChangesCard(colorScheme: colorScheme),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: currentDay > 28
                        ? _ShortMonthNote(
                            key: const ValueKey('short-month-note'),
                            colorScheme: colorScheme,
                            selectedDay: currentDay,
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

class _PageIntroduction extends StatelessWidget {
  const _PageIntroduction({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.calendar_month_rounded,
            size: 36,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.makeMonthMatchMoney,
          style: TextStyle(
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: colorScheme.foreground,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.financialMonthIntroDescription,
          style: TextStyle(
            fontSize: 16,
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
  });

  final ColorScheme colorScheme;
  final int selectedDay;
  final String previewRange;
  final bool isSaving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.date_range_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.yourCurrentFinancialMonth,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Semantics(
                      button: true,
                      label: context.l10n.editFinancialMonthStartDay,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: isSaving
                              ? Padding(
                                  key: const ValueKey('saving'),
                                  padding: const EdgeInsets.all(12),
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
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
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    previewRange,
                    key: ValueKey(selectedDay),
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.l10n.treatDatesAsOneMonth,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.mutedForeground,
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

Future<int?> _showFinancialMonthDayPicker({
  required BuildContext context,
  required int selectedDay,
}) async {
  const itemExtent = 56.0;
  final scrollController = ScrollController(
    initialScrollOffset: (selectedDay - 1) * itemExtent,
  );
  try {
    return await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.sheetBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: colorScheme.sheetBorder)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.sheetBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sheetContext.l10n.startFinancialMonthOn,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.foreground,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              sheetContext.l10n.choiceSavesOnSelectDay,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: sheetContext.l10n.close,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: colorScheme.mutedForeground,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.sheetBorder),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemExtent: itemExtent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: 31,
                    itemBuilder: (context, index) {
                      final day = index + 1;
                      final isSelected = day == selectedDay;
                      return ListTile(
                        title: Text(
                          context.l10n.financialMonthStartDayLabel(day),
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: colorScheme.foreground,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: colorScheme.primary,
                              )
                            : null,
                        selected: isSelected,
                        selectedTileColor:
                            colorScheme.primary.withValues(alpha: 0.08),
                        onTap: () => Navigator.of(sheetContext).pop(day),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    scrollController.dispose();
  }
}

class _WhatChangesCard extends StatelessWidget {
  const _WhatChangesCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.whatThisChanges,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 12),
          _ImpactRow(
            colorScheme: colorScheme,
            text: context.l10n.monthlyBudgetsAndPockets,
          ),
          _ImpactRow(
            colorScheme: colorScheme,
            text: context.l10n.dashboardTotalsAndMonthlyCharts,
          ),
          _ImpactRow(
            colorScheme: colorScheme,
            text: context.l10n.walletSummariesInsightsAndReports,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colorScheme.border),
          const SizedBox(height: 12),
          Text(
            context.l10n.savedTransactionsUnchangedNote,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({required this.colorScheme, required this.text});

  final ColorScheme colorScheme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 19,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colorScheme.mutedForeground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.shortMonthNote(selectedDay),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colorScheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
