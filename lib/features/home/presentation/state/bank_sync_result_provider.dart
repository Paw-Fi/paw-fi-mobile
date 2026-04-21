import 'package:hooks_riverpod/hooks_riverpod.dart';

class BankSyncResult {
  const BankSyncResult({
    this.currencyCode,
  });

  final String? currencyCode;
}

final bankSyncResultProvider = StateProvider<BankSyncResult?>((ref) => null);

class PendingBankLinkState {
  const PendingBankLinkState({
    required this.countryCode,
    this.targetHouseholdId,
  });

  final String countryCode;
  final String? targetHouseholdId;
}

final pendingBankLinkStateProvider =
    StateProvider<PendingBankLinkState?>((ref) => null);
