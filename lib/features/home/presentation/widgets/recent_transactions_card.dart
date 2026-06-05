import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' as foundation;

import 'package:moneko/features/home/presentation/models/models.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:moneko/features/home/presentation/widgets/unified_transaction_sheet.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/currency_rates.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/add_recurring_sheet.dart';
import 'package:moneko/features/recurring/presentation/widgets/upcoming_recurring_banner.dart';
import 'package:moneko/features/home/presentation/utils/transaction_display_datetime.dart';
import 'package:moneko/features/home/presentation/utils/converted_transaction_summary.dart';

const bool _enableRecentTransactionDebugLogs =
    bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

void _debugRecentTransactions(String message) {
  if (foundation.kDebugMode && _enableRecentTransactionDebugLogs) {
    foundation.debugPrint(message);
  }
}

bool _isOptimisticTransactionId(String id) => id.startsWith('optimistic_');

String _normalizedRecentText(ExpenseEntry entry) {
  final source = (entry.rawText?.trim().isNotEmpty == true)
      ? entry.rawText!.trim()
      : (entry.merchant?.trim().isNotEmpty == true)
          ? entry.merchant!.trim()
          : (entry.category ?? '').trim();
  return source
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();
}

String? _recentTransactionReconciliationFingerprint(ExpenseEntry entry) {
  final normalizedText = _normalizedRecentText(entry);
  if (normalizedText.isEmpty) return null;
  final dateKey = '${entry.date.year.toString().padLeft(4, '0')}-'
      '${entry.date.month.toString().padLeft(2, '0')}-'
      '${entry.date.day.toString().padLeft(2, '0')}';
  return [
    dateKey,
    (entry.currency ?? '').trim().toUpperCase(),
    (entry.type ?? 'expense').trim().toLowerCase(),
    entry.householdId?.trim() ?? '',
    entry.userId?.trim() ?? '',
    normalizedText,
  ].join('|');
}

String _recentTransactionContentSignature(ExpenseEntry entry) {
  final dateKey = '${entry.date.year.toString().padLeft(4, '0')}-'
      '${entry.date.month.toString().padLeft(2, '0')}-'
      '${entry.date.day.toString().padLeft(2, '0')}';
  return [
    dateKey,
    entry.amountCents.toString(),
    (entry.currency ?? '').trim().toUpperCase(),
    (entry.type ?? 'expense').trim().toLowerCase(),
    (entry.category ?? '').trim().toLowerCase(),
    _normalizedRecentText(entry),
    entry.splitGroupId?.trim() ?? '',
    entry.receiptImageUrl?.trim() ?? '',
    entry.localReceiptImagePath?.trim() ?? '',
    entry.isRecurring.toString(),
  ].join('|');
}

bool _canReconcileRecentTransaction({
  required ExpenseEntry previous,
  required ExpenseEntry next,
}) {
  if (previous.id == next.id) return true;
  final isOptimisticPair = _isOptimisticTransactionId(previous.id) !=
      _isOptimisticTransactionId(next.id);
  if (!isOptimisticPair) return false;

  final previousFingerprint =
      _recentTransactionReconciliationFingerprint(previous);
  final nextFingerprint = _recentTransactionReconciliationFingerprint(next);
  return previousFingerprint != null && previousFingerprint == nextFingerprint;
}

bool _shouldPreferRecentDuplicate({
  required ExpenseEntry candidate,
  required ExpenseEntry current,
}) {
  final candidateIsOptimistic = _isOptimisticTransactionId(candidate.id);
  final currentIsOptimistic = _isOptimisticTransactionId(current.id);
  if (candidateIsOptimistic == currentIsOptimistic) return false;
  return !candidateIsOptimistic && currentIsOptimistic;
}

List<ExpenseEntry> _dedupeRecentOptimisticReplacements(
  List<ExpenseEntry> sortedEntries,
) {
  final deduped = <ExpenseEntry>[];
  final indexByFingerprint = <String, int>{};

  for (final entry in sortedEntries) {
    final fingerprint = _recentTransactionReconciliationFingerprint(entry);
    if (fingerprint == null) {
      deduped.add(entry);
      continue;
    }

    final existingIndex = indexByFingerprint[fingerprint];
    if (existingIndex == null) {
      indexByFingerprint[fingerprint] = deduped.length;
      deduped.add(entry);
      continue;
    }

    final existing = deduped[existingIndex];
    final isOptimisticPair = _isOptimisticTransactionId(existing.id) !=
        _isOptimisticTransactionId(entry.id);
    if (!isOptimisticPair) {
      deduped.add(entry);
      continue;
    }

    if (_shouldPreferRecentDuplicate(candidate: entry, current: existing)) {
      deduped[existingIndex] = entry;
    }
    _debugRecentTransactions(
      '[RecentTransactions] De-duped optimistic replacement: '
      'kept=${deduped[existingIndex].id} dropped=${deduped[existingIndex].id == entry.id ? existing.id : entry.id} '
      'fingerprint=$fingerprint',
    );
  }

  return deduped;
}

