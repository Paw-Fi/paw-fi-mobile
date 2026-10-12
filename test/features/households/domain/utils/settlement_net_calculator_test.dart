import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/domain/utils/settlement_net_calculator.dart';
import 'package:moneko/features/households/presentation/utils/pending_settlement_payment.dart';

const _members = ['A', 'B', 'C', 'D'];

ExpenseSplitGroup _expense(
  String id,
  String payer,
  Map<String, int> allocations, {
  String currency = 'EUR',
  bool settled = false,
}) {
  final date = DateTime.utc(2026, 10, 12);
  return ExpenseSplitGroup(
    id: id,
    householdId: 'household',
    expenseId: id,
    payerUserId: payer,
    splitType: SplitType.amount,
    currency: currency,
    totalAmountCents: allocations.values.fold(0, (sum, cents) => sum + cents),
    createdAt: date,
    updatedAt: date,
    splitLines: [
      for (final allocation in allocations.entries)
        ExpenseSplitLine(
          id: '$id-${allocation.key}',
          splitGroupId: id,
          userId: allocation.key,
          amountCents: allocation.value,
          isSettled: settled,
          createdAt: date,
          updatedAt: date,
        ),
    ],
  );
}

int _net(List<ExpenseSplitGroup> splits, List<SettlementPaymentRecord> payments,
        String from, String to,
        {String currency = 'EUR'}) =>
    computePairwiseNet(
      splits: splits,
      currentUserId: from,
      otherUserId: to,
      currencyFilter: currency,
      settlementPayments: payments,
    ).netCents;

SettlementPaymentRecord _payment(String from, String to, int cents,
        {String currency = 'EUR'}) =>
    pendingSettlementPaymentRecord(
      currentUserId: from,
      memberUserId: to,
      mode: 'to_member',
      amountCents: cents,
      currency: currency,
    )!;

void _assertConservation(
    List<ExpenseSplitGroup> splits, List<SettlementPaymentRecord> payments) {
  var total = 0;
  for (final from in _members) {
    expect(_net(splits, payments, from, from), 0);
    for (final to in _members.where((member) => member != from)) {
      final net = _net(splits, payments, from, to);
      expect(net, -_net(splits, payments, to, from));
      total += net;
    }
  }
  expect(total, 0);
}

