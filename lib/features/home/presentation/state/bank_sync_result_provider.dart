import 'package:hooks_riverpod/hooks_riverpod.dart';

class BankSyncResult {
  const BankSyncResult({
    this.currencyCode,
  });

  final String? currencyCode;
}

final bankSyncResultProvider = StateProvider<BankSyncResult?>((ref) => null);
