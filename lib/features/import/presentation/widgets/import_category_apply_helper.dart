import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/import/presentation/widgets/persisted_transaction_editing_helper.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

Future<bool> confirmApplyCategoryToAll({
  required BuildContext context,
  required int matchingCount,
  required String originalCategory,
  required String newCategory,
}) async {
  if (matchingCount <= 0) {
    return false;
  }

  final result = await MonekoAlertDialog.show(
    context: context,
    title: context.l10n.applyToAllTransactions,
    description: context.l10n.applyCategoryToAllDescription(
      matchingCount,
      getCategoryTranslation(context, normalizeEditableCategory(newCategory)),
      getCategoryTranslation(
          context, normalizeEditableCategory(originalCategory)),
    ),
    confirmLabel: context.l10n.applyToAll,
    cancelLabel: context.l10n.onlyThisOne,
  );

  return result?.confirmed == true;
}
