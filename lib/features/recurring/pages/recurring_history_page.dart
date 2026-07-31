import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/date_formatter.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/state.dart'
    show analyticsProvider;
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/utils/recurring_occurrence_schedule.dart';
import 'package:moneko/features/recurring/presentation/widgets/confirm_recurring_occurrence_sheet.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

enum _HistoryFilter { all, paid, pending }

/// Dedicated Apple-inspired page for viewing full payment history & upcoming schedule
class RecurringHistoryPage extends HookConsumerWidget {
  final RecurringTransaction transaction;

  const RecurringHistoryPage({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeFilter = useState<_HistoryFilter>(_HistoryFilter.all);
    final locallySkippedDates = useState<Set<String>>(<String>{});

    final preferredTimezone = ref
        .watch(analyticsProvider.select((s) => s.contact?.preferredTimezone));
    final userNow = effectiveNow(preferredTimezone: preferredTimezone);
    final userToday = DateTime(userNow.year, userNow.month, userNow.day);
    final nextOccurrence = transaction.serverNextOccurrenceDate ??
        transaction.getNextOccurrence(
          userToday.subtract(const Duration(days: 1)),
        );

    final description = transaction.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final localizedCategory =
        getCategoryTranslation(context, transaction.category);
    final title = hasDescription ? description : localizedCategory;

    final categoryColor = getCategoryColor(transaction.category, context);
    final adaptedCategoryColor =
        AppTheme.adaptCategoryColorForTheme(categoryColor, colorScheme);
    final categoryIcon = getCategoryIcon(transaction.category);

    final isIncome = transaction.type == 'income';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? colorScheme.success : colorScheme.foreground;
    final normalizedAmount = double.parse(formatAmount(transaction.amount));
    final localizedNumber = formatLocalizedNumber(context, normalizedAmount);
    final currencySymbol = resolveCurrencySymbol(transaction.currency);
    final amountText = '$sign$currencySymbol$localizedNumber';

    final userId = ref.watch(authProvider).uid;
    final historyQuery = RecurringOccurrenceHistoryQuery(
      userId: userId,
      recurringId: transaction.id,
    );
    final history = userId.isEmpty
        ? const AsyncValue<RecurringOccurrenceHistoryState>.data(
            RecurringOccurrenceHistoryState(
              items: [],
              hasMore: false,
              nextCursor: null,
            ),
          )
        : ref.watch(recurringOccurrenceHistoryProvider(historyQuery));
    final historyState = history.valueOrNull;
    final fullRangeTimeline = (historyState?.items ?? const [])
        .map((item) => RecurringOccurrenceTimelineItem(
              occurrenceId: item.id,
              scheduledOccurrenceDate: item.scheduledOccurrenceDate,
              status: item.status,
              paidDate: item.paidDate,
              amountCents: item.amountCents,
              currency: item.currency,
              confirmedAt: item.confirmedAt,
              confirmationSource: item.confirmationSource,
            ))
        .toList(growable: false);
    final latestServerActionable =
        transaction.serverLatestActionableOccurrenceDate;
    final eligibleOccurrences = latestServerActionable == null
        ? const <DateTime>[]
        : <DateTime>[latestServerActionable];

    final occurrencesByDate = <String, DateTime>{
      for (final occurrence in eligibleOccurrences)
        formatDateOnlyYmd(occurrence): occurrence,
      for (final item in fullRangeTimeline)
        formatDateOnlyYmd(item.scheduledOccurrenceDate):
            item.scheduledOccurrenceDate,
      for (final excludedDate
          in transaction.recurrenceRule?.excludedDates ?? const <DateTime>[])
        formatDateOnlyYmd(excludedDate): excludedDate,
    };
    final occurrences = occurrencesByDate.values.toList(growable: false)
      ..sort();

    final timelineByDate = <String, RecurringOccurrenceTimelineItem>{
      for (final item in fullRangeTimeline)
        formatDateOnlyYmd(item.scheduledOccurrenceDate): item,
    };
    for (final excludedDate
        in transaction.recurrenceRule?.excludedDates ?? const <DateTime>[]) {
      timelineByDate.putIfAbsent(
        formatDateOnlyYmd(excludedDate),
        () => RecurringOccurrenceTimelineItem(
          scheduledOccurrenceDate: excludedDate,
          status: 'skipped',
        ),
      );
    }

    final latestUnconfirmedOccurrence = eligibleOccurrences.where((occurrence) {
      final item = timelineByDate[formatDateOnlyYmd(occurrence)];
      return item?.isConfirmed != true &&
          item?.isSkipped != true &&
          !locallySkippedDates.value.contains(formatDateOnlyYmd(occurrence));
    }).fold<DateTime?>(null, (latest, occurrence) {
      if (latest == null || occurrence.isAfter(latest)) return occurrence;
      return latest;
    });
    final futureReference = latestUnconfirmedOccurrence != null &&
            formatDateOnlyYmd(latestUnconfirmedOccurrence) ==
                formatDateOnlyYmd(nextOccurrence)
        ? null
        : nextOccurrence;
    final nextDueOccurrence =
        latestUnconfirmedOccurrence ?? futureReference ?? nextOccurrence;

    double totalCumulativeAmount = 0.0;
    int paidCyclesCount = 0;

    for (final occurrence in occurrences) {
      final dateStr = formatDateOnlyYmd(occurrence);
      final item = timelineByDate[dateStr];
      final double occAmount = item?.amountCents != null
          ? (item!.amountCents! / 100.0)
          : transaction.amount;

      if (item?.isConfirmed == true || item?.isSkipped == true) {
        paidCyclesCount++;
      }
      if (item?.isConfirmed == true) {
        totalCumulativeAmount += occAmount;
      }
    }

    final totalCumulativeText =
        '$sign$currencySymbol${formatLocalizedNumber(context, double.parse(formatAmount(totalCumulativeAmount)))}';

    final reversedOccurrences = mergeRecurringHistoryOccurrenceDates(
      futureReference: futureReference,
      occurrences: occurrences,
    );
    final filteredList = reversedOccurrences.where((occurrence) {
      final dateString = formatDateOnlyYmd(occurrence);
      final item = timelineByDate[dateString];
      final isResolved = item?.isConfirmed == true || item?.isSkipped == true;

      if (activeFilter.value == _HistoryFilter.paid) {
        return isResolved;
      }
      if (activeFilter.value == _HistoryFilter.pending) {
        return !isResolved;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              context.l10n.paymentHistoryAndUpcoming,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            AsyncRefreshStrip(
              isRefreshing: historyState?.isRefreshing == true,
            ),
            Expanded(
              child: history.hasError && !history.hasValue
                  ? Center(
                      child: OutlinedButton(
                        onPressed: () => ref.invalidate(
                          recurringOccurrenceHistoryProvider(historyQuery),
                        ),
                        child: Text(context.l10n.retry),
                      ),
                    )
                  : Skeletonizer(
                      enabled: history.isLoading && !history.hasValue,
                      effect: ShimmerEffect(
                        baseColor: colorScheme.skeletonBase,
                        highlightColor: colorScheme.skeletonHighlight,
                      ),
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Header Hero Card
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.homeCardSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.homeCardBorder,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.homeCardShadow,
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Category Icon with glow
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: adaptedCategoryColor
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: adaptedCategoryColor
                                                  .withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            categoryIcon,
                                            color: adaptedCategoryColor,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                  color: colorScheme.foreground,
                                                  letterSpacing: -0.4,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                hasDescription
                                                    ? '$localizedCategory · ${getLocalizedFrequencyText(context, transaction)}'
                                                    : getLocalizedFrequencyText(
                                                        context, transaction),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: colorScheme
                                                      .mutedForeground,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              context.l10n.total,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    colorScheme.mutedForeground,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              totalCumulativeText,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: amountColor,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Divider(
                                      height: 1,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.08),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem(
                                          context,
                                          colorScheme,
                                          label: context.l10n.perCycle,
                                          value: amountText,
                                          valueColor: colorScheme.foreground,
                                        ),
                                        _buildStatItem(
                                          context,
                                          colorScheme,
                                          label: context.l10n.totalCycles,
                                          value: '${occurrences.length}',
                                        ),
                                        _buildStatItem(
                                          context,
                                          colorScheme,
                                          label: context.l10n.nextDue,
                                          value: formatLocalizedDate(
                                              context, nextDueOccurrence),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Segmented Control / Filter Row
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    context,
                                    colorScheme,
                                    label: context.l10n.all,
                                    isSelected: activeFilter.value ==
                                        _HistoryFilter.all,
                                    count: occurrences.length,
                                    onTap: () =>
                                        activeFilter.value = _HistoryFilter.all,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    context,
                                    colorScheme,
                                    label: context.l10n.paid,
                                    isSelected: activeFilter.value ==
                                        _HistoryFilter.paid,
                                    count: paidCyclesCount,
                                    onTap: () => activeFilter.value =
                                        _HistoryFilter.paid,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    context,
                                    colorScheme,
                                    label: context.l10n.pending,
                                    isSelected: activeFilter.value ==
                                        _HistoryFilter.pending,
                                    count: occurrences.length - paidCyclesCount,
                                    onTap: () => activeFilter.value =
                                        _HistoryFilter.pending,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Timeline Occurrences List
                          if (filteredList.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 60),
                                child: Center(
                                  child: Text(
                                    context.l10n.noTransactionsFound,
                                    style: TextStyle(
                                      color: colorScheme.mutedForeground,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final occurrence = filteredList[index];
                                    final isLast =
                                        index == filteredList.length - 1;
                                    final dateString =
                                        formatDateOnlyYmd(occurrence);

                                    final timelineItem =
                                        timelineByDate[dateString];
                                    final isConfirmed =
                                        timelineItem?.isConfirmed == true;
                                    final isSkipped =
                                        timelineItem?.isSkipped == true;

                                    final formattedDate = formatLocalizedDate(
                                        context, occurrence);
                                    final isFutureReference = futureReference !=
                                            null &&
                                        occurrence.year ==
                                            futureReference.year &&
                                        occurrence.month ==
                                            futureReference.month &&
                                        occurrence.day == futureReference.day;
                                    final isActionableConfirmation =
                                        !isSkipped &&
                                            latestUnconfirmedOccurrence !=
                                                null &&
                                            occurrence.year ==
                                                latestUnconfirmedOccurrence
                                                    .year &&
                                            occurrence.month ==
                                                latestUnconfirmedOccurrence
                                                    .month &&
                                            occurrence.day ==
                                                latestUnconfirmedOccurrence.day;
                                    final isUpcoming = isFutureReference;

                                    final occurrenceDateOnly = DateTime(
                                      occurrence.year,
                                      occurrence.month,
                                      occurrence.day,
                                    );
                                    final daysDifference = occurrenceDateOnly
                                        .difference(userToday)
                                        .inDays;
                                    final isOverdue =
                                        daysDifference < 0 && !isConfirmed;

                                    final String dueText = daysDifference == 0
                                        ? context.l10n.dueTodayStatus
                                        : daysDifference == 1
                                            ? context.l10n.dueTomorrowStatus
                                            : daysDifference > 1
                                                ? context.l10n.dueInDaysStatus(
                                                    daysDifference)
                                                : context.l10n
                                                    .overdueByDaysStatus(
                                                        -daysDifference);

                                    final Color nodeColor = isConfirmed
                                        ? colorScheme.success
                                        : (isSkipped
                                            ? colorScheme.mutedForeground
                                            : (isUpcoming
                                                ? (isOverdue
                                                    ? colorScheme.destructive
                                                    : colorScheme.primary)
                                                : colorScheme.mutedForeground));

                                    final IconData nodeIcon = isConfirmed
                                        ? Icons.check_circle_rounded
                                        : (isSkipped
                                            ? Icons.remove_circle_outline
                                            : (isUpcoming
                                                ? (isOverdue
                                                    ? Icons
                                                        .error_outline_rounded
                                                    : Icons.schedule_rounded)
                                                : Icons.circle_outlined));

                                    final paidDate = timelineItem?.paidDate;
                                    final paidDateFormatted = paidDate != null
                                        ? formatLocalizedDate(context, paidDate)
                                        : null;
                                    final confirmedDateText = timelineItem
                                                ?.isImported ==
                                            true
                                        ? 'Imported payment'
                                        : (paidDate != null &&
                                                formatDateOnlyYmd(paidDate) !=
                                                    dateString)
                                            ? context.l10n.paidStatusOn(
                                                paidDateFormatted!)
                                            : context.l10n.paid;

                                    final onTileTap = isConfirmed
                                        ? () =>
                                            showLazyRecurringOccurrenceSheet(
                                              context: context,
                                              recurringTransaction: transaction,
                                              occurrence: timelineItem!,
                                            )
                                        : isActionableConfirmation
                                            ? () =>
                                                showConfirmRecurringOccurrenceSheet(
                                                  context: context,
                                                  recurringTransaction:
                                                      transaction,
                                                  scheduledOccurrenceDate:
                                                      occurrence,
                                                )
                                            : null;

                                    Future<void> skipOccurrence() async {
                                      final result =
                                          await MonekoAlertDialog.show(
                                        context: context,
                                        title: context.l10n.skipNextOccurrence,
                                        description: null,
                                        confirmLabel: context.l10n.skip,
                                        cancelLabel: context.l10n.cancel,
                                        isDestructive: true,
                                      );
                                      if (result == null ||
                                          result.action ==
                                              MonekoAlertDialogAction.cancel) {
                                        return;
                                      }
                                      final success = await ref
                                          .read(recurringTransactionsProvider(
                                                  transaction.householdId)
                                              .notifier)
                                          .skipOccurrence(
                                            userId,
                                            transaction.id,
                                            occurrence,
                                            transaction: transaction,
                                          );
                                      if (!context.mounted) return;
                                      if (success.success) {
                                        locallySkippedDates.value = {
                                          ...locallySkippedDates.value,
                                          formatDateOnlyYmd(occurrence),
                                        };
                                        ref.invalidate(
                                          recurringOccurrenceHistoryProvider(
                                              historyQuery),
                                        );
                                        return;
                                      }
                                      AppToast.error(
                                        context,
                                        success.error ??
                                            'Unable to skip occurrence.',
                                      );
                                    }

                                    return IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            width: 28,
                                            child: Column(
                                              children: [
                                                const SizedBox(
                                                  height: 6,
                                                ),
                                                if (isConfirmed)
                                                  Container(
                                                    width: 18,
                                                    height: 18,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          colorScheme.success,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.check_rounded,
                                                      size: 12,
                                                      color:
                                                          colorScheme.onPrimary,
                                                    ),
                                                  )
                                                else
                                                  Icon(
                                                    nodeIcon,
                                                    size: 18,
                                                    color: nodeColor,
                                                  ),
                                                if (!isLast)
                                                  Expanded(
                                                    child: Container(
                                                      width: 2,
                                                      margin: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(1),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: InkWell(
                                              onTap: onTileTap,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 12),
                                                padding:
                                                    const EdgeInsets.all(14),
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .homeCardSurface,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isUpcoming &&
                                                            !isConfirmed
                                                        ? (isOverdue
                                                            ? colorScheme
                                                                .destructive
                                                                .withValues(
                                                                    alpha: 0.4)
                                                            : colorScheme
                                                                .primary
                                                                .withValues(
                                                                    alpha: 0.4))
                                                        : colorScheme
                                                            .homeCardBorder,
                                                    width: 1,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: colorScheme
                                                          .homeCardShadow,
                                                      blurRadius: 12,
                                                      offset:
                                                          const Offset(0, 2),
                                                      spreadRadius: -2,
                                                    ),
                                                  ],
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          formattedDate,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: colorScheme
                                                                .foreground,
                                                          ),
                                                        ),
                                                        Text(
                                                          isConfirmed &&
                                                                  timelineItem
                                                                          ?.amountCents !=
                                                                      null
                                                              ? '$sign$currencySymbol${formatLocalizedNumber(context, timelineItem!.amountCents! / 100)}'
                                                              : amountText,
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: amountColor,
                                                            fontFamily:
                                                                'monospace',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    if (isActionableConfirmation &&
                                                        !isConfirmed)
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 8,
                                                              vertical: 3,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: (isOverdue
                                                                      ? colorScheme
                                                                          .destructive
                                                                      : colorScheme
                                                                          .primary)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.12),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  isOverdue
                                                                      ? Icons
                                                                          .warning_amber_rounded
                                                                      : Icons
                                                                          .autorenew_rounded,
                                                                  size: 12,
                                                                  color: isOverdue
                                                                      ? colorScheme
                                                                          .destructive
                                                                      : colorScheme
                                                                          .primary,
                                                                ),
                                                                const SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  dueText,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: isOverdue
                                                                        ? colorScheme
                                                                            .destructive
                                                                        : colorScheme
                                                                            .primary,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          InkWell(
                                                            onTap: () =>
                                                                showConfirmRecurringOccurrenceSheet(
                                                              context: context,
                                                              recurringTransaction:
                                                                  transaction,
                                                              scheduledOccurrenceDate:
                                                                  occurrence,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        100),
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 12,
                                                                vertical: 4,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color:
                                                                    colorScheme
                                                                        .primary,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            100),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .check_rounded,
                                                                    size: 12,
                                                                    color: colorScheme
                                                                        .onPrimary,
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Text(
                                                                    context.l10n
                                                                        .confirmPayment,
                                                                    style:
                                                                        TextStyle(
                                                                      color: colorScheme
                                                                          .onPrimary,
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    else if (isSkipped)
                                                      Text('Skipped',
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: colorScheme
                                                                  .mutedForeground,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600))
                                                    else if (isConfirmed)
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            confirmedDateText,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: colorScheme
                                                                  .success,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    else
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(dueText,
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: colorScheme
                                                                      .mutedForeground,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w400)),
                                                          if (isFutureReference)
                                                            TextButton(
                                                              onPressed: userId
                                                                      .isEmpty
                                                                  ? null
                                                                  : skipOccurrence,
                                                              style: TextButton
                                                                  .styleFrom(
                                                                minimumSize:
                                                                    Size.zero,
                                                                tapTargetSize:
                                                                    MaterialTapTargetSize
                                                                        .shrinkWrap,
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 2,
                                                                ),
                                                                visualDensity:
                                                                    VisualDensity
                                                                        .compact,
                                                              ),
                                                              child: Text(
                                                                  context.l10n
                                                                      .skip),
                                                            ),
                                                        ],
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  childCount: filteredList.length,
                                ),
                              ),
                            ),
                          if (historyState?.hasMore == true)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                child: Skeletonizer(
                                  enabled: historyState?.isLoadingMore == true,
                                  effect: ShimmerEffect(
                                    baseColor: colorScheme.skeletonBase,
                                    highlightColor:
                                        colorScheme.skeletonHighlight,
                                  ),
                                  child: OutlinedButton(
                                    onPressed: historyState?.isLoadingMore ==
                                            true
                                        ? null
                                        : () => ref
                                            .read(
                                                recurringOccurrenceHistoryProvider(
                                                        historyQuery)
                                                    .notifier)
                                            .loadMore(),
                                    child: Text(context.l10n.moreOptions),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    ColorScheme colorScheme, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor ?? colorScheme.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    ColorScheme colorScheme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int? count,
  }) {
    final titleText = count != null ? '$label ($count)' : label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.muted.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.border.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Text(
          titleText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}