class _KeyedRecentEntry {
  const _KeyedRecentEntry({
    required this.key,
    required this.entry,
  });

  final String key;
  final ExpenseEntry entry;
}

class _RecentTransactionRowState {
  const _RecentTransactionRowState({
    required this.key,
    required this.entry,
    required this.isRemoving,
    required this.animateIn,
  });

  final String key;
  final ExpenseEntry entry;
  final bool isRemoving;
  final bool animateIn;

  _RecentTransactionRowState copyWith({
    String? key,
    ExpenseEntry? entry,
    bool? isRemoving,
    bool? animateIn,
  }) {
    return _RecentTransactionRowState(
      key: key ?? this.key,
      entry: entry ?? this.entry,
      isRemoving: isRemoving ?? this.isRemoving,
      animateIn: animateIn ?? this.animateIn,
    );
  }
}

List<ExpenseEntry> _latestRecentTransactions(List<ExpenseEntry> allExpenses) {
  final nonRecurringExpenses =
      allExpenses.where((e) => !e.isRecurring).toList(growable: false);

  final recent = nonRecurringExpenses.toList()
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
  return _dedupeRecentOptimisticReplacements(recent).take(5).toList();
}

List<_KeyedRecentEntry> _keyedLatestRecentEntries(
  List<ExpenseEntry> allExpenses,
) {
  final occurrences = <String, int>{};
  return _latestRecentTransactions(allExpenses).map((entry) {
    final baseKey = entry.id.isEmpty
        ? 'fallback:${_recentTransactionContentSignature(entry)}'
        : 'id:${entry.id}';
    final count = occurrences[baseKey] ?? 0;
    occurrences[baseKey] = count + 1;
    return _KeyedRecentEntry(
      key: count == 0 ? baseKey : '$baseKey#$count',
      entry: entry,
    );
  }).toList(growable: false);
}

int _recentExpensesSignature(List<ExpenseEntry> expenses) {
  var hash = expenses.length;
  for (final expense in expenses) {
    hash = Object.hash(
      hash,
      expense.id,
      expense.date.millisecondsSinceEpoch,
      expense.createdAt.millisecondsSinceEpoch,
      expense.amountCents,
      expense.currency,
      expense.type,
      expense.category,
      expense.rawText,
      expense.merchant,
      expense.receiptImageUrl,
      expense.localReceiptImagePath,
      expense.splitGroupId,
      expense.isRecurring,
    );
  }
  return hash;
}

Widget buildRecentTransactionsCard(
  BuildContext context,
  ColorScheme colorScheme,
  List<ExpenseEntry> allExpenses,
  UserContact? contact, {
  Key? key,
  String? selectedCurrency,
  List<String>? selectedCurrencies,
  String? householdId,
  required VoidCallback onViewAll,
}) {
  return _RecentTransactionsCard(
    key: key,
    colorScheme: colorScheme,
    allExpenses: allExpenses,
    contact: contact,
    selectedCurrency: selectedCurrency,
    selectedCurrencies: selectedCurrencies,
    householdId: householdId,
    onViewAll: onViewAll,
  );
}

class _RecentTransactionsCard extends ConsumerStatefulWidget {
  const _RecentTransactionsCard({
    super.key,
    required this.colorScheme,
    required this.allExpenses,
    required this.contact,
    required this.selectedCurrency,
    required this.selectedCurrencies,
    required this.householdId,
    required this.onViewAll,
  });

  final ColorScheme colorScheme;
  final List<ExpenseEntry> allExpenses;
  final UserContact? contact;
  final String? selectedCurrency;
  final List<String>? selectedCurrencies;
  final String? householdId;
  final VoidCallback onViewAll;

  @override
  ConsumerState<_RecentTransactionsCard> createState() =>
      _RecentTransactionsCardState();
}

