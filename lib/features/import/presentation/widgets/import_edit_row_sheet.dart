import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/widgets/transaction_date_picker.dart';
import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/widgets/import_shared_widgets.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

/// Bottom sheet for editing a single parsed import row.
class EditRowSheet extends StatefulWidget {
  const EditRowSheet({super.key, required this.row});

  final ImportParsedRow row;

  @override
  State<EditRowSheet> createState() => _EditRowSheetState();
}

class _EditRowSheetState extends State<EditRowSheet> {
  late DateTime? _date;
  late String _amountText;
  late String _categoryText;
  late String _descriptionText;
  late String _currencyText;
  late String _typeValue;
  late final DateFormat _dateFormat;

  @override
  void initState() {
    super.initState();
    _dateFormat = DateFormat('yyyy-MM-dd');
    _date = widget.row.date;
    _amountText = widget.row.amountCents != null
        ? (widget.row.amountCents!.abs() / 100.0).toStringAsFixed(2)
        : '';
    _categoryText = widget.row.category ?? '';
    _descriptionText = widget.row.description ?? '';
    _currencyText = widget.row.currency ?? '';
    _typeValue = widget.row.type ?? 'expense';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.sheetBorder.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.importEditRowTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop('delete'),
                  icon: Icon(Icons.delete_rounded, color: scheme.error),
                  tooltip: 'Delete Transaction',
                ),
              ],
            ),
            const SizedBox(height: 16),
            GroupedSectionCard(
              title: context.l10n.details.toUpperCase(),
              children: [
                StandardTile(
                  leadingIcon: Icons.calendar_month_rounded,
                  title: context.l10n.date,
                  trailing: ValueChevron(
                    value:
                        _date != null ? _dateFormat.format(_date!) : 'Select',
                  ),
                  onTap: () => _pickDate(context),
                ),
                StandardTile(
                  leadingIcon: Icons.payments_rounded,
                  title: context.l10n.amount,
                  trailing: ValueChevron(
                    value: _amountText.isEmpty ? 'Enter' : _amountText,
                    isPlaceholder: _amountText.isEmpty,
                  ),
                  onTap: () => _editText(
                    context,
                    title: context.l10n.amount,
                    placeholder: context.l10n.importEditAmountHint,
                    initialValue: _amountText,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onSaved: (value) => setState(() => _amountText = value),
                  ),
                ),
                StandardTile(
                  leadingIcon: Icons.category_rounded,
                  title: context.l10n.category,
                  trailing: ValueChevron(
                    value:
                        _categoryText.isEmpty ? 'Uncategorized' : _categoryText,
                    isPlaceholder: _categoryText.isEmpty,
                  ),
                  onTap: () => _editText(
                    context,
                    title: context.l10n.category,
                    placeholder: context.l10n.importEditCategoryHint,
                    initialValue: _categoryText,
                    keyboardType: TextInputType.text,
                    onSaved: (value) => setState(() => _categoryText = value),
                  ),
                ),
                StandardTile(
                  leadingIcon: Icons.notes_rounded,
                  title: context.l10n.description,
                  trailing: ValueChevron(
                    value: _descriptionText.isEmpty ? 'None' : _descriptionText,
                    isPlaceholder: _descriptionText.isEmpty,
                  ),
                  onTap: () => _editText(
                    context,
                    title: context.l10n.description,
                    placeholder: context.l10n.importEditDescriptionHint,
                    initialValue: _descriptionText,
                    keyboardType: TextInputType.text,
                    onSaved: (value) =>
                        setState(() => _descriptionText = value),
                  ),
                ),
                StandardTile(
                  leadingIcon: Icons.currency_exchange_rounded,
                  title: context.l10n.currency,
                  trailing: ValueChevron(
                    // TODO: wire to l10n once ARB keys are added
                    value: _currencyText.isEmpty ? 'USD' : _currencyText,
                    isPlaceholder: _currencyText.isEmpty,
                  ),
                  onTap: () => _editText(
                    context,
                    title: context.l10n.currency,
                    // TODO: wire to l10n once ARB keys are added
                    placeholder: 'e.g. USD, EUR, GBP',
                    initialValue: _currencyText,
                    keyboardType: TextInputType.text,
                    onSaved: (value) =>
                        setState(() => _currencyText = value.toUpperCase()),
                  ),
                ),
                StandardTile(
                  leadingIcon: Icons.swap_horiz_rounded,
                  // TODO: wire to l10n once ARB keys are added
                  title: 'Type',
                  trailing: GestureDetector(
                    onTap: () {
                      setState(() {
                        _typeValue =
                            _typeValue == 'expense' ? 'income' : 'expense';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _typeValue == 'income'
                            ? scheme.successSurface
                            : scheme.errorSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (_typeValue == 'income'
                                  ? scheme.success
                                  : scheme.errorAccent)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _typeValue == 'income' ? 'Income' : 'Expense',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _typeValue == 'income'
                              ? scheme.success
                              : scheme.errorAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedAdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryAdaptiveButton(
                    onPressed: () => _handleSave(context),
                    child: Text(context.l10n.importEditSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = _date ?? DateTime.now();
    final picked = await showTransactionDatePicker(
      context: context,
      currentDate: current,
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String placeholder,
    required String initialValue,
    required TextInputType keyboardType,
    required ValueChanged<String> onSaved,
  }) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: title,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: initialValue,
        placeholder: placeholder,
        keyboardType: keyboardType,
      ),
      confirmLabel: context.l10n.ok,
      cancelLabel: context.l10n.cancel,
    );

    final text = result?.text;
    if (result?.confirmed == true && text != null) {
      onSaved(text);
    }
  }

  Future<void> _handleSave(BuildContext context) async {
    final parsedAmount = parseAmountCents(_amountText);

    final errors = <String>[];
    if (_date == null) {
      errors.add(context.l10n.importErrorInvalidDate);
    }
    if (parsedAmount == null) {
      errors.add(context.l10n.importErrorInvalidAmount);
    }

    if (errors.isNotEmpty) {
      await MonekoAlertDialog.show(
        context: context,
        title: context.l10n.importEditInvalidTitle,
        description: errors.join('\n'),
        confirmLabel: context.l10n.ok,
        cancelLabel: context.l10n.cancel,
      );
      return;
    }

    final categoryValue = _categoryText.trim();
    final descriptionValue = _descriptionText.trim();
    final currencyValue = _currencyText.trim().toUpperCase();
    final typeValue = _typeValue.trim().toLowerCase();

    Navigator.of(context).pop(
      widget.row.copyWith(
        date: _date,
        amountCents: parsedAmount?.abs(),
        category: categoryValue.isEmpty ? 'uncategorized' : categoryValue,
        description: descriptionValue.isEmpty ? null : descriptionValue,
        currency: currencyValue.isEmpty ? null : currencyValue,
        type: typeValue.isEmpty ? null : typeValue,
      ),
    );
  }
}
