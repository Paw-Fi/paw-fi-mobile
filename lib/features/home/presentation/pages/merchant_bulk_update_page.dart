import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/pages/merchant_selection_page.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:moneko/features/home/presentation/state/transactions_feed_provider.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/shared/widgets/auto_paginated_scroll.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class MerchantBulkScope {
  const MerchantBulkScope({
    required this.userId,
    required this.householdId,
    required this.selectedCurrency,
    required this.selectedCurrencies,
  });

  final String userId;
  final String? householdId;
  final String? selectedCurrency;
  final List<String>? selectedCurrencies;

  List<String>? get effectiveCurrencies {
    final currencies = <String>{
      for (final currency in selectedCurrencies ?? const <String>[])
        if (currency.trim().isNotEmpty) currency.trim().toUpperCase(),
      if (selectedCurrency?.trim().isNotEmpty == true)
        selectedCurrency!.trim().toUpperCase(),
    }.toList()
      ..sort();
    return currencies.isEmpty ? null : currencies;
  }
}

class _BulkUpdateGroup {
  const _BulkUpdateGroup({
    required this.selectionId,
    required this.representative,
    required this.entries,
  });

  final String selectionId;
  final ExpenseEntry representative;
  final List<ExpenseEntry> entries;
}

ExpenseEntry _entryFromRecurringTransaction(RecurringTransaction transaction) {
  return ExpenseEntry(
    id: transaction.id,
    userId: transaction.userId,
    householdId: transaction.householdId,
    date: transaction.date,
    amountCents: (transaction.amount * 100).round(),
    currency: transaction.currency,
    category: transaction.category,
    createdAt: transaction.createdAt,
    updatedAt: transaction.updatedAt,
    rawText: transaction.description ?? transaction.merchant,
    merchant: transaction.merchant,
    merchantId: transaction.merchantId,
    merchantDomain: transaction.merchantDomain,
    merchantLogoUrl: transaction.merchantLogoUrl,
    merchantStructuredName: transaction.merchantStructuredName,
    walletId: transaction.accountId,
    type: transaction.type,
    isRecurring: true,
    recurrenceRuleJson: transaction.recurrenceRule?.toJson(),
  );
}

List<_BulkUpdateGroup> _groupEntriesForBulkUpdate(
  List<ExpenseEntry> entries,
) {
  final grouped = <String, List<ExpenseEntry>>{};
  for (final entry in entries) {
    final recurringId = entry.parentRecurringId?.trim();
    final selectionId =
        recurringId == null || recurringId.isEmpty ? entry.id : recurringId;
    grouped.putIfAbsent(selectionId, () => <ExpenseEntry>[]).add(entry);
  }

  return grouped.entries.map((group) {
    final representative = group.value.firstWhere(
      (entry) => entry.id == group.key && entry.isRecurring,
      orElse: () => group.value.first,
    );
    return _BulkUpdateGroup(
      selectionId: group.key,
      representative: representative,
      entries: List<ExpenseEntry>.unmodifiable(group.value),
    );
  }).toList(growable: false);
}

Future<void> showMerchantBulkUpdatePage({
  required BuildContext context,
  required MerchantBulkScope scope,
  required MerchantSelection selection,
  String? excludedTransactionId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MerchantBulkUpdatePage(
        scope: scope,
        selection: selection,
        excludedTransactionId: excludedTransactionId,
      ),
    ),
  );
}

class MerchantBulkUpdatePage extends ConsumerStatefulWidget {
  const MerchantBulkUpdatePage({
    super.key,
    required this.scope,
    required this.selection,
    this.excludedTransactionId,
  });

  final MerchantBulkScope scope;
  final MerchantSelection selection;
  final String? excludedTransactionId;

  @override
  ConsumerState<MerchantBulkUpdatePage> createState() =>
      _MerchantBulkUpdatePageState();
}

