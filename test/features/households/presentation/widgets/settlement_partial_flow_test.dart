import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:moneko/core/sync/mobile_outbox_sync_provider.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/widgets/animated_amount_text.dart';
import 'package:moneko/features/households/data/services/household_service.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/entities/expense_split.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/widgets/settle_up_sheet.dart';
import 'package:moneko/features/households/presentation/widgets/settlement_suggestions_card.dart';
import 'package:moneko/features/households/presentation/pages/settlement_history_page.dart';
import 'package:moneko/l10n/app_localizations.dart';

const _household = '99999999-9999-4999-8999-999999999999';
const _ids = {
  'A': '11111111-1111-4111-8111-111111111111',
  'B': '22222222-2222-4222-8222-222222222222',
  'C': '33333333-3333-4333-8333-333333333333',
  'D': '44444444-4444-4444-8444-444444444444'
};

class _Auth extends Auth {
  _Auth(this.actor);
  final String actor;
  @override
  AppUser build() => AppUser(uid: actor, email: 'test@example.com');
}

class _Service extends Mock implements HouseholdService {}

class _Repository extends Mock implements HouseholdRepository {}

class _Client extends Mock implements SupabaseClient {}

class _AuthClient extends Mock implements GoTrueClient {}

class _User extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://settlement.test',
        anonKey: 'test',
        httpClient: MockClient((request) async => http.Response('{}', 200,
            request: request, headers: {'content-type': 'application/json'})));
  });
  testWidgets(
      'real card and sheet submit four independent partial payments and retain history after remount',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = MonekoDatabase.inMemory();
    addTearDown(database.close);
    final service = _Service();
    final repository = _Repository();
    final client = _Client();
    final auth = _AuthClient();
    final user = _User();
    var actor = _ids['A']!;
    var ab = 10000;
    var dc = 8000;
    final writes = <Map<String, dynamic>>[];
    final events = <Map<String, dynamic>>[];
    final steps = [
      ('A', 'B', 4000, 6000, 8000),
      ('D', 'C', 8000, 6000, 0),
      ('A', 'B', 3000, 3000, 0),
      ('A', 'B', 3000, 0, 0)
    ];
    int net(String other) {
      if (actor == _ids['A'] && other == _ids['B']) return ab;
      if (actor == _ids['B'] && other == _ids['A']) return -ab;
      if (actor == _ids['D'] && other == _ids['C']) return dc;
      if (actor == _ids['C'] && other == _ids['D']) return -dc;
      return 0;
    }

    Map<String, dynamic> balance(String other) {
      final value = net(other);
      final original = (actor == _ids['A'] && other == _ids['B'])
          ? 10000
          : (actor == _ids['D'] && other == _ids['C'])
              ? 8000
              : value.abs();
      return {
        'other_user_id': other,
        'currency': 'EUR',
        'split_to_cents': value < 0 ? 0 : original,
        'split_from_cents': value < 0 ? original : 0,
        'paid_to_cents': value < 0 ? 0 : original - value,
        'paid_from_cents': 0,
        'net_cents': value
      };
    }

    String token() =>
        'v1:${(writes.length + 10).toRadixString(16).padLeft(64, '0')}';
    when(() => user.id).thenAnswer((_) => actor);
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.auth).thenReturn(auth);
    final date = DateTime.utc(2026, 10, 12);
    final members = [
      for (final e in _ids.entries)
        HouseholdMember(
            id: e.value,
            householdId: _household,
            userId: e.value,
            role: HouseholdRole.member,
            userName: e.key,
            joinedAt: date,
            createdAt: date,
            updatedAt: date)
    ];
    when(() => repository.getHouseholdMembers(_household))
        .thenAnswer((_) async => members);
    final splits = [
      for (final pair in [('B', 'A', 10000), ('C', 'D', 8000)])
        ExpenseSplitGroup(
            id: 'group-${pair.$1}',
            householdId: _household,
            expenseId: 'expense-${pair.$1}',
            payerUserId: _ids[pair.$1]!,
            splitType: SplitType.amount,
            currency: 'EUR',
            totalAmountCents: pair.$3,
            createdAt: date,
            updatedAt: date,
            splitLines: [
              ExpenseSplitLine(
                  id: 'line-${pair.$1}',
                  splitGroupId: 'group-${pair.$1}',
                  userId: _ids[pair.$2]!,
                  amountCents: pair.$3,
                  isSettled: false,
                  createdAt: date,
                  updatedAt: date)
            ])
    ];
    when(() => repository.getHouseholdSplits(householdId: _household))
        .thenAnswer((_) async => splits);
    when(() => service.getPairwiseSettlementBalancesV2(
            householdId: _household, currency: 'EUR'))
        .thenAnswer((_) async => [
              for (final other in _ids.values.where((id) => id != actor))
                balance(other)
            ]);
    when(() => service.getSettlementCalculationV3(
        householdId: _household,
        memberUserId: any(named: 'memberUserId'),
        currency: 'EUR')).thenAnswer((call) async {
      final other = call.namedArguments[#memberUserId] as String;
      return {
        ...balance(other),
        'snapshot_version': 1,
        'snapshot_token': token(),
        'household_id': _household,
        'member_user_id': other,
        'rows': <dynamic>[]
      };
    });
    when(() => service.getHouseholdSettlementEvents(_household)).thenAnswer(
        (_) async => events
            .where((e) =>
                e['payer_user_id'] == actor ||
                e['participant_user_id'] == actor)
            .toList());
    when(() => service.settleAmountAndNotifyV2(
        householdId: _household,
        memberUserId: any(named: 'memberUserId'),
        mode: any(named: 'mode'),
        amountCents: any(named: 'amountCents'),
        currency: 'EUR',
        expectedSnapshotToken: any(named: 'expectedSnapshotToken'),
        clientMutationId: any(named: 'clientMutationId'),
        settlementNote: any(named: 'settlementNote'))).thenAnswer((call) async {
      final step = steps[writes.length];
      final arguments = call.namedArguments;
      expect(actor, _ids[step.$1]);
      expect(arguments[#memberUserId], _ids[step.$2]);
      expect(arguments[#amountCents], step.$3);
      expect(arguments[#mode], 'both');
      expect(arguments[#expectedSnapshotToken], token());
      final before = net(arguments[#memberUserId] as String);
      writes
          .add({for (final e in arguments.entries) e.key.toString(): e.value});
      ab = step.$4;
      dc = step.$5;
      final id = 'event-${writes.length}';
      events.add({
        'id': id,
        'household_id': _household,
        'actor_user_id': actor,
        'participant_user_id': actor,
        'payer_user_id': _ids[step.$2],
        'amount_cents': step.$3,
        'currency': 'EUR',
        'is_express_netting': true,
        'created_at':
            date.add(Duration(seconds: writes.length)).toIso8601String(),
        'settlement_note': arguments[#settlementNote],
        'client_mutation_id': arguments[#clientMutationId]
      });
      return {
        'status': 'applied',
        'replayed': false,
        'client_mutation_id': arguments[#clientMutationId],
        'settlement_event_id': id,
        'requested_amount_cents': step.$3,
        'applied_amount_cents': step.$3,
        'pair_balance_before_cents': before,
        'pair_balance_after_cents': net(_ids[step.$2]!),
        'current_net_cents': net(_ids[step.$2]!),
        'cleared_pair_balance': net(_ids[step.$2]!) == 0,
        'result_snapshot_token': token()
      };
    });
    Future<void> mount(String name, int generation) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      actor = _ids[name]!;
      await tester.pumpWidget(ProviderScope(
          key: ValueKey(generation),
          overrides: [
            authProvider.overrideWith(() => _Auth(actor)),
            localDatabaseProvider.overrideWith((ref) async => database),
            supabaseClientProvider.overrideWithValue(client),
            mobileOutboxSupabaseClientProvider.overrideWithValue(client),
            householdServiceProvider.overrideWithValue(service),
            householdRepositoryProvider.overrideWithValue(repository),
            homeFilterProvider.overrideWith(
                (ref) => HomeFilterNotifier()..setSelectedCurrency('EUR')),
            cachedHouseholdExpensesProvider.overrideWith((ref, p) async => []),
            cachedHouseholdSplitsProvider
                .overrideWith((ref, p) async => splits),
          ],
          child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(
                  body: ListView(children: [
                SettlementSuggestionsCard(
                    householdId: _household,
                    currency: 'EUR',
                    selectedCurrencies: const ['EUR'],
                    currentUserId: actor,
                    members: members)
              ])))));
      await tester.pumpAndSettle();
    }

    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      await mount(step.$1, i);
      final row = find.text('You owe ${step.$2}');
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<SettleUpSheet>(find.byType(SettleUpSheet))
              .specificMemberId,
          _ids[step.$2]);
      await tester.tap(find.text('Settle').last);
      // The sheet remains processing while the amount dialog awaits the user.
      for (var wait = 0;
          wait < 30 && find.byType(TextField).evaluate().length < 2;
          wait++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(
          find.byType(TextField).first, (step.$3 / 100).toStringAsFixed(2));
      await tester.enterText(find.byType(TextField).last, 'payment-$i');
      await tester.tap(find.text('Settle').last);
      await tester.pumpAndSettle();
      expect(writes.length, i + 1);
      expect(ab, step.$4);
      expect(dc, step.$5);
      final remaining = step.$1 == 'A' ? ab : dc;
      final displayed = tester
          .widgetList<AnimatedAmountText>(find.descendant(
            of: find.byType(SettlementSuggestionsCard),
            matching: find.byType(AnimatedAmountText),
          ))
          .map((amount) => amount.value)
          .toList();
      expect(
          displayed,
          remaining == 0
              ? isEmpty
              : equals([remaining / 100, 0.0, remaining / 100]));
      expect(find.byType(SettleUpSheet), findsNothing);
      expect(
          await database.getPendingHouseholdSettlementMutations(
              householdId: _household),
          isEmpty);
      expect(tester.takeException(), isNull);
    }
    expect(events.map((e) => e['client_mutation_id']).toSet().length, 4);
    verifyNever(() => repository.getHouseholdSplits(householdId: _household));
    await mount('A', 10);
    await tester.tap(find.byIcon(Icons.history_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(SettlementHistoryPage), findsOneWidget);
    expect(find.text('3 settlements'), findsOneWidget);
    for (final i in [0, 2, 3]) {
      expect(find.text('payment-$i'), findsOneWidget);
    }
    expect(find.text('payment-1'), findsNothing);
    expect(tester.getCenter(find.text('A').first).dx,
        lessThan(tester.getCenter(find.text('B').first).dx));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
