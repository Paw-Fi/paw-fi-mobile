import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_currency_picker.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/shared/widgets/destructive_text_button.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';
import 'package:moneko/shared/widgets/transaction_edit_handlers.dart';
import 'package:moneko/shared/widgets/transaction_form_section.dart';

/// Bottom sheet for editing a single parsed import row.
class EditRowSheet extends StatefulWidget {
  final ImportParsedRow row;
  final Future<void> Function(ImportParsedRow)? onSave;
  final GlobalKey<EditRowSheetState>? sheetKey;

  const EditRowSheet({
    super.key,
    required this.row,
    this.onSave,
    this.sheetKey,
  });

  @override
  State<EditRowSheet> createState() => EditRowSheetState();
}

class EditRowSheetState extends State<EditRowSheet> {
  late DateTime? _date;
  late double _amount;
  late String _category;
  late String _description;
  late String _merchant;
  late String _currency;
  late bool _isIncome;

  Future<void> save() async {
    await _handleSave(context);
  }

  @override
  void initState() {
    super.initState();
    _date = widget.row.date;
    _amount = widget.row.amountCents != null
        ? widget.row.amountCents!.abs() / 100.0
        : 0.0;
    _category = widget.row.category ?? '';
    _description = widget.row.description ?? '';
    _merchant = widget.row.merchant ?? '';
    _currency = widget.row.currency ?? 'USD';
    _isIncome = widget.row.type?.toLowerCase() == 'income';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safePadding = MediaQuery.of(context).viewPadding.bottom;
    final effectiveBottomPadding =
        viewInsets > 0 ? viewInsets + 16 : safePadding + 16;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: effectiveBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TransactionFormSection(
              amount: _amount,
              category: _category,
              date: _date ?? DateTime.now(),
              description: _description,
              merchant: _merchant,
              currency: _currency,
              isIncome: _isIncome,
              onEditAmount: _handleEditAmount,
              onEditCategory: _handleEditCategory,
              onEditDate: _handleEditDate,
              onEditDescription: _handleEditDescription,
              onEditMerchant: _handleEditMerchant,
              merchantLabel:
                  _isIncome ? context.l10n.source : context.l10n.merchant,
              merchantPlaceholder:
                  _isIncome ? context.l10n.addSource : context.l10n.addMerchant,
              onEditCurrency: _handleEditCurrency,
              onToggleType: _handleToggleType,
            ),
            const SizedBox(height: 24),
            DestructiveAdaptiveButton(
              onPressed: _handleDelete,
              child: Text(context.l10n.delete),
            ),
          ],
        ),
      ),
    );
  }

  // Edit handlers using shared TransactionEditHandlers
  Future<void> _handleEditAmount() async {
    final result = await TransactionEditHandlers.editAmount(
      context,
      currentAmount: _amount,
    );
    if (result != null) {
      setState(() => _amount = result);
    }
  }

  Future<void> _handleEditCategory() async {
    final result = await showCategoryPicker(
      context: context,
      currentCategory: _category,
      isIncome: _isIncome,
    );
    if (result != null) {
      setState(() => _category = result);
    }
  }

  Future<void> _handleEditDate() async {
    final result = await TransactionEditHandlers.editDate(
      context,
      currentDate: _date ?? DateTime.now(),
    );
    if (result != null) {
      setState(() => _date = result);
    }
  }

  Future<void> _handleEditDescription() async {
    final result = await TransactionEditHandlers.editText(
      context,
      title: context.l10n.description,
      currentValue: _description,
      placeholder: context.l10n.importEditDescriptionHint,
    );
    if (result != null) {
      setState(() => _description = result);
    }
  }

  Future<void> _handleEditMerchant() async {
    final result = await TransactionEditHandlers.editText(
      context,
      title: context.l10n.merchantOptional,
      currentValue: _merchant,
      placeholder: context.l10n.addMerchant,
    );
    if (result != null) {
      setState(() => _merchant = result);
    }
  }

  Future<void> _handleEditCurrency() async {
    final result = await showCurrencyPicker(
      context: context,
      currentCurrency: _currency,
    );
    if (result != null) {
      setState(() => _currency = result);
    }
  }

  void _handleToggleType() {
    setState(() => _isIncome = !_isIncome);
  }

  Future<void> _handleSave(BuildContext context) async {
    final errors = <String>[];
    if (_date == null) {
      errors.add(context.l10n.importErrorInvalidDate);
    }
    if (_amount <= 0) {
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

    final updatedRow = widget.row.copyWith(
      date: _date,
      amountCents: (_amount * 100).round(),
      category: _category.isEmpty ? 'uncategorized' : _category,
      description: _description.isEmpty ? null : _description,
      merchant: _merchant.trim().isEmpty ? null : _merchant.trim(),
      currency: _currency.isEmpty ? null : _currency,
      type: _isIncome ? 'income' : 'expense',
    );

    if (widget.onSave != null) {
      await widget.onSave!(updatedRow);
    } else {
      Navigator.of(context).pop(updatedRow);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.delete,
      description: context.l10n.areYouSureYouWantToDeleteThisTransaction,
      confirmLabel: context.l10n.delete,
      cancelLabel: context.l10n.cancel,
      barrierDismissible: true,
    );

    if (confirmed?.confirmed != true || !mounted) return;
    Navigator.of(context).pop('delete');
  }
}
