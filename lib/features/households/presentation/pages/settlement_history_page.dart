import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/shared/widgets/user_avatar.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

String _formatLocalizedCurrency(
  BuildContext context,
  double amount,
  String currency,
) {
  final normalized = double.parse(formatAmount(amount));
  final symbol = resolveCurrencySymbol(currency);
  final localized = formatLocalizedNumber(context, normalized);
  return '$symbol$localized';
}

List<String> _normalizeSettlementCurrencies(List<String>? currencies) {
  final normalized = (currencies ?? const <String>[])
      .map((currency) => currency.trim().toUpperCase())
      .where((currency) => currency.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return normalized;
}

String _formatSettlementAmount(
  int amountCents, {
  required String sourceCurrency,
  required String displayCurrency,
  required bool convertForDisplay,
  required CurrencyRateTable rates,
}) {
  final currency =
      convertForDisplay ? displayCurrency : sourceCurrency.trim().toUpperCase();
  final displayAmountCents = convertForDisplay
      ? convertAmountCentsToCurrency(
          amountCents,
          fromCurrency: sourceCurrency,
          targetCurrency: displayCurrency,
          rates: rates,
        )
      : amountCents;
  return formatCurrency(displayAmountCents / 100.0, currency);
}

class SettlementHistoryPage extends ConsumerStatefulWidget {
  final String householdId;
  const SettlementHistoryPage({super.key, required this.householdId});

  @override
  ConsumerState<SettlementHistoryPage> createState() =>
      _SettlementHistoryPageState();
}

class _SettlementHistoryPageState extends ConsumerState<SettlementHistoryPage> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  Future<void> _refreshHistory() async {
    HapticFeedback.lightImpact();
    ref.invalidate(householdSettlementHistoryProvider(
      SettlementHistoryParams(householdId: widget.householdId),
    ));
  }

  Map<String, List<SettlementEvent>> _groupEventsByDate(
      List<SettlementEvent> events) {
    final Map<String, List<SettlementEvent>> grouped = {};
    for (final event in events) {
      final dateKey = DateFormat.yMd().format(event.settledAt);
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }
    return grouped;
  }

  Map<String, double> _calculateCurrencyTotals(
    List<SettlementEvent> events, {
    required String displayCurrency,
    required bool convertForDisplay,
    required CurrencyRateTable rates,
  }) {
    final Map<String, double> currencyTotals = {};
    for (final event in events) {
      final currency = convertForDisplay ? displayCurrency : event.currency;
      final amountCents = convertForDisplay
          ? convertAmountCentsToCurrency(
              event.amountCents,
              fromCurrency: event.currency,
              targetCurrency: displayCurrency,
              rates: rates,
            )
          : event.amountCents;
      currencyTotals[currency] =
          (currencyTotals[currency] ?? 0.0) + amountCents / 100.0;
    }
    return currencyTotals;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(householdSettlementHistoryProvider(
        SettlementHistoryParams(householdId: widget.householdId)));
    final homeFilter = ref.watch(homeFilterProvider);
    final selectedCurrency =
        (homeFilter.selectedCurrency ?? 'USD').toUpperCase();
    final selectedCurrencyFilters = _normalizeSettlementCurrencies(
      homeFilter.normalizedSelectedCurrencies,
    );
    final hasMultiCurrencySelection = selectedCurrencyFilters.length > 1;
    final selectedCurrencySet = selectedCurrencyFilters.toSet();
    final rateTable = ref.watch(currencyRateTableProvider).valueOrNull ??
        const CurrencyRateTable(
          baseCurrency: 'USD',
          rates: CurrencyRates.rates,
          isStale: true,
        );
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      appBar: AdaptiveAppBar(
          useNativeToolbar: false, title: context.l10n.settlement),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshHistory,
        color: colorScheme.primary,
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Material(
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.errorLoadingData,
                      style: TextStyle(color: colorScheme.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (members) {
            String nameFor(String userId) {
              final m = members.firstWhere(
                (member) => member.userId == userId,
                orElse: () => HouseholdMember(
                  id: '',
                  householdId: '',
                  userId: userId,
                  role: HouseholdRole.member,
                  joinedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  userEmail: null,
                  userName: null,
                ),
              );
              final n = m.userName?.trim();
              if (n != null && n.isNotEmpty) return n;
              if (m.userEmail != null && m.userEmail!.isNotEmpty) {
                return m.userEmail!;
              }
              return context.l10n.member;
            }

            return historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.errorLoadingData,
                      style: TextStyle(color: colorScheme.mutedForeground),
                    ),
                  ],
                ),
              ),
              data: (events) {
                final filtered = events.where((e) {
                  final currency = e.currency.toUpperCase();
                  return hasMultiCurrencySelection
                      ? selectedCurrencySet.contains(currency)
                      : currency == selectedCurrency;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.history,
                            size: 48,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.nothingToSettle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${context.l10n.settlementsWillAppearHere} ($selectedCurrency)',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.history,
                            size: 48,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.nothingToSettle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.settlementsWillAppearHere,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final groupedEvents = _groupEventsByDate(filtered);
                final currencyTotals = _calculateCurrencyTotals(
                  filtered,
                  displayCurrency: selectedCurrency,
                  convertForDisplay: hasMultiCurrencySelection,
                  rates: rateTable,
                );
                final sortedDates = groupedEvents.keys.toList()
                  ..sort((a, b) => DateFormat.yMd()
                      .parse(b)
                      .compareTo(DateFormat.yMd().parse(a)));

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: _buildSummarySection(
                            context, filtered, currencyTotals),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= sortedDates.length) return null;
                            final date = sortedDates[index];
                            final dayEvents = groupedEvents[date]!;
                            final isLastGroup = index == sortedDates.length - 1;

                            return _buildDayGroup(
                              context,
                              date,
                              dayEvents,
                              nameFor,
                              isLastGroup,
                              displayCurrency: selectedCurrency,
                              convertForDisplay: hasMultiCurrencySelection,
                              rates: rateTable,
                            );
                          },
                          childCount: sortedDates.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 48),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    ));
  }

  Widget _buildSummarySection(BuildContext context,
      List<SettlementEvent> events, Map<String, double> currencyTotals) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalTransactions = events.fold(
      0,
      (sum, event) =>
          sum + (event.lines.isNotEmpty ? event.lines.length : event.lineCount),
    );

    return Column(
      children: [
        Text(
          context.l10n.totalSettled,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (currencyTotals.isEmpty)
          Text(
            '0.00',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
            ),
          )
        else
          ...currencyTotals.entries.map(
            (e) => Text(
              formatCurrency(e.value, e.key.toUpperCase()),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatBadge(
              context,
              Icons.receipt_long_rounded,
              '$totalTransactions ${context.l10n.transactions.toLowerCase()}',
            ),
            const SizedBox(width: 12),
            _buildStatBadge(
              context,
              Icons.handshake_rounded,
              '${events.length} ${context.l10n.settlements.toLowerCase()}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBadge(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayGroup(
    BuildContext context,
    String date,
    List<SettlementEvent> events,
    String Function(String) nameFor,
    bool isLastGroup, {
    required String displayCurrency,
    required bool convertForDisplay,
    required CurrencyRateTable rates,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final parsedDate = DateFormat.yMd().parse(date);
    final isToday = DateFormat.yMd().format(DateTime.now()) == date;
    final isYesterday = DateFormat.yMd()
            .format(DateTime.now().subtract(const Duration(days: 1))) ==
        date;

    String displayDate;
    if (isToday) {
      displayDate = context.l10n.today;
    } else if (isYesterday) {
      displayDate = context.l10n.yesterday;
    } else {
      displayDate = DateFormat.MMMd().format(parsedDate);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            displayDate.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
              letterSpacing: 1,
            ),
          ),
        ),
        ...events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLastItem = index == events.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: (isLastGroup && isLastItem)
                            ? colorScheme.surface.withValues(alpha: 0.0)
                            : colorScheme.border.withValues(alpha: 0.5),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: _buildSettlementItem(
                      context,
                      event,
                      nameFor,
                      displayCurrency: displayCurrency,
                      convertForDisplay: convertForDisplay,
                      rates: rates,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSettlementItem(
    BuildContext context,
    SettlementEvent event,
    String Function(String) nameFor, {
    required String displayCurrency,
    required bool convertForDisplay,
    required CurrencyRateTable rates,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final payerName = nameFor(event.payerUserId);
    final participantName = nameFor(event.participantUserId);
    final amount = _formatSettlementAmount(
      event.amountCents,
      sourceCurrency: event.currency,
      displayCurrency: displayCurrency,
      convertForDisplay: convertForDisplay,
      rates: rates,
    );
    final time = DateFormat.jm().format(event.settledAt.toLocal());

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final actorId = event.settledByUserId;
    String? actorLabel;
    if (actorId != null) {
      final isYou = currentUserId != null && actorId == currentUserId;
      final actorName = isYou ? 'you' : nameFor(actorId);
      actorLabel = 'Settled by $actorName';
    }
    final isExpress = event.isExpressNetting == true;

    int sumDirection(List<SettlementLine> lines, String fromId, String toId) {
      return lines
          .where((l) =>
              (l.payerUserId ?? fromId) == fromId &&
              (l.participantUserId ?? toId) == toId)
          .fold<int>(0, (s, l) => s + l.amountCents);
    }

    final totalPayerToParticipant = event.lines.isNotEmpty
        ? sumDirection(event.lines, event.payerUserId, event.participantUserId)
        : event.payerToParticipantCents;
    final totalParticipantToPayer = event.lines.isNotEmpty
        ? sumDirection(event.lines, event.participantUserId, event.payerUserId)
        : event.participantToPayerCents;

    final shouldShowOffsets =
        isExpress && totalPayerToParticipant > 0 && totalParticipantToPayer > 0;

    return Material(
      child: InkWell(
        onTap: () => _showSettlementDetails(context, event, nameFor),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.cardSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        UserAvatar(
                          name: participantName,
                          userId: event.participantUserId,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            participantName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.foreground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            payerName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.foreground,
                            ),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        UserAvatar(
                          name: payerName,
                          userId: event.payerUserId,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (event.settlementNote != null &&
                  event.settlementNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  event.settlementNote!,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.foreground,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.mutedForeground
                                  .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${event.lines.isNotEmpty ? event.lines.length : event.lineCount} ${context.l10n.items}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      if (actorLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          actorLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (shouldShowOffsets) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offsets',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$participantName → $payerName: ${_formatSettlementAmount(
                              totalParticipantToPayer,
                              sourceCurrency: event.currency,
                              displayCurrency: displayCurrency,
                              convertForDisplay: convertForDisplay,
                              rates: rates,
                            )}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                          Text(
                            '$payerName → $participantName: ${_formatSettlementAmount(
                              totalPayerToParticipant,
                              sourceCurrency: event.currency,
                              displayCurrency: displayCurrency,
                              convertForDisplay: convertForDisplay,
                              rates: rates,
                            )}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Express netting',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSettlementDetails(BuildContext context, SettlementEvent event,
      String Function(String) nameFor) {
    HapticFeedback.lightImpact();
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      builder: (context) => SettlementDetailsSheet(
        event: event,
        nameFor: nameFor,
        householdId: widget.householdId,
        settlementNote: event.settlementNote,
      ),
    );
  }
}

class SettlementDetailsSheet extends StatefulWidget {
  final SettlementEvent event;
  final String Function(String) nameFor;
  final String householdId;
  final String? settlementNote;

  const SettlementDetailsSheet({
    Key? key,
    required this.event,
    required this.nameFor,
    required this.householdId,
    this.settlementNote,
  }) : super(key: key);

  @override
  State<SettlementDetailsSheet> createState() => _SettlementDetailsSheetState();
}

class _SettlementDetailsSheetState extends State<SettlementDetailsSheet> {
  List<SettlementLine> _lines = const [];

  @override
  void initState() {
    super.initState();
    _lines = [...widget.event.lines]
      ..sort((a, b) => b.settledAt.compareTo(a.settledAt));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = _formatLocalizedCurrency(
      context,
      widget.event.amountCents / 100.0,
      widget.event.currency.toUpperCase(),
    );
    final lineItems = (_lines.isNotEmpty ? _lines : widget.event.lines).toList()
      ..sort((a, b) => b.settledAt.compareTo(a.settledAt));
    final forwardTotal = lineItems.isNotEmpty
        ? lineItems
            .where((l) =>
                (l.payerUserId ?? widget.event.payerUserId) ==
                    widget.event.payerUserId &&
                (l.participantUserId ?? widget.event.participantUserId) ==
                    widget.event.participantUserId)
            .fold<int>(0, (s, l) => s + l.amountCents)
        : widget.event.payerToParticipantCents;
    final reverseTotal = lineItems.isNotEmpty
        ? lineItems
            .where((l) =>
                (l.payerUserId ?? widget.event.participantUserId) ==
                    widget.event.participantUserId &&
                (l.participantUserId ?? widget.event.payerUserId) ==
                    widget.event.payerUserId)
            .fold<int>(0, (s, l) => s + l.amountCents)
        : widget.event.participantToPayerCents;
    final isExpress = widget.event.isExpressNetting == true;
    final shouldShowOffsets = isExpress && forwardTotal > 0 && reverseTotal > 0;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final actorId = widget.event.settledByUserId;
    String? actorDisplay;
    if (actorId != null) {
      if (currentUserId != null && actorId == currentUserId) {
        actorDisplay = 'You';
      } else {
        actorDisplay = widget.nameFor(actorId);
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.cardSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: colorScheme.success,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isExpress) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Express netting',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.l10n.settledSuccessfully,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat.yMMMd()
                        .add_jm()
                        .format(widget.event.settledAt.toLocal()),
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    amount,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.foreground,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          context,
                          context.l10n.from,
                          widget.nameFor(widget.event.participantUserId),
                          icon: Icons.arrow_outward_rounded,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        _buildDetailRow(
                          context,
                          context.l10n.to,
                          widget.nameFor(widget.event.payerUserId),
                          icon: Icons.arrow_downward_rounded,
                        ),
                        if (shouldShowOffsets) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _buildDetailRow(
                            context,
                            'Offset totals',
                            '${widget.nameFor(widget.event.participantUserId)} → ${widget.nameFor(widget.event.payerUserId)} ${formatCurrency(reverseTotal / 100.0, widget.event.currency.toUpperCase())} • ${widget.nameFor(widget.event.payerUserId)} → ${widget.nameFor(widget.event.participantUserId)} ${formatCurrency(forwardTotal / 100.0, widget.event.currency.toUpperCase())}',
                            icon: Icons.compare_arrows_rounded,
                          ),
                        ],
                        if (actorDisplay != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _buildDetailRow(
                            context,
                            'Settled by',
                            actorDisplay,
                            icon: Icons.person_rounded,
                          ),
                        ],
                        if (widget.settlementNote != null &&
                            widget.settlementNote!.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          _buildDetailRow(
                            context,
                            context.l10n.note,
                            widget.settlementNote!,
                            icon: Icons.notes_rounded,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (lineItems.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.transactions,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ...lineItems.map(
                            (line) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: buildExpenseTransactionTile(
                                context: context,
                                category: line.expenseCategory,
                                rawText: line.expenseDescription ??
                                    line.expenseRawText,
                                date: line.settledAt.toLocal(),
                                amount: line.amountCents / 100.0,
                                currency: widget.event.currency.toUpperCase(),
                                isIncome: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value,
      {IconData? icon}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: colorScheme.mutedForeground,
          ),
          const SizedBox(width: 12),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.mutedForeground,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