void main() {
  test(
      'identical amounts remain distinct while repeated identities are applied once',
      () {
    final splits = [
      _expense('AB', 'B', {'A': 10000})
    ];
    const first = SettlementPaymentRecord(
        payerUserId: 'B',
        participantUserId: 'A',
        amountCents: 3000,
        currency: 'EUR',
        actorUserId: 'A',
        clientMutationId: 'first',
        eventId: 'event-first');
    const second = SettlementPaymentRecord(
        payerUserId: 'B',
        participantUserId: 'A',
        amountCents: 3000,
        currency: 'EUR',
        actorUserId: 'A',
        clientMutationId: 'second',
        eventId: 'event-second');
    final pending = _payment('A', 'B', 3000);
    final samePending = SettlementPaymentRecord(
        payerUserId: pending.payerUserId,
        participantUserId: pending.participantUserId,
        amountCents: pending.amountCents,
        currency: pending.currency,
        actorUserId: 'A',
        clientMutationId: 'first');
    expect(_net(splits, [first, first, samePending, second], 'A', 'B'), 4000);
    expect(
        () => mergeSettlementPayments(confirmed: const [
              first
            ], pending: const [
              SettlementPaymentRecord(
                  payerUserId: 'B',
                  participantUserId: 'A',
                  amountCents: 3001,
                  currency: 'EUR',
                  actorUserId: 'A',
                  clientMutationId: 'first')
            ]),
        throwsA(isA<FormatException>()));
  });
  test(
      'marked future templates and soft-deleted sources never create current debt',
      () {
    final live = _expense('live', 'B', {'A': 1000});
    final template = ExpenseSplitGroup.fromJson({
      ..._expense('template', 'B', {'A': 2000}).toJson(),
      'is_recurring_template': true,
    });
    final deleted = ExpenseSplitGroup.fromJson({
      ..._expense('deleted', 'B', {'A': 3000}).toJson(),
      'expense_deleted': true,
    });
    expect(_net([live, template, deleted], [], 'A', 'B'), 1000);
  });
  test('four members settle independent debts in exact partial amounts', () {
    final splits = [
      _expense('AB', 'B', {'A': 10000}),
      _expense('DC', 'C', {'D': 8000}),
    ];
    final payments = <SettlementPaymentRecord>[];
    void verify(int ab, int dc) {
      expect(_net(splits, payments, 'A', 'B'), ab);
      expect(_net(splits, payments, 'D', 'C'), dc);
      for (final pair in [('A', 'C'), ('A', 'D'), ('B', 'C'), ('B', 'D')]) {
        expect(_net(splits, payments, pair.$1, pair.$2), 0);
      }
      _assertConservation(splits, payments);
    }

    verify(10000, 8000);
    payments.add(_payment('A', 'B', 4000));
    verify(6000, 8000);
    payments.add(_payment('D', 'C', 8000));
    verify(6000, 0);
    payments.add(_payment('A', 'B', 3000));
    verify(3000, 0);
    payments.add(_payment('A', 'B', 3000));
    verify(0, 0);
    expect(payments.fold<int>(0, (sum, p) => sum + p.amountCents), 18000);
  });

  test('receiver-entered payment has the same effect as sender-entered payment',
      () {
    final splits = [
      _expense('AB', 'B', {'A': 10000})
    ];
    final payment = pendingSettlementPaymentRecord(
      currentUserId: 'B',
      memberUserId: 'A',
      mode: 'from_member',
      amountCents: 4000,
      currency: 'EUR',
    )!;
    expect(_net(splits, [payment], 'A', 'B'), 6000);
    expect(_net(splits, [payment], 'B', 'A'), -6000);
  });

  test('circular debts remain pairwise even when member net positions are zero',
      () {
    final splits = [
      _expense('AB', 'B', {'A': 5000}),
      _expense('BC', 'C', {'B': 5000}),
      _expense('CA', 'A', {'C': 5000}),
    ];
    expect(_net(splits, [], 'A', 'B'), 5000);
    expect(_net(splits, [], 'B', 'C'), 5000);
    expect(_net(splits, [], 'C', 'A'), 5000);
    for (final member in ['A', 'B', 'C']) {
      final nets = computeSettlementNets(
        splits: splits,
        currentUserId: member,
        currencyFilter: 'EUR',
      );
      expect(nets.values.fold<int>(0, (sum, net) => sum + net.netCents), 0);
    }
    _assertConservation(splits, []);
  });

  test('overlapping payers, own shares and reciprocal obligations reconcile',
      () {
    final splits = [
      _expense('B-paid', 'B', {'A': 10000, 'B': 2000}),
      _expense('C-paid', 'C', {'A': 5000}),
      _expense('A-paid', 'A', {'D': 3000}),
      _expense('D-paid', 'D', {'C': 7000}),
      _expense('A-reciprocal', 'A', {'B': 2500}),
    ];
    expect(_net(splits, [], 'A', 'B'), 7500);
    expect(_net(splits, [], 'A', 'C'), 5000);
    expect(_net(splits, [], 'D', 'A'), 3000);
    expect(_net(splits, [], 'C', 'D'), 7000);
    _assertConservation(splits, []);
  });

  test('new expense, edit and delete preserve historical cash payments', () {
    final original = _expense('AB', 'B', {'A': 10000});
    final payments = [_payment('A', 'B', 4000)];
    expect(_net([original], payments, 'A', 'B'), 6000);
    final added = _expense('new', 'B', {'A': 2500});
    expect(_net([original, added], payments, 'A', 'B'), 8500);
    final edited = _expense('AB', 'B', {'A': 7000});
    expect(_net([edited, added], payments, 'A', 'B'), 5500);
    expect(_net([added], payments, 'A', 'B'), -1500);
    expect(_net([], payments, 'A', 'B'), -4000);
    _assertConservation([edited, added], payments);
  });

  test('one-cent, zero, large, settled and foreign-currency rows stay exact',
      () {
    final splits = [
      _expense('cent', 'B', {'A': 1}),
      _expense('zero', 'B', {'A': 0}),
      _expense('large', 'B', {'A': 1000000000000}),
      _expense('settled', 'B', {'A': 10000}, settled: true),
      _expense('usd', 'B', {'A': 90000}, currency: 'USD'),
    ];
    final payments = [_payment('A', 'B', 1)];
    expect(_net(splits, payments, 'A', 'B'), 1000000000000);
    expect(_net(splits, payments, 'A', 'B', currency: 'USD'), 90000);
    _assertConservation(splits, payments);
  });

  test('seeded ledgers match an independent signed ledger in any input order',
      () {
    final random = Random(20261012);
    for (var trial = 0; trial < 100; trial++) {
      final splits = <ExpenseSplitGroup>[];
      final payments = <SettlementPaymentRecord>[];
      final expected = <(String, String), int>{};
      void add(String from, String to, int cents) {
        if (from == to) return;
        expected[(from, to)] = (expected[(from, to)] ?? 0) + cents;
        expected[(to, from)] = (expected[(to, from)] ?? 0) - cents;
      }

      for (var i = 0; i < 40; i++) {
        final payer = _members[random.nextInt(4)];
        final allocations = {
          for (final member in _members) member: random.nextInt(10000),
        };
        splits.add(_expense('$trial-$i', payer, allocations));
        for (final allocation in allocations.entries) {
          add(allocation.key, payer, allocation.value);
        }
      }
      for (var i = 0; i < 20; i++) {
        final debts = expected.entries.where((e) => e.value > 0).toList();
        if (debts.isEmpty) break;
        final debt = debts[random.nextInt(debts.length)];
        final cents = 1 + random.nextInt(debt.value);
        payments.add(_payment(debt.key.$1, debt.key.$2, cents));
        add(debt.key.$1, debt.key.$2, -cents);
      }
      splits.shuffle(random);
      payments.shuffle(random);
      for (final entry in expected.entries) {
        expect(_net(splits, payments, entry.key.$1, entry.key.$2), entry.value,
            reason: 'trial $trial, pair ${entry.key}');
      }
      _assertConservation(splits, payments);
    }
  });
}
