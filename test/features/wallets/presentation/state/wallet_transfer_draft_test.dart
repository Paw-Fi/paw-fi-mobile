import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/wallets/presentation/state/wallet_transfer_draft.dart';

void main() {
  WalletTransferDraftController controller({String target = 'EUR'}) =>
      WalletTransferDraftController(WalletTransferDraft(
        sourceCurrency: 'USD',
        targetCurrency: target,
      ));

  test(
      'suggestion fills missing amount, then each amount keeps the other fixed',
      () {
    final draft = controller();
    addTearDown(draft.dispose);
    draft.setSource(10000);
    expect(draft.state.targetCents, isNull);
    draft.suggestRate('0.91');
    expect(draft.state.targetCents, 9100);
    draft.setSource(20000);
    expect(draft.state.targetCents, 9100);
    expect(draft.state.rate, '0.455');
    draft.setTarget(18000);
    expect(draft.state.sourceCents, 20000);
    expect(draft.state.rate, '0.9');
    draft.setRate('0.92');
    expect(draft.state.sourceCents, 20000);
    expect(draft.state.targetCents, 18400);
  });

  test('late suggestions cannot overwrite manual rates or paired amounts', () {
    final draft = controller();
    addTearDown(draft.dispose);
    draft.setSource(10000);
    draft.setTarget(9000);
    draft.suggestRate('0.95');
    expect(draft.state.targetCents, 9000);
    expect(draft.state.rate, '0.9');
    draft.setRate('0.93');
    draft.suggestRate('0.96');
    expect(draft.state.targetCents, 9300);
  });

  test('entering received amount first fills missing source from suggestion',
      () {
    final draft = controller();
    addTearDown(draft.dispose);
    draft.setTarget(9100);
    draft.suggestRate('0.91');
    expect(draft.state.sourceCents, 10000);
    expect(draft.state.targetCents, 9100);
    expect(draft.state.isValid, isTrue);
  });

  test(
      'same currency mirrors principals at rate one and adds fee only to debit',
      () {
    final draft = controller(target: 'USD');
    addTearDown(draft.dispose);
    draft.setSource(10000);
    draft.setFee(200);
    expect(draft.state.targetCents, 10000);
    expect(draft.state.rate, '1');
    expect(draft.state.totalDebitCents, 10200);
    expect(draft.state.isValid, isTrue);
    draft.setTarget(8000);
    expect(draft.state.sourceCents, 8000);
  });

  test('swap exchanges native principals and clears source-currency fee', () {
    final draft = controller();
    addTearDown(draft.dispose);
    draft.setSource(10000);
    draft.setTarget(9000);
    draft.setFee(200);
    draft.swap();
    expect(draft.state.sourceCurrency, 'EUR');
    expect(draft.state.sourceCents, 9000);
    expect(draft.state.targetCents, 10000);
    expect(draft.state.feeCents, 0);
    expect(convertTransferCents(9000, draft.state.rate!), 10000);
  });

  test('changing wallet currency clears only affected amount and stale rate',
      () {
    final draft = controller();
    addTearDown(draft.dispose);
    draft.setSource(10000);
    draft.setTarget(9000);
    draft.setFee(200);
    draft.changeCurrencies('USD', 'SGD');
    expect(draft.state.sourceCents, 10000);
    expect(draft.state.targetCents, isNull);
    expect(draft.state.rate, isNull);
    expect(draft.state.feeCents, 200);
    draft.suggestRate('1.3');
    expect(draft.state.targetCents, 13000);
    draft.changeCurrencies('EUR', 'SGD');
    expect(draft.state.sourceCents, isNull);
    expect(draft.state.targetCents, 13000);
    expect(draft.state.feeCents, 0);
  });

  test('decimal rates round once and derived rates preserve exact principals',
      () {
    expect(convertTransferCents(1000, '0.9231'), 923);
    expect(convertTransferCents(1, '0.565'), 1);
    expect(convertTransferCents(10000, '1e-3'), 10);
    for (final pair in [(1890, 2000), (9007199254740990, 1), (3, 10000)]) {
      final rate = deriveTransferRate(pair.$1, pair.$2);
      expect(convertTransferCents(pair.$1, rate), pair.$2);
    }
    expect(convertTransferCents(100, 'NaN'), isNull);
    expect(convertTransferCents(100, '-1'), isNull);
    expect(convertTransferCents(100, '0'), isNull);
    expect(normalizeTransferRate('1e-15'), '0.000000000000001');
    expect(
        normalizeTransferRate('0.923456789123456789'), '0.923456789123456789');
    expect(normalizeTransferRate('10'), '10');
  });

  test('invalid and overflowing amounts cannot be saved', () {
    final draft = controller();
    addTearDown(draft.dispose);
    draft.setSource(10000);
    draft.setRate('0');
    expect(draft.state.isValid, isFalse);
    draft.setRate('0.9');
    draft.setFee(-1);
    expect(draft.state.isValid, isFalse);
    draft.setFee(9007199254740991);
    expect(draft.state.isValid, isFalse);
  });
}
