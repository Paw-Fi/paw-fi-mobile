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
  test('receipt clarification retains the image and original dropdown defaults',
      () async {
    final image = {'data': 'cmVjZWlwdA==', 'contentType': 'image/jpeg'};
    final requests = <Map<String, dynamic>>[];
    final response = await runInteractiveAiAnalysis(
      body: {
        'image': image,
        'householdId': 'family',
        'accountId': 'selected-wallet',
        'language': 'ja',
      },
      invoke: (request) async {
        requests.add(request);
        expect(request['image'], image);
        expect(request['householdId'], 'family');
        expect(request['accountId'], 'selected-wallet');
        return requests.length == 1
            ? correction
            : ready([item('family', 'selected-wallet', 'JPY')]);
      },
      ask: (_) async => '合計は７０円です',
      retry: (_) async => fail('receipt clarification must use the MCQ loop'),
      isActive: () => true,
    );
    expect(requests, hasLength(2));
    expect((requests.last['interactive'] as Map)['answers'], [
      {'question': '残りの30は誰に？', 'answer': '合計は７０円です'}
    ]);
    expect(response?['data']['requireCorrection'], false);
  });

  test(
      'a saved question reopens before analysis and custom answers checkpoint before invocation',
      () async {
    final events = <String>[];
    final answers = [
      {'question': '金額は？', 'answer': '７０円'}
    ];
    final result = await runInteractiveAiAnalysis(
      body: {'text': '買い物'},
      initialAnswers: answers,
      initialQuestion: AiAnalysisQuestion.fromJson(
          (correction['data'] as Map)['correction']),
      ask: (question) async {
        events.add('ask');
        return '家族に３０円';
      },
      checkpoint: (savedAnswers, question, clock) async {
        events.add('checkpoint');
        expect(savedAnswers, [
          ...answers,
          {'question': '残りの30は誰に？', 'answer': '家族に３０円'}
        ]);
        expect(question, isNull);
      },
      invoke: (request) async {
        events.add('invoke');
        expect((request['interactive'] as Map)['answers'], hasLength(2));
        return ready([item(null, null, 'JPY')]);
      },
      retry: (_) async => false,
      isActive: () => true,
    );
    expect(result, isNotNull);
    expect(events, ['ask', 'checkpoint', 'invoke']);
    expect(answers, hasLength(1));
  });

  test(
      'a dismissed question is checkpointed with no transaction save or second request',
      () async {
    final events = <String>[];
    final result = await runInteractiveAiAnalysis(
      body: {'text': '買い物'},
      invoke: (_) async {
        events.add('invoke');
        return correction;
      },
      checkpoint: (answers, question, issue) async {
        events.add('checkpoint');
        expect(question?.question, '残りの30は誰に？');
        expect(answers, isEmpty);
      },
      ask: (_) async {
        events.add('ask');
        return null;
      },
      retry: (_) async => false,
      isActive: () => true,
    );
    expect(result, isNull);
    expect(events, ['invoke', 'checkpoint', 'ask']);
  });

  test(
      'an accepted answer persists if the app pauses immediately before its next request',
      () async {
    var active = true;
    var checkpointed = false;
    var requests = 0;
    final result = await runInteractiveAiAnalysis(
      body: {'text': '買い物'},
      invoke: (_) async {
        requests++;
        return correction;
      },
      ask: (_) async {
        active = false;
        return '私に３０円';
      },
      checkpoint: (answers, question, issue) async {
        if (answers.isNotEmpty) {
          checkpointed = true;
          expect(answers.single['answer'], '私に３０円');
        }
      },
      retry: (_) async => false,
      isActive: () => active,
    );
    expect(result, isNull);
    expect(requests, 1);
    expect(checkpointed, isTrue);
  });

  test('AI default day follows the configured IANA timezone', () {
    final now = DateTime.utc(2026, 10, 2, 23, 30);
    expect(aiAnalysisWallNow(preferredTimezone: 'Asia/Tokyo', at: now).day, 3);
    expect(
        aiAnalysisWallNow(preferredTimezone: 'America/New_York', at: now).day,
        2);
  });

  test('nonexistent and repeated daylight-saving clocks require clarification',
      () async {
    for (final values in [
      ('2026-03-08', '02:30:00', 'nonexistent_wall_time'),
      ('2026-11-01', '01:30:00', 'ambiguous_wall_time'),
    ]) {
      final requests = <Map<String, dynamic>>[];
      final ambiguous = item(null, null, 'USD')
        ..['date'] = values.$1
        ..['transactionTime'] = values.$2;
      var asks = 0;
      final result = await runInteractiveAiAnalysis(
          body: {'text': 'clock'},
          preferredTimezone: 'America/New_York',
          invoke: (request) async {
            requests.add(request);
            if (requests.length == 1) return ready([ambiguous]);
            if (requests.length == 2) return correction;
            return ready([
              {...ambiguous}..remove('transactionTime')
            ]);
          },
          ask: (_) async {
            asks++;
            return '記録は日付のみで、時刻は不要';
          },
          retry: (_) async => fail('must clarify, not retry'),
          isActive: () => true);
      expect(result, isNotNull);
      expect(asks, 1);
      expect((requests[1]['interactive'] as Map)['clientIssue'],
          {'itemIndex': 0, 'field': 'transactionTime', 'reason': values.$3});
      expect((requests[2]['interactive'] as Map).containsKey('clientIssue'),
          false);
    }
  });

  test('an old server cannot cause an infinite unresolved clock loop',
      () async {
    var calls = 0;
    var retries = 0;
    final ambiguous = item(null, null, 'USD')
      ..['date'] = '2026-11-01'
      ..['transactionTime'] = '01:30:00';
    final result = await runInteractiveAiAnalysis(
        body: {'text': 'clock'},
        preferredTimezone: 'America/New_York',
        invoke: (_) async {
          calls++;
          return ready([ambiguous]);
        },
        ask: (_) async => fail('must not invent a question'),
        retry: (_) async {
          retries++;
          return false;
        },
        isActive: () => true);
    expect(result, isNull);
    expect(calls, 2);
    expect(retries, 1);
  });
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

  test(
      'verified category, merchant, date, time and allocations survive grouping',
      () {
    final verified = item('family', 'wallet', 'USD')
      ..['category'] = '家族の食費'
      ..['description'] = '昨夜の夕食'
      ..['payerUserId'] = 'alice'
      ..['customSplits'] = {
        'splitType': 'amount',
        'memberSplits': [
          {'userId': 'alice', 'amount': 50},
          {'userId': 'me', 'amount': 20},
          {'userId': 'bob', 'amount': 0}
        ]
      };
    final result = groupInteractiveAiItems([verified]).values.single.single;
    expect(result, verified);
    expect(result['category'], '家族の食費');
    expect(result['transactionTime'], '18:30:00');
    expect(result['payerUserId'], 'alice');
  });

  test('invalid financial details block the complete ready response', () async {
    for (final patch in [
      {'amount': 70.001},
      {'payerUserId': 42},
      {'transactionTime': '6:30 PM'},
      {'isRecurring': 'true'},
      {
        'recurrence_rule': {'frequency': 'monthly'}
      },
      {
        'customSplits': {
          'splitType': 'amount',
          'memberSplits': [
            {'userId': 'alice', 'amount': 50},
            {'userId': 'me', 'amount': 19}
          ]
        }
      },
      {
        'customSplits': {
          'splitType': 'shares',
          'memberSplits': [
            {'userId': 'alice', 'shares': 0}
          ]
        }
      },
    ]) {
      var retries = 0;
      final result = await runInteractiveAiAnalysis(
        body: {'text': '夕食70'},
        invoke: (_) async => ready([
          item(null, null, 'EUR'),
          {...item('family', 'wallet', 'USD'), ...patch}
        ]),
        ask: (_) async =>
            fail('Invalid ready data must not ask a fabricated question'),
        retry: (_) async {
          retries++;
          return false;
        },
        isActive: () => true,
      );
      expect(result, isNull, reason: patch.toString());
      expect(retries, 1);
    }
  });

  test('verified recurrence retains dates and rejects an unsupported clock',
      () {
    final recurring = item(null, null, 'EUR')
      ..remove('transactionTime')
      ..['isRecurring'] = true
      ..['recurrence_rule'] = {
        'frequency': 'monthly',
        'interval': 1,
        'anchor_date': '2026-09-30',
        'end_date': '2027-09-30'
      };
    expect(
        groupInteractiveAiItems([recurring]).values.single.single, recurring);
    expect(
        () => groupInteractiveAiItems([
              {...recurring, 'transactionTime': '00:00:00'}
            ]),
        throwsFormatException);
    final wrong = {
      ...recurring,
      'recurrence_rule': {
        'frequency': 'monthly',
        'interval': 1,
        'anchor_date': '2026-10-01'
      }
    };
    expect(() => groupInteractiveAiItems([wrong]), throwsFormatException);
  });

  test('clarification retry retains multiple answers and latest corrections',
      () async {
    final requests = <Map<String, dynamic>>[];
    var answers = 0;
    final result = await runInteractiveAiAnalysis(
      body: {'text': '١٠٠ للعشاء، أليس ٥٠ وأنا ٢٠'},
      invoke: (request) async {
        requests.add(request);
        if (requests.length == 3) throw StateError('offline');
        return requests.length <= 2
            ? correction
            : ready([item('family', 'wallet', 'USD')]);
      },
      ask: (_) async => ++answers == 1 ? 'المجموع ٧٠' : 'استخدم محفظة السفر',
      retry: (_) async => true,
      isActive: () => true,
    );
    expect(result, isNotNull);
    expect(answers, 2);
    expect(requests[2]['interactive'], requests[3]['interactive']);
    expect((requests.last['interactive'] as Map)['answers'], [
      {'question': '残りの30は誰に？', 'answer': 'المجموع ٧٠'},
      {'question': '残りの30は誰に？', 'answer': 'استخدم محفظة السفر'}
    ]);
  });

  test('clarification limit exits without retrying an exhausted history',
      () async {
    var calls = 0;
    var questions = 0;
    var errors = 0;
    final result = await runInteractiveAiAnalysis(
      body: {'text': '夕食70'},
      invoke: (_) async {
        calls++;
        return correction;
      },
      ask: (_) async {
        questions++;
        return '家族';
      },
      retry: (_) async {
        errors++;
        return true;
      },
      isActive: () => true,
    );
    expect(result, isNull);
    expect(calls, 13);
    expect(questions, 12);
    expect(errors, 1);
  });

  test('audio and source context survive a clarification round trip', () async {
    final source = {
      'audio': {'data': 'recording', 'contentType': 'audio/mp4'},
      'accountId': 'usd',
      'date': '2026-09-30'
    };
    var calls = 0;
    await runInteractiveAiAnalysis(
      body: source,
      invoke: (request) async {
        expect(request['audio'], source['audio']);
        expect(request['accountId'], 'usd');
        return ++calls == 1
            ? correction
            : ready([item('family', 'usd', 'USD')]);
      },
      ask: (_) async => '旅行',
      retry: (_) async => false,
      isActive: () => true,
    );
    expect(calls, 2);
  });

  test('duplicate normalized clarification choices are rejected', () {
    expect(
        () => AiAnalysisQuestion.fromJson({
              'question': '財布？',
              'choices': ['旅行', ' 旅行 '],
              'allowCustomResponse': true
            }),
        throwsFormatException);
  });
}
