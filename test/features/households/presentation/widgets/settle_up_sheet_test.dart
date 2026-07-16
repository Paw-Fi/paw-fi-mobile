import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/presentation/utils/settlement_input_utils.dart';

void main() {
  group('settlement amount parsing', () {
    test('accepts the untouched numeric max and locale decimal commas', () {
      expect(parseSettlementAmountCents('66.11'), 6611);
      expect(parseSettlementAmountCents('66,11'), 6611);
      expect(parseSettlementAmountCents('1,234.56'), 123456);
      expect(parseSettlementAmountCents('1.234,56'), 123456);
      expect(parseSettlementAmountCents('1 234,56'), 123456);
      expect(parseSettlementAmountCents('1\u00A0234.56'), 123456);
      expect(parseSettlementAmountCents('1\u202F234,56'), 123456);
    });

    test('rejects currency text, blank, zero, negative, and garbage', () {
      expect(parseSettlementAmountCents(null), isNull);
      expect(parseSettlementAmountCents(''), isNull);
      expect(parseSettlementAmountCents('   '), isNull);
      expect(parseSettlementAmountCents('0'), isNull);
      expect(parseSettlementAmountCents('0.00'), isNull);
      expect(parseSettlementAmountCents('-1'), isNull);
      expect(parseSettlementAmountCents(r'C$-1'), isNull);
      expect(parseSettlementAmountCents(r'$66.11'), isNull);
      expect(parseSettlementAmountCents(r'C$66.11'), isNull);
      expect(parseSettlementAmountCents('CAD 66.11'), isNull);
      expect(parseSettlementAmountCents('USD 66.11'), isNull);
      expect(parseSettlementAmountCents('66,11 CAD'), isNull);
      expect(parseSettlementAmountCents('garbage'), isNull);
      expect(parseSettlementAmountCents('garbage 66.11'), isNull);
      expect(parseSettlementAmountCents('XYZ 66.11'), isNull);
      expect(parseSettlementAmountCents('1,2,3'), isNull);
      expect(parseSettlementAmountCents('12..34'), isNull);
      expect(parseSettlementAmountCents('12.'), isNull);
      expect(parseSettlementAmountCents('1.234'), isNull);
      expect(parseSettlementAmountCents('66,111'), isNull);
      expect(parseSettlementAmountCents('1,2345'), isNull);
      expect(parseSettlementAmountCents('12.3456'), isNull);
      expect(parseSettlementAmountCents('66 11'), isNull);
      expect(parseSettlementAmountCents('1 23'), isNull);
      expect(parseSettlementAmountCents('12 34 567'), isNull);
    });
  });

  group('settlement amount clamping', () {
    test('never converts a missing or invalid request into a full settlement',
        () {
      expect(
        clampSettlementAmountCents(requestedCents: null, maxCents: 6611),
        isNull,
      );
      expect(
        clampSettlementAmountCents(requestedCents: 0, maxCents: 6611),
        isNull,
      );
      expect(
        clampSettlementAmountCents(requestedCents: -1, maxCents: 6611),
        isNull,
      );
    });

    test('keeps valid values and rejects values above max', () {
      expect(
        clampSettlementAmountCents(requestedCents: 2500, maxCents: 6611),
        2500,
      );
      expect(
        clampSettlementAmountCents(requestedCents: 6611, maxCents: 6611),
        6611,
      );
      expect(
        clampSettlementAmountCents(requestedCents: 9999, maxCents: 6611),
        isNull,
      );
      expect(
        clampSettlementAmountCents(requestedCents: 100, maxCents: 0),
        isNull,
      );
    });
  });

  group('authoritative balance request races', () {
    test('accepts only the latest matching member and currency response', () {
      expect(
        isCurrentSettlementBalanceRequest(
          requestGeneration: 3,
          currentGeneration: 3,
          requestedMemberId: 'alex',
          currentMemberId: 'alex',
          requestedCurrencyCode: 'CAD',
          currentCurrencyCode: 'CAD',
        ),
        isTrue,
      );
      expect(
        isCurrentSettlementBalanceRequest(
          requestGeneration: 2,
          currentGeneration: 3,
          requestedMemberId: 'alex',
          currentMemberId: 'alex',
          requestedCurrencyCode: 'CAD',
          currentCurrencyCode: 'CAD',
        ),
        isFalse,
      );
      expect(
        isCurrentSettlementBalanceRequest(
          requestGeneration: 3,
          currentGeneration: 3,
          requestedMemberId: 'alex',
          currentMemberId: 'sam',
          requestedCurrencyCode: 'CAD',
          currentCurrencyCode: 'CAD',
        ),
        isFalse,
      );
      expect(
        isCurrentSettlementBalanceRequest(
          requestGeneration: 3,
          currentGeneration: 3,
          requestedMemberId: 'alex',
          currentMemberId: 'alex',
          requestedCurrencyCode: 'CAD',
          currentCurrencyCode: 'USD',
        ),
        isFalse,
      );
    });
  });

  group('settlement mutation IDs', () {
    test('contain 128 bits of random entropy and do not repeat', () {
      final random = math.Random(42);
      final now = DateTime.utc(2026, 7, 16, 12);

      final first = generateSettlementClientMutationId(
        now: now,
        random: random,
      );
      final second = generateSettlementClientMutationId(
        now: now,
        random: random,
      );

      expect(
        first,
        matches(RegExp(r'^mobile:settlement:\d+:[0-9a-f]{32}$')),
      );
      expect(second, isNot(first));
    });
  });
}
