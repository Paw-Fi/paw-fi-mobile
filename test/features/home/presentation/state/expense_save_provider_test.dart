import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user_1', email: 'user@example.com');
}

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

  test('saveExpense sends client mutation metadata for idempotent retries',
      () async {
    Map<String, dynamic>? capturedSaveBody;
    requestHandler = (request) async {
      if (request.url.path.endsWith('/functions/v1/save-expense')) {
        capturedSaveBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'expense_1',
              'user_id': 'user_1',
              'date': '2026-04-20',
              'category': 'food',
              'amount_cents': 1250,
              'currency': 'EUR',
              'type': 'expense',
              'created_at': '2026-04-20T10:00:00.000Z',
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

    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_TestAuth.new),
      householdScopeProvider.overrideWithValue(
        const HouseholdScope(
          viewMode: ViewMode.personal,
          selected: SelectedHouseholdState(),
          portfolioHouseholdIds: {},
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final saved =
        await container.read(expenseSaveNotifierProvider.notifier).saveExpense(
              expense: ParsedExpense(
                amount: 12.50,
                category: 'food',
                currency: 'EUR',
                currencySymbol: 'EUR',
                date: DateTime(2026, 4, 20),
                description: 'Lunch',
              ),
              clientRecordId: 'optimistic_abc',
              clientMutationId: 'mobile:optimistic_abc',
              idempotencyKey: 'mobile:optimistic_abc',
              invalidateProviders: false,
            );

    expect(saved?.id, 'expense_1');
    expect(capturedSaveBody, isNotNull);
    expect(capturedSaveBody!['clientRecordId'], 'optimistic_abc');
    expect(capturedSaveBody!['clientMutationId'], 'mobile:optimistic_abc');
    expect(capturedSaveBody!['idempotencyKey'], 'mobile:optimistic_abc');
  });
}
