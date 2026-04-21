import 'package:flutter/material.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';

class WalletBalanceAdjustmentResult {
  final int targetBalanceCents;
  final String? note;

  const WalletBalanceAdjustmentResult({
    required this.targetBalanceCents,
    this.note,
  });
}

Future<WalletBalanceAdjustmentResult?> showAccountBalanceAdjustmentSheet(
  BuildContext context, {
  required WalletEntity wallet,
}) {
  final targetController = TextEditingController(
    text: (wallet.currentBalanceCents / 100).toStringAsFixed(2),
  );
  final noteController = TextEditingController();

  return showModalBottomSheet<WalletBalanceAdjustmentResult>(
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
            Text('Adjust balance for ${wallet.name}'),
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
                  WalletBalanceAdjustmentResult(
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
