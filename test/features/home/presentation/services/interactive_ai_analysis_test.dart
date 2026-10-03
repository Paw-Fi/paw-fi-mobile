import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/services/interactive_ai_analysis.dart';

Map<String, dynamic> ready(List<Map<String, dynamic>> items) => {
      'success': true,
      'data': {
        'interactiveVersion': 1,
        'requireCorrection': false,
        'items': items
      },
    };
Map<String, dynamic> item(String? household, String? wallet, String currency) =>
    {
      'type': 'expense',
      'amount': 70,
      'category': 'groceries',
      'currency': currency,
      'currencySymbol': currency,
      'date': '2026-09-30',
      'transactionTime': '18:30:00',
      'merchant': '小商店',
      'destination': {
        'householdId': household,
        'accountId': wallet,
        'accountCurrency': wallet == null ? null : currency,
        'isPortfolio': false,
        'spaceLabel': household ?? 'Personal'
      },
    };
final correction = {
  'success': true,
  'data': {
    'interactiveVersion': 1,
    'requireCorrection': true,
    'items': [],
    'correction': {
      'question': '残りの30は誰に？',
      'choices': ['私に30', 'アリスに30'],
      'allowCustomResponse': true
    }
  },
};

void main() {
  test(
      'clarification resubmits original source and answer before returning items',
      () async {
    final requests = <Map<String, dynamic>>[];
    final response = await runInteractiveAiAnalysis(
      body: {'text': '家族で100、アリス50、自分20'},
      invoke: (body) async {
        requests.add(body);
        return requests.length == 1
            ? correction
            : ready([item('family', 'wallet', 'USD')]);
      },
      ask: (question) async {
        expect(question.choices.length, 2);
        return '合計は70です';
      },
      retry: (_) async => false,
      isActive: () => true,
    );
    expect(requests.length, 2);
    expect(requests.last['text'], '家族で100、アリス50、自分20');
    expect((requests.last['interactive'] as Map)['answers'], [
      {'question': '残りの30は誰に？', 'answer': '合計は70です'}
    ]);
    expect(response?['data']['requireCorrection'], false);
  });

  test('dismissing clarification returns no transaction to save', () async {
    final response = await runInteractiveAiAnalysis(
        body: {'text': '100 dinner'},
        invoke: (_) async => correction,
        ask: (_) async => null,
        retry: (_) async => false,
        isActive: () => true);
    expect(response, isNull);
  });

  test('retry retains source and clarification history without a save',
      () async {
    var calls = 0;
    final response = await runInteractiveAiAnalysis(
        body: {'text': '70 dinner'},
        invoke: (_) async {
          calls++;
          if (calls == 1) throw StateError('offline');
          return ready([item(null, null, 'EUR')]);
        },
        ask: (_) async => null,
        retry: (_) async => true,
        isActive: () => true);
    expect(calls, 2);
    expect(response, isNotNull);
  });

  test('unnegotiated legacy response never silently auto-saves', () async {
    var retries = 0;
    final response = await runInteractiveAiAnalysis(
        body: {'text': '70 dinner'},
        invoke: (_) async => {
              'success': true,
              'data': {
                'items': [item(null, null, 'EUR')]
              }
            },
        ask: (_) async => null,
        retry: (_) async {
          retries++;
          return false;
        },
        isActive: () => true);
    expect(response, isNull);
    expect(retries, 1);
  });

  test('auth or route changes stop the clarification flow', () async {
    var active = true;
    final response = await runInteractiveAiAnalysis(
        body: {'text': '70 dinner'},
        invoke: (_) async {
          active = false;
          return ready([item(null, null, 'EUR')]);
        },
        ask: (_) async => fail('must not ask'),
        retry: (_) async => false,
        isActive: () => active);
    expect(response, isNull);
  });

  test('destinations group independently and keep native wallets', () {
    final items = [
      item('family', 'usd', 'USD'),
      item(null, 'eur', 'EUR'),
      item('family', 'usd', 'USD')
    ];
    final groups = groupInteractiveAiItems(items);
    expect(groups.length, 2);
    expect(groups.entries.first.key.householdId, 'family');
    expect(groups.entries.first.value.length, 2);
    expect(groups.entries.last.key.householdId, isNull);
    expect(groups.entries.last.key.accountId, 'eur');
  });

  test('malformed destinations and wallet currency conflicts block all items',
      () {
    expect(
        () => groupInteractiveAiItems([
              item(null, 'eur', 'EUR'),
              {'amount': 2}
            ]),
        throwsFormatException);
    final wrong = item('family', 'usd', 'USD');
    (wrong['destination'] as Map)['accountCurrency'] = 'EUR';
    expect(() => groupInteractiveAiItems([wrong]), throwsFormatException);
  });
}
