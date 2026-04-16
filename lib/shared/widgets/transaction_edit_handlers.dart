import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

/// Shared edit handlers for transaction form fields.
///
/// These utilities provide consistent editing experiences across
/// import editing, transaction creation, and expense editing flows.
class TransactionEditHandlers {
  TransactionEditHandlers._();

  /// Shows an amount editor dialog and returns the parsed amount if confirmed.
  static Future<double?> editAmount(
    BuildContext context, {
    required double currentAmount,
  }) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: context.l10n.editAmount,
      confirmLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: currentAmount.toStringAsFixed(2),
        placeholder: context.l10n.amount,
        isRequired: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validationPattern: RegExp(r'^[0-9]+(\.[0-9]{0,2})?$'),
        validationMessage: context.l10n.pleaseEnterValidAmount,
      ),
    );

    if (result != null && result.confirmed && result.text != null) {
      final parsed = double.tryParse(result.text!.replaceAll(',', ''));
      if (parsed == null || parsed <= 0) return null;
      return parsed;
    }

    return null;
  }

  /// Shows a text editor dialog for string fields.
  static Future<String?> editText(
    BuildContext context, {
    required String title,
    required String currentValue,
    String? placeholder,
    TextInputType keyboardType = TextInputType.text,
    String? validationMessage,
  }) async {
    final result = await MonekoAlertDialog.show(
      context: context,
      title: title,
      confirmLabel: context.l10n.save,
      cancelLabel: context.l10n.cancel,
      inputConfig: MonekoAlertDialogInputConfig(
        initialValue: currentValue,
        placeholder: placeholder ?? '',
        keyboardType: keyboardType,
      ),
    );

    if (result != null && result.confirmed && result.text != null) {
      return result.text!.trim();
    }

    return null;
  }

  /// Shows a date picker appropriate for the platform.
  static Future<DateTime?> editDate(
    BuildContext context, {
    required DateTime currentDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final effectiveFirstDate = firstDate ?? DateTime(2020);
    final effectiveLastDate = lastDate ?? DateTime.now();

    if (Platform.isIOS) {
      return _showCupertinoDatePicker(
        context,
        currentDate: currentDate,
        firstDate: effectiveFirstDate,
        lastDate: effectiveLastDate,
      );
    } else {
      return showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: effectiveFirstDate,
        lastDate: effectiveLastDate,
      );
    }
  }

  /// Shows a time picker appropriate for the platform.
  static Future<TimeOfDay?> editTime(
    BuildContext context, {
    required TimeOfDay currentTime,
  }) async {
    if (Platform.isIOS) {
      return _showCupertinoTimePicker(context, currentTime: currentTime);
    } else {
      return showTimePicker(
        context: context,
        initialTime: currentTime,
      );
    }
  }

  static Future<DateTime?> _showCupertinoDatePicker(
    BuildContext context, {
    required DateTime currentDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    DateTime tempDate = currentDate;

    return showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: colorScheme.sheetBackground,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.sheetBorder,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context, tempDate),
                      child: Text(context.l10n.done),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: currentDate,
                  minimumDate: firstDate,
                  maximumDate: lastDate,
                  onDateTimeChanged: (DateTime value) {
                    tempDate = value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<TimeOfDay?> _showCupertinoTimePicker(
    BuildContext context, {
    required TimeOfDay currentTime,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      currentTime.hour,
      currentTime.minute,
    );
    DateTime tempTime = initialDateTime;

    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: colorScheme.sheetBackground,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.sheetBorder,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context, tempTime),
                      child: Text(context.l10n.done),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initialDateTime,
                  use24hFormat: false,
                  onDateTimeChanged: (DateTime value) {
                    tempTime = value;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      return TimeOfDay(hour: result.hour, minute: result.minute);
    }

    return null;
  }
}
