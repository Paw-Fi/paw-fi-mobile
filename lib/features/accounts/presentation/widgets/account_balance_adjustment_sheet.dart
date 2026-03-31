import 'package:flutter/material.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';

class AccountBalanceAdjustmentResult {
  final int targetBalanceCents;
  final String? note;

  const AccountBalanceAdjustmentResult({
    required this.targetBalanceCents,
    this.note,
  });
}

Future<AccountBalanceAdjustmentResult?> showAccountBalanceAdjustmentSheet(
  BuildContext context, {
  required AccountEntity account,
}) {
  final targetController = TextEditingController(
    text: (account.currentBalanceCents / 100).toStringAsFixed(2),
  );
  final noteController = TextEditingController();

  return showModalBottomSheet<AccountBalanceAdjustmentResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Adjust balance for ${account.name}'),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Target current balance'),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final cents =
                    ((double.tryParse(targetController.text) ?? 0) * 100)
                        .round();
                Navigator.of(context).pop(
                  AccountBalanceAdjustmentResult(
                    targetBalanceCents: cents,
                    note: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                  ),
                );
              },
              child: const Text('Update balance'),
            ),
          ],
        ),
      );
    },
  );
}
