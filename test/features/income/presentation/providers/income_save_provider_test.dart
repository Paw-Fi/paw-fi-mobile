import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/income/presentation/providers/income_providers.dart';

void main() {
  late Future<http.Response> Function(http.Request request) requestHandler;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'anon',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) => requestHandler(request)),
    );
  });

  test('saveIncome sends household custom splits and payer user id', () async {
    Map<String, dynamic>? capturedSaveBody;
    requestHandler = (request) async {
      if (request.url.path.endsWith('/functions/v1/save-income')) {
        capturedSaveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'income_1',
              'date': '2026-04-20',
              'category': 'income:salary',
              'amount_cents': 12000,
              'currency': 'USD',
              'household_id': 'hh_1',
              'owner_type': 'me',
              'privacy_scope': 'full',
              'is_recurring': false,
              'created_at': '2026-04-20T10:00:00.000Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (request.url.path.endsWith('/functions/v1/list-income')) {
        return http.Response(
          jsonEncode({'success': true, 'data': <Map<String, dynamic>>[]}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (request.url.path.endsWith('/functions/v1/income-summary')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'totalIncome': 0,
              'currency': 'USD',
              'categoryBreakdown': <String, double>{},
              'transactionCount': 0,
              'period': {
                'startDate': '2026-04-01',
                'endDate': '2026-04-30',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response(
        jsonEncode({'success': false, 'error': 'unexpected request'}),
        404,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    };

    final members = [
      HouseholdMember(
        id: 'm1',
        householdId: 'hh_1',
        userId: 'user_1',
        role: HouseholdRole.owner,
        joinedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      HouseholdMember(
        id: 'm2',
        householdId: 'hh_1',
        userId: 'user_2',
        role: HouseholdRole.member,
        joinedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];
    final container = ProviderContainer(overrides: [
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.household,
          selected: SelectedHouseholdState(householdId: 'hh_1'),
          portfolioHouseholdIds: {},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final saved = await container.read(incomeSaveProvider.notifier).saveIncome(
          userId: 'user_1',
          amount: 120,
          category: 'income:salary',
          currency: 'USD',
          date: DateTime(2026, 4, 20),
          householdId: 'hh_1',
          clientRecordId: 'optimistic_income_1',
          clientMutationId: 'mobile:optimistic_income_1',
          idempotencyKey: 'mobile:optimistic_income_1',
          customSplitType: SplitType.amount,
          customSplits: [
            MemberSplit(member: members[0], amount: 80),
            MemberSplit(member: members[1], amount: 40),
          ],
          payerUserId: 'user_2',
        );

    expect(saved?.id, 'income_1');
    expect(capturedSaveBody, isNotNull);
    expect(capturedSaveBody!['householdId'], 'hh_1');
    expect(capturedSaveBody!['clientRecordId'], 'optimistic_income_1');
    expect(capturedSaveBody!['clientMutationId'], 'mobile:optimistic_income_1');
    expect(capturedSaveBody!['idempotencyKey'], 'mobile:optimistic_income_1');
    expect(capturedSaveBody!['payerUserId'], 'user_2');
    expect(capturedSaveBody!['customSplits'], {
      'splitType': 'amount',
      'memberSplits': [
        {'userId': 'user_1', 'amount': 80.0},
        {'userId': 'user_2', 'amount': 40.0},
      ],
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
}
