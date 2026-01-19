import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/constants/pocket_icon_constants.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';

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

void showUncategorizedSheet(
  BuildContext context,
  ColorScheme colorScheme,
  String currency,
  List<UncategorizedCategory> uncategorized,
  List<PocketEnvelope> availablePockets,
  Function(String pocketId, String category) onAssignCategory, {
  Map<String, List<Map<String, dynamic>>>? uncategorizedExpenses,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
    builder: (sheetContext) {
      final sorted = [...uncategorized]
        ..sort((a, b) => b.amount.compareTo(a.amount));

      return StatefulBuilder(
        builder: (context, setState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.sheetBackground.withValues(alpha: 0.96),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.sheetBorder.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 40,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).padding.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 16,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.uncategorizedSpendingTitle,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.uncategorizedSpendingDescription,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.mutedForeground,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // List
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sorted.length,
                          physics: const BouncingScrollPhysics(),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = sorted[index];
                            final expensesForCategory =
                                uncategorizedExpenses?[item.category] ??
                                    uncategorizedExpenses?[
                                        item.category.toLowerCase()] ??
                                    const [];

                            return _UncategorizedCategoryTile(
                              key: ValueKey(item.category),
                              item: item,
                              currency: currency,
                              colorScheme: colorScheme,
                              expenses: expensesForCategory,
                              onAssign: () {
                                _showPocketSelectionModal(
                                  context,
                                  availablePockets,
                                  (pocket) {
                                    onAssignCategory(pocket.id, item.category);
                                    Navigator.of(sheetContext).pop();
                                    setState(() {
                                      sorted.removeWhere(
                                          (e) => e.category == item.category);
                                    });
                                    if (sorted.isEmpty &&
                                        Navigator.of(sheetContext).canPop()) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                                  colorScheme,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _UncategorizedCategoryTile extends StatefulWidget {
  const _UncategorizedCategoryTile({
    super.key,
    required this.item,
    required this.currency,
    required this.colorScheme,
    required this.expenses,
    required this.onAssign,
  });

  final UncategorizedCategory item;
  final String currency;
  final ColorScheme colorScheme;
  final List<Map<String, dynamic>> expenses;
  final VoidCallback onAssign;

  @override
  State<_UncategorizedCategoryTile> createState() =>
      _UncategorizedCategoryTileState();
}

class _UncategorizedCategoryTileState extends State<_UncategorizedCategoryTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final categoryColor = getCategoryColor(widget.item.category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.pocketCardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.pocketCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Category Icon/Initial
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      getCategoryIcon(widget.item.category),
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Category Name & Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        Text(
                          '${widget.expenses.length} transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Amount & Expand Icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatLocalizedCurrency(
                          context,
                          widget.item.amount,
                          widget.currency,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.foreground,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Column(
                    children: [
                      Container(
                        height: 1,
                        color: colorScheme.sheetBorder.withValues(alpha: 0.4),
                      ),
                      if (widget.expenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            context.l10n.noDetailedExpensesFound,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.mutedForeground,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: widget.expenses.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 56,
                            endIndent: 16,
                            color:
                                colorScheme.sheetBorder.withValues(alpha: 0.3),
                          ),
                          itemBuilder: (context, index) {
                            final exp = widget.expenses[index];
                            final desc =
                                (exp['description'] as String?)?.trim();
                            final amountCents =
                                (exp['amount_cents'] as num?)?.toDouble() ?? 0;
                            final dateStr = exp['date'] as String?;
                            DateTime? date;
                            if (dateStr != null) {
                              date = DateTime.tryParse(dateStr);
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          desc?.isNotEmpty == true
                                              ? desc!
                                              : context.l10n.expense,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.foreground,
                                          ),
                                        ),
                                        if (date != null)
                                          Text(
                                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  colorScheme.mutedForeground,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatLocalizedCurrency(
                                      context,
                                      amountCents / 100.0,
                                      widget.currency,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      // Action Button Area
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.onAssign,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  context.l10n.assignToPocket,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

void _showPocketSelectionModal(
  BuildContext context,
  List<PocketEnvelope> pockets,
  ValueChanged<PocketEnvelope> onSelected,
  ColorScheme colorScheme,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
    isScrollControlled: true,
    builder: (context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: colorScheme.sheetBackground.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Select Pocket',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: colorScheme.foreground,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                      icon: Icon(Icons.close,
                          size: 20, color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (pockets.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.money_off_rounded,
                        size: 48,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pockets available',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pockets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final pocket = pockets[index];
                      final iconData = getPocketIconData(pocket.icon);
                      final pocketColor = pocket.color != null
                          ? Color(int.parse(
                              pocket.color!.replaceFirst('#', '0xff')))
                          : colorScheme.primary;

                      return Material(
                        color: colorScheme.surface.withValues(alpha: 0.0),
                        child: InkWell(
                          onTap: () => onSelected(pocket),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.pocketCardBorder,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: pocketColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: pocketColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pocket.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.foreground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: colorScheme.mutedForeground
                                      .withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