class _RecentTransactionsCardState
    extends ConsumerState<_RecentTransactionsCard> {
  static const _rowAnimationDuration = Duration(milliseconds: 320);

  late List<_RecentTransactionRowState> _rows;
  List<ExpenseEntry>? _cachedExpensesIdentity;
  int? _cachedExpensesSignature;
  List<_KeyedRecentEntry>? _cachedKeyedEntries;

  @override
  void initState() {
    super.initState();
    _rows = _keyedEntriesFor(widget.allExpenses)
        .map(
          (entry) => _RecentTransactionRowState(
            key: entry.key,
            entry: entry.entry,
            isRemoving: false,
            animateIn: false,
          ),
        )
        .toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant _RecentTransactionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRows(_keyedEntriesFor(widget.allExpenses));
  }

  List<_KeyedRecentEntry> _keyedEntriesFor(List<ExpenseEntry> expenses) {
    final cached = _cachedKeyedEntries;
    if (cached != null && identical(_cachedExpensesIdentity, expenses)) {
      return cached;
    }

    final signature = _recentExpensesSignature(expenses);
    if (cached != null && _cachedExpensesSignature == signature) {
      _cachedExpensesIdentity = expenses;
      return cached;
    }

    final next = _keyedLatestRecentEntries(expenses);
    _cachedExpensesIdentity = expenses;
    _cachedExpensesSignature = signature;
    _cachedKeyedEntries = next;
    return next;
  }

  void _syncRows(List<_KeyedRecentEntry> latest) {
    final oldRows = _rows;
    final matchedOldIndexes = <int>{};
    final nextRows = <_RecentTransactionRowState>[];

    int findExactMatch(String key) {
      for (var index = 0; index < oldRows.length; index++) {
        if (matchedOldIndexes.contains(index)) continue;
        final row = oldRows[index];
        if (!row.isRemoving && row.key == key) return index;
      }
      return -1;
    }

    int findReconciledMatch(ExpenseEntry entry) {
      for (var index = 0; index < oldRows.length; index++) {
        if (matchedOldIndexes.contains(index)) continue;
        final row = oldRows[index];
        if (row.isRemoving) continue;
        if (_canReconcileRecentTransaction(
          previous: row.entry,
          next: entry,
        )) {
          return index;
        }
      }
      return -1;
    }

    for (final keyedEntry in latest) {
      final exactIndex = findExactMatch(keyedEntry.key);
      final matchIndex =
          exactIndex >= 0 ? exactIndex : findReconciledMatch(keyedEntry.entry);
      if (matchIndex >= 0) {
        matchedOldIndexes.add(matchIndex);
        nextRows.add(
          oldRows[matchIndex].copyWith(
            key: keyedEntry.key,
            entry: keyedEntry.entry,
            isRemoving: false,
            animateIn: false,
          ),
        );
        continue;
      }

      nextRows.add(
        _RecentTransactionRowState(
          key: keyedEntry.key,
          entry: keyedEntry.entry,
          isRemoving: false,
          animateIn: true,
        ),
      );
    }

    var hasRemovingRows = false;
    for (var oldIndex = 0; oldIndex < oldRows.length; oldIndex++) {
      if (matchedOldIndexes.contains(oldIndex)) continue;
      final oldRow = oldRows[oldIndex];
      final removingRow = oldRow.copyWith(
        key: 'removing:${oldRow.key}:$oldIndex:${oldRow.entry.id}',
        isRemoving: true,
        animateIn: false,
      );
      final insertIndex = oldIndex.clamp(0, nextRows.length).toInt();
      nextRows.insert(insertIndex, removingRow);
      hasRemovingRows = true;
    }

    if (!_rowStatesEqual(oldRows, nextRows)) {
      setState(() {
        _rows = nextRows;
      });
    }

    if (hasRemovingRows) {
      Future<void>.delayed(_rowAnimationDuration, () {
        if (!mounted) return;
        setState(() {
          _rows = _rows.where((row) => !row.isRemoving).toList(growable: false);
        });
      });
    }
  }

  bool _rowStatesEqual(
    List<_RecentTransactionRowState> previous,
    List<_RecentTransactionRowState> next,
  ) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index += 1) {
      final a = previous[index];
      final b = next[index];
      if (a.key != b.key ||
          !identical(a.entry, b.entry) ||
          a.isRemoving != b.isRemoving ||
          a.animateIn != b.animateIn) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final cardRadius = BorderRadius.circular(24);

    return Material(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.homeCardSurface,
          borderRadius: cardRadius,
          border: Border.all(
            color: colorScheme.homeCardBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.homeCardShadow,
              blurRadius: 32,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: cardRadius,
          clipBehavior: Clip.antiAlias,
          child: Builder(
            builder: (context) {
              final upcoming = ref.watch(upcomingRecurringTransactionProvider(
                UpcomingRecurringScope(
                  householdId: widget.householdId,
                  currency: widget.selectedCurrency,
                  selectedCurrencies: widget.selectedCurrencies,
                ),
              ));
              final shouldConvertUpcoming =
                  (widget.selectedCurrencies?.length ?? 0) > 1;
              final targetCurrency = widget.selectedCurrency ?? 'USD';
              final rateTable = shouldConvertUpcoming
                  ? ref.watch(currencyRateTableProvider).valueOrNull ??
                      const CurrencyRateTable(
                        baseCurrency: 'USD',
                        rates: CurrencyRates.rates,
                        isStale: true,
                      )
                  : null;
              final upcomingDisplayAmount =
                  upcoming == null || !shouldConvertUpcoming
                      ? null
                      : convertAmountCentsToCurrency(
                            (upcoming.transaction.amount * 100).round(),
                            fromCurrency: upcoming.transaction.currency
                                .trim()
                                .toUpperCase(),
                            targetCurrency: targetCurrency,
                            rates: rateTable!,
                          ) /
                          100.0;

              if (_rows.isEmpty && upcoming == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      context.l10n.noTransactionsFound,
                      style: TextStyle(color: colorScheme.mutedForeground),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (upcoming != null) ...[
                    UpcomingRecurringBanner(
                      upcoming: upcoming,
                      displayAmount: upcomingDisplayAmount,
                      displayCurrency:
                          shouldConvertUpcoming ? targetCurrency : null,
                      onTap: () {
                        showAddRecurringSheet(
                          context,
                          type: upcoming.transaction.type,
                          existingTransaction: upcoming.transaction,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      upcoming != null ? 0 : 16,
                      0,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._rows.map(_buildAnimatedRow),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: widget.onViewAll,
                            child: Text(context.l10n.viewAll),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedRow(_RecentTransactionRowState row) {
    return _AnimatedRecentTransactionRow(
      key: ValueKey(row.key),
      animateIn: row.animateIn,
      isRemoving: row.isRemoving,
      duration: _rowAnimationDuration,
      child: _buildSlidableRow(row),
    );
  }

  Widget _buildSlidableRow(_RecentTransactionRowState row) {
    final e = row.entry;
    final colorScheme = widget.colorScheme;
    final isIncome = (e.type ?? 'expense').toLowerCase() == 'income';
    final displayDateTime = composeTransactionDisplayDateTime(
      transactionDate: e.date,
      createdAt: e.createdAt,
      preferredTimezone: widget.contact?.preferredTimezone,
    );

    return Slidable(
      key: ValueKey('slidable_${row.key}'),
      enabled: !row.isRemoving,
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final l10n = context.l10n;
              final rootNavigator = Navigator.of(context, rootNavigator: true);
              final toastContext = rootNavigator.context;

              setState(() {
                _rows = _rows
                    .where((currentRow) => currentRow.key != row.key)
                    .toList(growable: false);
              });
              AppToast.success(toastContext, l10n.transactionDeleted);
              final success = await ref
                  .read(transactionEditProvider.notifier)
                  .deleteExpensesOptimistically([e]);

              if (!success) {
                final error = ref.read(transactionEditProvider).error;
                if (!toastContext.mounted) return;
                AppToast.error(
                  toastContext,
                  ErrorHandler.getUserFriendlyMessage(
                    error,
                    context: BackendErrorContext.deleteExpense,
                  ),
                );
              }
            },
            backgroundColor: colorScheme.destructive,
            foregroundColor: colorScheme.onError,
            icon: Icons.delete,
            label: context.l10n.delete,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: KeyedSubtree(
          key: ValueKey(_recentTransactionContentSignature(e)),
          child: buildExpenseTransactionTile(
            context: context,
            category: e.category,
            rawText: e.rawText,
            date: displayDateTime,
            amount: e.amount,
            currency: e.currency ?? widget.selectedCurrency ?? 'USD',
            isIncome: isIncome,
            onTap: row.isRemoving
                ? null
                : () => showUnifiedTransactionSheet(
                      context,
                      existingExpense: e,
                      contact: widget.contact,
                    ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedRecentTransactionRow extends StatefulWidget {
  const _AnimatedRecentTransactionRow({
    super.key,
    required this.child,
    required this.animateIn,
    required this.isRemoving,
    required this.duration,
  });

  final Widget child;
  final bool animateIn;
  final bool isRemoving;
  final Duration duration;

  @override
  State<_AnimatedRecentTransactionRow> createState() =>
      _AnimatedRecentTransactionRowState();
}

class _AnimatedRecentTransactionRowState
    extends State<_AnimatedRecentTransactionRow> {
  late bool _isVisible;

  @override
  void initState() {
    super.initState();
    _isVisible = !widget.animateIn && !widget.isRemoving;
    if (widget.animateIn && !widget.isRemoving) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isVisible = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedRecentTransactionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextVisible = !widget.isRemoving;
    if (_isVisible != nextVisible) {
      setState(() => _isVisible = nextVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _isVisible ? 1 : 0),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
