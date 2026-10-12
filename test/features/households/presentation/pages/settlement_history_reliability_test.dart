import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/pages/settlement_history_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';

const _household = '00000000-0000-0000-0000-000000000001';

class _Auth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'me', email: 'me@example.com');
}

class _Repository extends Mock implements HouseholdRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://settlement.test',
        anonKey: 'test',
        httpClient: MockClient((request) async => http.Response('[]', 200,
            request: request, headers: {'content-type': 'application/json'})));
  });

  testWidgets(
      'older than 200 payments remain accessible through the real history page',
      (tester) async {
    final repository = _Repository();
    final date = DateTime.utc(2026, 10, 12);
    when(() => repository.getHouseholdMembers(_household))
        .thenAnswer((_) async => [
              for (final id in ['me', 'alex'])
                HouseholdMember(
                    id: id,
                    householdId: _household,
                    userId: id,
                    role: HouseholdRole.member,
                    joinedAt: date,
                    createdAt: date,
                    updatedAt: date,
                    userName: id == 'me' ? 'Me' : 'Alex'),
            ]);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(_Auth.new),
          householdRepositoryProvider.overrideWithValue(repository),
          homeFilterProvider.overrideWith(
              (ref) => HomeFilterNotifier()..setSelectedCurrency('EUR')),
          householdSettlementEventsProvider
              .overrideWith((ref, householdId) async => [
                    for (var i = 0; i < 201; i++)
                      {
                        'id': 'event-$i',
                        'household_id': _household,
                        'created_at':
                            date.subtract(Duration(days: i)).toIso8601String(),
                        'payer_user_id': 'alex',
                        'participant_user_id': 'me',
                        'actor_user_id': 'me',
                        'amount_cents': 100,
                        'currency': 'EUR',
                        'is_express_netting': true,
                        'settlement_note':
                            i == 200 ? 'oldest-payment' : 'payment-$i',
                      },
                  ]),
        ],
        child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: SettlementHistoryPage(householdId: _household))));
    await tester.pumpAndSettle();
    expect(find.text('201 settlements'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('oldest-payment'), 600,
        scrollable: find.byType(Scrollable).first, maxScrolls: 200);
    await tester.pumpAndSettle();
    expect(find.text('oldest-payment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
