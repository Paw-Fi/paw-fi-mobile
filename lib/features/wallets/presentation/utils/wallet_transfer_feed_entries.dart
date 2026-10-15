import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/domain/entities/wallet_transfer.dart';

List<String> walletTransferFeedEntryIds(String transferId) => <String>[
      'transfer:$transferId:out',
      'transfer:$transferId:in',
    ];

String walletTransferFeeEntryId(String transferId) =>
    'transfer-fee:$transferId';

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
  final entries = buildWalletTransferFeedEntriesForTransfer(
    transfer: transfer,
    fallbackUserId: createdByUserId,
    fromWallet: fromWallet,
    toWallet: toWallet,
    householdId: householdId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
  final fee = transferJson['fee_expense'];
  if (transfer.feeAmountCents > 0 && fee is Map) {
    entries[2] = ExpenseEntry.fromJson({
      ...entries[2].toJson(),
      ...Map<String, dynamic>.from(fee),
      'transfer_fee_transfer_id': transfer.id,
    });
  }
  return entries;
}

List<ExpenseEntry> buildWalletTransferFeedEntriesForTransfer({
  required WalletTransfer transfer,
  required String fallbackUserId,
  WalletEntity? fromWallet,
  WalletEntity? toWallet,
  String? householdId,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final resolvedHouseholdId =
      householdId ?? fromWallet?.householdId ?? toWallet?.householdId;
  final note = _trimmedOrNull(transfer.note);

  ExpenseEntry buildEntry({
    required String direction,
    required String walletId,
    required WalletEntity? wallet,
    required String type,
  }) {
    return ExpenseEntry(
      id: 'transfer:${transfer.id}:$direction',
      userId: fallbackUserId,
      householdId: resolvedHouseholdId,
      date: transfer.date,
      transferTime: transfer.time,
      amountCents: (direction == 'in'
              ? transfer.effectiveToAmountCents
              : transfer.amountCents)
          .abs(),
      currency:
          (direction == 'in' ? transfer.effectiveToCurrency : transfer.currency)
              .trim()
              .toUpperCase(),
      category: 'transfers',
      createdAt: createdAt ?? transfer.createdAt ?? DateTime.now().toUtc(),
      updatedAt: updatedAt ?? transfer.updatedAt,
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
    if (transfer.feeAmountCents > 0)
      ExpenseEntry(
        id: transfer.feeExpenseId ?? walletTransferFeeEntryId(transfer.id),
        userId: fallbackUserId,
        householdId: resolvedHouseholdId,
        date: transfer.date,
        amountCents: transfer.feeAmountCents,
        currency: transfer.currency.trim().toUpperCase(),
        category: 'fees',
        createdAt: createdAt ?? transfer.createdAt ?? DateTime.now().toUtc(),
        updatedAt: updatedAt ?? transfer.updatedAt,
        rawText: note,
        walletId: transfer.fromAccountId,
        accountName: fromWallet?.name,
        accountIcon: fromWallet?.icon,
        accountColor: fromWallet?.color,
        type: 'expense',
        transferFeeTransferId: transfer.id,
        analyticsClass: 'expense',
        analyticsIsFinal: true,
        analyticsSpendingMultiplier: 1,
        analyticsCountsTowardIncome: false,
      ),
  ];
}

String? _trimmedOrNull(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
