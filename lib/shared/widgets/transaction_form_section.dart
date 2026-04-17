import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';
import 'package:moneko/shared/widgets/transaction_type_toggle.dart';

/// A reusable form section for transaction/expense data entry.
///
/// This widget provides a consistent UI for editing transaction fields
/// (amount, category, description, date, currency, type) across
/// different features (import editing, transaction creation, etc.).
///
/// Structure:
/// - Amount hero (outside container)
/// - Form fields (category, currency, date, time, type, description) inside container
///
/// The parent should wrap the form fields in a card/container for visual grouping.
class TransactionFormSection extends StatelessWidget {
  const TransactionFormSection({
    super.key,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    required this.currency,
    required this.isIncome,
    required this.onEditAmount,
    required this.onEditCategory,
    required this.onEditDate,
    required this.onEditDescription,
    required this.onEditCurrency,
    required this.onToggleType,
    this.currencySymbol,
    this.time,
    this.onEditTime,
    this.categoryTranslator,
    this.dividerIndent = 16,
    this.showAmountHero = true,
  });

  // Field values
  final double amount;
  final String category;
  final DateTime date;
  final String? description;
  final String currency;
  final bool isIncome;
  final String? currencySymbol;
  final TimeOfDay? time;

  // Callbacks
  final VoidCallback onEditAmount;
  final VoidCallback onEditCategory;
  final VoidCallback onEditDate;
  final VoidCallback onEditDescription;
  final VoidCallback onEditCurrency;
  final VoidCallback onToggleType;
  final VoidCallback? onEditTime;

  // Optional translator for category display
  final String Function(String)? categoryTranslator;

  // Visual customization
  final double dividerIndent;

  /// Whether to show the amount hero at the top (outside container)
  final bool showAmountHero;

  String get _formattedAmount {
    final symbol = currencySymbol ?? currency;
    final formatted = amount.toStringAsFixed(2);
    return isIncome ? '+$symbol$formatted' : '$symbol$formatted';
  }

  String get _displayCategory {
    if (categoryTranslator != null) {
      return categoryTranslator!(category);
    }
    return category.isEmpty ? 'Uncategorized' : category;
  }

  String _formatDate(BuildContext context) {
    return DateFormat.yMMMMd(
      intlSafeLocaleName(Localizations.localeOf(context)),
    ).format(DateTime(date.year, date.month, date.day));
  }

  String get _displayDescription {
    if (description == null || description!.isEmpty) {
      return '';
    }
    return description!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amount Hero (outside container)
          if (showAmountHero) _buildAmountHero(context),
      
          if (showAmountHero) const SizedBox(height: 24),
      
          // Form Fields (parent should wrap this in a container)
          _buildFormFields(context),
        ],
      ),
    );
  }

  /// Builds the amount hero section (displayed outside any container)
  Widget _buildAmountHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onEditAmount,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            _formattedAmount,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w600,
              color: isIncome ? scheme.primary : scheme.onSurface,
              letterSpacing: -0.5,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _formatRelativeDate(context, date),
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds the form fields section (wrapped in a card container)
  Widget _buildFormFields(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main form fields container (Category, Currency, Date, Time, Type)
        MonekoInput(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category
              MonekoDisclosureRow(
                label: context.l10n.category,
                value: _displayCategory,
                onTap: onEditCategory,
                isFirst: true,
              ),
              _buildDivider(scheme),

              // Currency
              MonekoDisclosureRow(
                label: context.l10n.currency,
                value: currency.toUpperCase(),
                onTap: onEditCurrency,
              ),
              _buildDivider(scheme),

              // Date
              MonekoDisclosureRow(
                label: context.l10n.date,
                value: _formatDate(context),
                onTap: onEditDate,
              ),

              // Time (optional)
              if (onEditTime != null) ...[
                _buildDivider(scheme),
                MonekoDisclosureRow(
                  label: context.l10n.time,
                  value: time!.format(context),
                  onTap: onEditTime!,
                ),
              ],

              _buildDivider(scheme),

              // Type Toggle
              _buildTypeToggle(context),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Notes/Description in separate container
        MonekoInput(
          child: _buildDescriptionField(context),
        ),
      ],
    );
  }

  Widget _buildDivider(ColorScheme scheme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: dividerIndent,
      endIndent: 0,
      color: scheme.onSurface.withValues(alpha: 0.1),
    );
  }

  Widget _buildTypeToggle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggleType,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                context.l10n.type,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TransactionTypeToggle(
                  isIncome: isIncome,
                  onToggle: onToggleType,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = _displayDescription.isNotEmpty;

    return InkWell(
      onTap: onEditDescription,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                context.l10n.notes,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasValue ? _displayDescription : context.l10n.addANote,
                textAlign: TextAlign.start,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: hasValue
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeDate(BuildContext context, DateTime date) {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    final localeName = intlSafeLocaleName(Localizations.localeOf(context));

    if (dateOnly == today) {
      return context.l10n.today;
    } else if (dateOnly == yesterday) {
      return context.l10n.yesterday;
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat.EEEE(localeName).format(dateOnly);
    } else {
      return DateFormat.yMMMMd(localeName).format(dateOnly);
    }
  }
}
