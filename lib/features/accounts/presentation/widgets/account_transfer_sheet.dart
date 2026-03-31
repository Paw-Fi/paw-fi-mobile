import 'package:flutter/material.dart';
import 'package:moneko/features/accounts/domain/entities/account.dart';

class AccountTransferResult {
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final DateTime date;
  final String? note;

  const AccountTransferResult({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.date,
    this.note,
  });
}

Future<AccountTransferResult?> showAccountTransferSheet(
  BuildContext context, {
  required List<AccountEntity> accounts,
}) {
  if (accounts.length < 2) {
    return Future.value(null);
  }

  String fromId = accounts.first.id;
  String toId = accounts[1].id;
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  return showModalBottomSheet<AccountTransferResult>(
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
                const Text('Transfer between accounts'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: fromId,
                  items: accounts
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => fromId = v);
                  },
                  decoration: const InputDecoration(labelText: 'From account'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: toId,
                  items: accounts
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => toId = v);
                  },
                  decoration: const InputDecoration(labelText: 'To account'),
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
                      AccountTransferResult(
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
