import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// Shows a date picker for transactions
/// 
/// This is a low-level widget that only handles showing the date
/// selection UI and returning the selected date. It has no knowledge
/// of what will be done with the selected date.
/// 
/// Platform-aware: Uses Cupertino date picker for iOS, Material for Android
/// 
/// [context] - BuildContext for showing the modal
/// [currentDate] - Currently selected date
/// [firstDate] - Optional minimum selectable date (defaults to 2020-01-01)
/// [lastDate] - Optional maximum selectable date (defaults to 2030-12-31)
/// 
/// Returns the selected date or null if cancelled
Future<DateTime?> showTransactionDatePicker({
  required BuildContext context,
  required DateTime currentDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final minDate = firstDate ?? DateTime(2020);
  final maxDate = lastDate ?? DateTime(2030);

  if (Platform.isIOS) {
    // Use Cupertino date picker for iOS
    return await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        DateTime tempDate = currentDate;
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              // Header with Done button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
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
              // Date picker
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: currentDate,
                  minimumDate: minDate,
                  maximumDate: maxDate,
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
  } else {
    // Use Material date picker for Android
    return await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: minDate,
      lastDate: maxDate,
    );
  }
}