class _MerchantBulkUpdatePageState
    extends ConsumerState<MerchantBulkUpdatePage> {
  final _selectedIds = <String>{};
  var _isSaving = false;

  TransactionsFeedQuery get _query => TransactionsFeedQuery(
        userId: widget.scope.userId,
        householdId: widget.scope.householdId,
        selectedCurrency: widget.scope.selectedCurrency,
        selectedCurrencies: widget.scope.selectedCurrencies,
        selectedCategory: null,
        selectedType: 'all',
        searchQuery: '',
        startDate: null,
        endDate: null,
      );

  Future<void> _save(List<_BulkUpdateGroup> groups) async {
    if (_isSaving || _selectedIds.isEmpty) return;
    setState(() => _isSaving = true);

    final seenIds = <String>{};
    final selectedEntries = groups
        .where((group) => _selectedIds.contains(group.selectionId))
        .expand((group) => group.entries)
        .where((entry) => seenIds.add(entry.id))
        .toList(growable: false);
    for (var start = 0; start < selectedEntries.length; start += 500) {
      final end = (start + 500).clamp(0, selectedEntries.length);
      final chunk = selectedEntries.sublist(start, end);
      final descriptors = {
        for (final entry in chunk)
          if (!widget.selection.isCustomText &&
              entry.merchant?.trim().isNotEmpty == true)
            entry.id: entry.merchant!.trim(),
      };
      final success =
          await ref.read(transactionEditProvider.notifier).updateExpensesBatch(
                entries: chunk,
                updates: {
                  if (widget.selection.isCustomText)
                    'merchant': widget.selection.merchant,
                  'merchant_id': widget.selection.merchantId,
                  'merchant_structured_name': widget.selection.merchantName,
                },
                householdId: widget.scope.householdId,
                currencies: widget.scope.effectiveCurrencies,
                descriptorsById: descriptors,
              );
      if (!success) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
    }

    final recurringNotifier = ref
        .read(recurringTransactionsProvider(widget.scope.householdId).notifier);
    for (final group in groups) {
      if (!_selectedIds.contains(group.selectionId)) continue;
      final transaction = group.representative.isRecurring
          ? ref
              .read(recurringTransactionsProvider(widget.scope.householdId))
              .data
              .valueOrNull
              ?.where((item) => item.id == group.selectionId)
              .firstOrNull
          : null;
      if (transaction == null) continue;
      recurringNotifier.updateRecurring(
        transaction.copyWith(
          merchant: widget.selection.isCustomText
              ? widget.selection.merchant
              : transaction.merchant,
          merchantId: widget.selection.merchantId,
          merchantDomain: widget.selection.merchantDomain,
          merchantStructuredName: widget.selection.merchantName,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop();
  }

  void _toggleEntrySelection(String id) {
    if (_isSaving) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final feedState = ref.watch(transactionsFeedProvider(_query));
    final recurringState =
        ref.watch(recurringTransactionsProvider(widget.scope.householdId));
    final entries = feedState.items
        .where((entry) => entry.id != widget.excludedTransactionId)
        .where((entry) => entry.parentRecurringId == null && !entry.isRecurring)
        .followedBy(
          (recurringState.data.valueOrNull ?? const <RecurringTransaction>[])
              .where((transaction) {
            final currencies = widget.scope.effectiveCurrencies;
            return currencies == null ||
                currencies.contains(transaction.currency.toUpperCase());
          }).map(_entryFromRecurringTransaction),
        )
        .toList(growable: false);
    final groups = _groupEntriesForBulkUpdate(entries);
    final merchantName = widget.selection.merchantName ??
        widget.selection.merchant ??
        'Merchant';

    return AdaptiveScaffold(
      body: Material(
        color: colorScheme.appBackground,
        child: SafeArea(
          child: Column(
            children: [
              _BulkUpdateHeader(
                isSaving: _isSaving,
                canSave: _selectedIds.isNotEmpty,
                selectedCount: _selectedIds.length,
                onClose: () => Navigator.of(context).pop(),
                onSave: () => _save(groups),
              ),
              Expanded(
                child: AutoPaginatedScroll(
                  hasMore: feedState.hasMore,
                  isLoading: feedState.isLoading,
                  isLoadingMore: feedState.isLoadingMore,
                  onLoadMore: () => ref
                      .read(transactionsFeedProvider(_query).notifier)
                      .loadMore(),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: _TargetMerchantCard(
                            selection: widget.selection,
                            merchantName: merchantName,
                            isDark: isDark,
                            colorScheme: colorScheme,
                          ),
                        ),
                      ),
                      if (feedState.isLoading && !feedState.hasLoadedInitial)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _BulkUpdateSkeleton(isDark: isDark),
                          ),
                        )
                      else if (groups.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _BulkUpdateEmptyState(),
                        )
                      else
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.card,
                                borderRadius: BorderRadius.circular(10),
                                border: isDark
                                    ? Border.all(
                                        color: colorScheme.surfaceBorder,
                                        width: 0.5,
                                      )
                                    : null,
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < groups.length; i++) ...[
                                    _BulkTransactionTile(
                                      entry: groups[i].representative,
                                      isSelected: _selectedIds.contains(
                                        groups[i].selectionId,
                                      ),
                                      targetSelection: widget.selection,
                                      onTap: () => _toggleEntrySelection(
                                        groups[i].selectionId,
                                      ),
                                    ),
                                    if (i < groups.length - 1)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 68),
                                        child: Divider(
                                          height: 1,
                                          thickness: 0.5,
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.25),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (groups.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: colorScheme.appBackground,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.surfaceBorder,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: PrimaryAdaptiveButton(
                    onPressed: _selectedIds.isEmpty || _isSaving
                        ? null
                        : () => _save(groups),
                    isExpanded: true,
                    child: _isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selectedIds.isEmpty
                                ? 'Select Transactions to Update'
                                : 'Update ${_selectedIds.length} ${_selectedIds.length == 1 ? 'Transaction' : 'Transactions'}',
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

class _BulkUpdateHeader extends StatelessWidget {
  const _BulkUpdateHeader({
    required this.isSaving,
    required this.canSave,
    required this.selectedCount,
    required this.onClose,
    required this.onSave,
  });

  final bool isSaving;
  final bool canSave;
  final int selectedCount;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        minHeight: 56,
        maxHeight: MediaQuery.textScalerOf(context).scale(16) > 20
            ? double.infinity
            : 56,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              onPressed: isSaving ? null : onClose,
              icon: Icon(
                Icons.close_rounded,
                size: 22,
                color: colorScheme.foreground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Apply Merchant',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: canSave ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: canSave ? onSave : null,
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetMerchantCard extends StatelessWidget {
  const _TargetMerchantCard({
    required this.selection,
    required this.merchantName,
    required this.isDark,
    required this.colorScheme,
  });

  final MerchantSelection selection;
  final String merchantName;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isCustom = selection.isCustomText;
    final domain = selection.merchantDomain;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: isDark
            ? Border.all(color: colorScheme.surfaceBorder, width: 0.5)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCustom
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.surfaceBorder,
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isCustom
                ? Center(
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: colorScheme.primary,
                      size: 26,
                    ),
                  )
                : MerchantLogo(
                    merchantId: selection.merchantId,
                    domain: domain,
                    fallback: Center(
                      child: Icon(
                        Icons.storefront_outlined,
                        color: colorScheme.mutedForeground,
                        size: 24,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchantName,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (!isCustom) ...[
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          domain ?? 'Verified merchant',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          'Custom merchant text',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkTransactionTile extends StatelessWidget {
  const _BulkTransactionTile({
    required this.entry,
    required this.isSelected,
    required this.targetSelection,
    required this.onTap,
  });

  final ExpenseEntry entry;
  final bool isSelected;
  final MerchantSelection targetSelection;
  final VoidCallback onTap;

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = entry.type == 'income';
    final amountText =
        '${isIncome ? '+' : ''}${resolveCurrencySymbol(entry.currency ?? 'USD')}${entry.amount.toStringAsFixed(2)}';

    final categoryName = entry.category ?? 'Uncategorized';
    final categoryColor = AppTheme.adaptCategoryColorForTheme(
      getCategoryColor(categoryName, context),
      colorScheme,
    );
    final categoryIcon = getCategoryIcon(categoryName);

    final title = entry.merchant?.trim().isNotEmpty == true
        ? entry.merchant!.trim()
        : entry.rawText?.trim().isNotEmpty == true
            ? entry.rawText!.trim()
            : categoryName;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surface.withValues(alpha: 0.0),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.controlBorder,
                    width: isSelected ? 0 : 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: colorScheme.primaryForeground,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: isSelected
                    ? (!targetSelection.isCustomText
                        ? Container(
                            key: const ValueKey('selected_merchant_logo'),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colorScheme.surfaceBorder,
                                width: 0.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: MerchantLogo(
                              merchantId: targetSelection.merchantId,
                              domain: targetSelection.merchantDomain,
                              fallback: Center(
                                child: Icon(
                                  categoryIcon,
                                  color: categoryColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            key: const ValueKey('selected_custom_icon'),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          ))
                    : Container(
                        key: const ValueKey('category_icon'),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            categoryIcon,
                            color: categoryColor,
                            size: 18,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(entry.date)} · $categoryName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                amountText,
                style: TextStyle(
                  color:
                      isIncome ? colorScheme.success : colorScheme.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkUpdateEmptyState extends StatelessWidget {
  const _BulkUpdateEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surfaceBorder,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 28,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Other Transactions Found',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No existing transactions in this currency scope match to be reassigned.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkUpdateSkeleton extends StatelessWidget {
  const _BulkUpdateSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shimmerColor = colorScheme.onSurface.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: isDark
            ? Border.all(color: colorScheme.surfaceBorder, width: 0.5)
            : null,
      ),
      child: Column(
        children: List.generate(
          4,
          (index) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 110,
                            height: 14,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 70,
                            height: 11,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 14,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < 3)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
