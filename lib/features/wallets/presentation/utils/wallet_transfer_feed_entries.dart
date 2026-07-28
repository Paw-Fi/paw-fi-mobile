import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';

List<String> walletTransferFeedEntryIds(String transferId) => <String>[
      'transfer:$transferId:out',
      'transfer:$transferId:in',
    ];

List<ExpenseEntry> buildWalletTransferFeedEntries({
  required Map<String, dynamic> transferJson,
  required String fallbackUserId,
  WalletEntity? fromWallet,
  WalletEntity? toWallet,
}) {
  final transfer = WalletTransfer.fromJson(transferJson);
  final createdAt = DateTime.tryParse(
        transferJson['created_at']?.toString() ?? '',
      ) ??
      DateTime.now().toUtc();
  final updatedAt = DateTime.tryParse(
    transferJson['updated_at']?.toString() ?? '',
  );
  final createdByUserId =
      _trimmedOrNull(transferJson['created_by_user_id']) ?? fallbackUserId;
  final householdId = _trimmedOrNull(transferJson['household_id']) ??
      fromWallet?.householdId ??
      toWallet?.householdId;
  final note = _trimmedOrNull(transfer.note);

  ExpenseEntry buildEntry({
    required String direction,
    required String walletId,
    required WalletEntity? wallet,
    required String type,
  }) {
    return ExpenseEntry(
      id: 'transfer:${transfer.id}:$direction',
      userId: createdByUserId,
      householdId: householdId,
      date: transfer.date,
      amountCents: transfer.amountCents.abs(),
      currency: transfer.currency.trim().toUpperCase(),
      category: 'transfers',
      createdAt: createdAt,
      updatedAt: updatedAt,
      rawText: note ?? (direction == 'in' ? 'Transfer in' : 'Transfer out'),
      walletId: walletId,
      accountName: wallet?.name,
      accountIcon: wallet?.icon,
      accountColor: wallet?.color,
      type: type,
      analyticsClass: direction == 'in' ? 'transfer_in' : 'transfer_out',
      analyticsIsFinal: true,
      analyticsSpendingMultiplier: 0,
      analyticsCountsTowardIncome: false,
    );
  }

  return <ExpenseEntry>[
    buildEntry(
      direction: 'out',
      walletId: transfer.fromAccountId,
      wallet: fromWallet,
      type: 'expense',
    ),
    buildEntry(
      direction: 'in',
      walletId: transfer.toAccountId,
      wallet: toWallet,
      type: 'income',
    ),
  ];
}

String? _trimmedOrNull(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
