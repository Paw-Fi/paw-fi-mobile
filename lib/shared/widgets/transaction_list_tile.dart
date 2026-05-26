import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/constants/custom_category_style_overrides.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/utils/intl_locale.dart';

class TransactionListTile extends ConsumerWidget {
  final String category;
  final String title;
  final String? description;
  final String? subtitle;
  final Widget? subtitleWidget;
  final DateTime? date;
  final double amount;
  final String currency;
  final bool isIncome;
  final VoidCallback? onTap;
  final Widget? trailingWidget;
  final bool dense;
  final bool showYouLabel;
  final bool showRecurringChip;
  final String? accountLabel;

  const TransactionListTile({
    super.key,
    required this.category,
    required this.title,
    this.description,
    this.subtitle,
    this.subtitleWidget,
    this.date,
    required this.amount,
    required this.currency,
    required this.isIncome,
    this.onTap,
    this.trailingWidget,
    this.dense = true,
    this.showYouLabel = false,
    this.showRecurringChip = false,
    this.accountLabel,
  });

  String? _formatDate(BuildContext context, DateTime date) {
    final localeName = intlSafeLocaleName(Localizations.localeOf(context));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final localDate = date.toLocal();
    final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

    if (dateOnly == today) {
      return '${context.l10n.today}, ${DateFormat.jm(localeName).format(localDate)}';
    }
    if (dateOnly == yesterday) {
      return '${context.l10n.yesterday}, ${DateFormat.jm(localeName).format(localDate)}';
    }
    if (localDate.year == now.year) {
      return DateFormat.MMMd(localeName).format(localDate);
    }
    return DateFormat.yMMMd(localeName).format(localDate);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCurrencyFilters = ref.watch(
      homeFilterProvider.select((state) => state.normalizedSelectedCurrencies),
    );
    final shouldShowCurrencyFlag = (selectedCurrencyFilters?.length ?? 0) > 1;

    return ValueListenableBuilder<Map<String, CustomCategoryStyle>>(
      valueListenable: customCategoryStyleOverridesNotifier,
      builder: (context, _, __) {
        final colorScheme = Theme.of(context).colorScheme;
        final color = getCategoryColor(category);
        final icon = getCategoryIcon(category);
        final sign = isIncome ? '+' : '-';
        final normalizedAmount = double.parse(formatAmount(amount.abs()));
        final localizedNumber =
            formatLocalizedNumber(context, normalizedAmount);
        final currencySymbol = resolveCurrencySymbol(currency);
        final formattedAmount = '$currencySymbol$localizedNumber';
        final trimmedDescription = description?.trim() ?? '';
        final trimmedTitle = title.trim();
        final displayTitle = trimmedDescription.isNotEmpty
            ? trimmedDescription
            : (trimmedTitle.isNotEmpty ? trimmedTitle : category);

        // Build badge chips
        final chips = <Widget>[];
        if (showYouLabel) {
          chips.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'You',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );
        }
        if (showRecurringChip) {
          chips.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.repeat, size: 10, color: colorScheme.tertiary),
                ],
              ),
            ),
          );
        }
        if (shouldShowCurrencyFlag) {
          chips.add(_TransactionCurrencyFlagBadge(currencyCode: currency));
        }

        Widget? subtitleNode;
        if (subtitleWidget != null) {
          subtitleNode = subtitleWidget;
        } else if (date != null) {
          final base = _formatDate(context, date!);
          if (base != null && base.isNotEmpty) {
            if (chips.isNotEmpty) {
              subtitleNode = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      base,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...chips
                      .expand((chip) => [chip, const SizedBox(width: 4)])
                      .toList()
                    ..removeLast(),
                ],
              );
            } else {
              subtitleNode = Text(
                base,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.mutedForeground,
                ),
              );
            }
          }
        } else if (subtitle != null) {
          subtitleNode = Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.mutedForeground,
            ),
          );
        }

        return ListTile(
          onTap: onTap,
          dense: dense,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.foreground,
            ),
          ),
          subtitle: subtitleNode,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sign,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isIncome
                          ? colorScheme.success
                          : colorScheme.foreground,
                    ),
                  ),
                  Text(
                    formattedAmount,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isIncome
                          ? colorScheme.success
                          : colorScheme.foreground,
                    ),
                  ),
                ],
              ),
              if (trailingWidget != null) ...[
                const SizedBox(height: 2),
                trailingWidget!,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TransactionCurrencyFlagBadge extends StatelessWidget {
  const _TransactionCurrencyFlagBadge({
    required this.currencyCode,
  });

  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final flagPath = getCurrencyFlagPath(normalizedCurrency);
    final fallbackLabel = normalizedCurrency.isNotEmpty
        ? normalizedCurrency.substring(0, 1)
        : '?';

    return SizedBox(
      width: 15,
      height: 15,
      child: ClipOval(
        child: flagPath != null
            ? Image.asset(flagPath, fit: BoxFit.cover)
            : Center(
                child: Text(
                  fallbackLabel,
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

Widget buildExpenseTransactionTile({
  required BuildContext context,
  String? category,
  String? rawText,
  required DateTime date,
  required double amount,
  required String currency,
  required bool isIncome,
  VoidCallback? onTap,
  Widget? trailingWidget,
  bool dense = true,
  bool showYouLabel = false,
  bool showRecurringChip = false,
}) {
  final effectiveCategory = category ?? 'other';
  final title = getCategoryTranslation(context, effectiveCategory);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: TransactionListTile(
      onTap: onTap,
      category: effectiveCategory,
      title: title,
      description: rawText,
      date: date,
      amount: amount,
      currency: currency,
      isIncome: isIncome,
      trailingWidget: trailingWidget,
      dense: dense,
      showYouLabel: showYouLabel,
      showRecurringChip: showRecurringChip,
    ),
  );
}
