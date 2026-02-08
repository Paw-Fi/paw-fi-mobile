import 'package:moneko/features/households/domain/entities/expense_split.dart';

/// Result of computing the net settlement between the current user and
/// one other household member.
class PairwiseNetResult {
  /// Positive = currentUser owes otherUser this many cents.
  /// Negative = otherUser owes currentUser.
  final int netCents;

  /// Raw split-line total: currentUser owes otherUser (before events).
  final int splitToCents;

  /// Raw split-line total: otherUser owes currentUser (before events).
  final int splitFromCents;

  /// Sum of settlement events where otherUser was payer and currentUser
  /// was participant (i.e. currentUser already paid towards debt).
  final int paidToCents;

  /// Sum of settlement events where currentUser was payer and otherUser
  /// was participant (i.e. otherUser already paid towards debt).
  final int paidFromCents;

  const PairwiseNetResult({
    required this.netCents,
    required this.splitToCents,
    required this.splitFromCents,
    required this.paidToCents,
    required this.paidFromCents,
  });

  /// Convenience: amount currentUser owes (clamped to >= 0).
  int get youOweCents => netCents > 0 ? netCents : 0;

  /// Convenience: amount currentUser is owed (clamped to >= 0).
  int get youAreOwedCents => netCents < 0 ? -netCents : 0;
}

/// A settlement payment record used as input to the net calculator.
class SettlementPaymentRecord {
  final String payerUserId;
  final String participantUserId;
  final int amountCents;
  final String? currency;

  const SettlementPaymentRecord({
    required this.payerUserId,
    required this.participantUserId,
    required this.amountCents,
    this.currency,
  });
}

/// Pure function: compute the net settlement between [currentUserId] and
/// every other user, given [splits] and [settlementPayments].
///
/// Returns a map from otherUserId → [PairwiseNetResult].
///
/// The formula mirrors the server-side RPC
/// `households_settle_amount_and_notify`:
///
///   net = (splitTo − splitFrom) − (paidTo − paidFrom)
///
/// where:
///   splitTo   = sum of unsettled split lines where currentUser owes otherUser
///   splitFrom = sum of unsettled split lines where otherUser owes currentUser
///   paidTo    = sum of settlement events (payer=otherUser, participant=currentUser)
///   paidFrom  = sum of settlement events (payer=currentUser, participant=otherUser)
Map<String, PairwiseNetResult> computeSettlementNets({
  required List<ExpenseSplitGroup> splits,
  required String currentUserId,
  String? currencyFilter,
  List<SettlementPaymentRecord> settlementPayments = const [],
}) {
  final splitTo = <String, int>{};
  final splitFrom = <String, int>{};

  final normalizedCurrency = currencyFilter?.trim().toUpperCase();
  final hasCurrencyFilter =
      normalizedCurrency != null && normalizedCurrency.isNotEmpty;

  for (final g in splits) {
    if (hasCurrencyFilter) {
      final groupCode = g.currency.trim().toUpperCase();
      if (groupCode != normalizedCurrency) continue;
    }

    final payer = g.payerUserId;
    final lines = g.splitLines ?? const <ExpenseSplitLine>[];

    for (final line in lines) {
      if (line.isSettled) continue;
      final amount = (line.amountCents ?? 0).abs();
      if (amount <= 0) continue;

      if (line.userId == currentUserId && payer != currentUserId) {
        splitTo[payer] = (splitTo[payer] ?? 0) + amount;
      } else if (payer == currentUserId && line.userId != currentUserId) {
        splitFrom[line.userId] = (splitFrom[line.userId] ?? 0) + amount;
      }
    }
  }

  final paidTo = <String, int>{};
  final paidFrom = <String, int>{};
  for (final p in settlementPayments) {
    // Filter settlement payments by currency when a filter is active.
    // Exclude payments with null/empty currency to prevent cross-currency
    // subtraction from legacy rows that may lack a currency value.
    if (hasCurrencyFilter) {
      final pc = p.currency?.trim().toUpperCase();
      if (pc == null || pc.isEmpty || pc != normalizedCurrency) continue;
    }
    if (p.participantUserId == currentUserId) {
      paidTo[p.payerUserId] =
          (paidTo[p.payerUserId] ?? 0) + p.amountCents.abs();
    } else if (p.payerUserId == currentUserId) {
      paidFrom[p.participantUserId] =
          (paidFrom[p.participantUserId] ?? 0) + p.amountCents.abs();
    }
  }

  final otherUsers = <String>{
    ...splitTo.keys,
    ...splitFrom.keys,
    ...paidTo.keys,
    ...paidFrom.keys,
  };

  final results = <String, PairwiseNetResult>{};
  for (final otherUserId in otherUsers) {
    if (otherUserId.isEmpty || otherUserId == currentUserId) continue;

    final st = splitTo[otherUserId] ?? 0;
    final sf = splitFrom[otherUserId] ?? 0;
    final pt = paidTo[otherUserId] ?? 0;
    final pf = paidFrom[otherUserId] ?? 0;
    final net = (st - sf) - (pt - pf);

    results[otherUserId] = PairwiseNetResult(
      netCents: net,
      splitToCents: st,
      splitFromCents: sf,
      paidToCents: pt,
      paidFromCents: pf,
    );
  }

  return results;
}

/// Convenience: compute the net for a single [otherUserId].
PairwiseNetResult computePairwiseNet({
  required List<ExpenseSplitGroup> splits,
  required String currentUserId,
  required String otherUserId,
  String? currencyFilter,
  List<SettlementPaymentRecord> settlementPayments = const [],
}) {
  final all = computeSettlementNets(
    splits: splits,
    currentUserId: currentUserId,
    currencyFilter: currencyFilter,
    settlementPayments: settlementPayments,
  );
  return all[otherUserId] ??
      const PairwiseNetResult(
        netCents: 0,
        splitToCents: 0,
        splitFromCents: 0,
        paidToCents: 0,
        paidFromCents: 0,
      );
}
