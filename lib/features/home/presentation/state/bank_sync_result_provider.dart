import 'package:hooks_riverpod/hooks_riverpod.dart';

class BankSyncResult {
  const BankSyncResult({
    this.householdId,
    this.currencyCode,
  });

  final String? householdId;
  final String? currencyCode;
}

final bankSyncResultProvider = StateProvider<BankSyncResult?>((ref) => null);
