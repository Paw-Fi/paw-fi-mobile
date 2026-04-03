import 'package:flutter/material.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';

class WalletTransferResult {
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final DateTime date;
  final String? note;

  const WalletTransferResult({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.date,
    this.note,
  });
}

Future<WalletTransferResult?> showWalletTransferSheet(
  BuildContext context, {
  required List<WalletEntity> wallets,
}) {
  if (wallets.length < 2) {
    return Future.value(null);
  }

  String fromId = wallets.first.id;
  String toId = wallets[1].id;
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  return showModalBottomSheet<WalletTransferResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
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
                const Text('Transfer between wallets'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: fromId,
                  items: wallets
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => fromId = v);
                  },
                  decoration: const InputDecoration(labelText: 'From wallet'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: toId,
                  items: wallets
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => toId = v);
                  },
                  decoration: const InputDecoration(labelText: 'To wallet'),
                ),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                TextField(
                  controller: noteController,
                  decoration:
                      const InputDecoration(labelText: 'Note (optional)'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    if (fromId == toId) {
                      return;
                    }
                    final amountCents =
                        ((double.tryParse(amountController.text) ?? 0) * 100)
                            .round();
                    if (amountCents <= 0) {
                      return;
                    }
                    Navigator.of(context).pop(
                      WalletTransferResult(
                        fromAccountId: fromId,
                        toAccountId: toId,
                        amountCents: amountCents,
                        date: DateTime.now(),
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Transfer'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
