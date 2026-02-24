import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

Future<void> showBudgetStatusSheet(
  BuildContext context, {
  required String title,
  required String status,
  required String detail,
  required VoidCallback onViewBudget,
  required VoidCallback onOpenHousehold,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
    builder: (sheetContext) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.sheetBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border.all(color: colorScheme.sheetBorder),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                status,
                style: TextStyle(
                  color: colorScheme.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                detail,
                style: TextStyle(
                  color: colorScheme.mutedForeground,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onViewBudget();
                  },
                  child: Text(sheetContext.l10n.budgetStatus),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onOpenHousehold();
                  },
                  child: const Text('Open household'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
