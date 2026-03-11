import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/home/presentation/state/analytics_data.dart';
import 'package:moneko/features/home/presentation/state/analytics_notifier.dart';
import 'package:moneko/features/home/presentation/state/analytics_provider.dart';
import 'package:moneko/features/home/presentation/state/transaction_edit_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockFunctionResponse extends Mock implements FunctionResponse {}

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

class _FakeAnalyticsNotifier extends AnalyticsNotifier {
  _FakeAnalyticsNotifier(super.ref) : super() {
    state = AnalyticsData(allExpenses: const []);
  }

  String? loadedUserId;

  @override
  Future<void> loadData(
    String userId, {
    int retryCount = 0,
  }) async {
    loadedUserId = userId;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  ProviderContainer createContainer({
    required SupabaseClient supabaseClient,
    required void Function(_FakeAnalyticsNotifier notifier)
        onAnalyticsNotifierCreated,
  }) {
    return ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'user-1', email: 'user@test.com')),
        ),
        analyticsProvider.overrideWith((ref) {
          final notifier = _FakeAnalyticsNotifier(ref);
          onAnalyticsNotifierCreated(notifier);
          return notifier;
        }),
        transactionEditSupabaseClientProvider.overrideWithValue(supabaseClient),
      ],
    );
  }

  group('TransactionEditNotifier.updateExpense', () {
    late _MockSupabaseClient supabaseClient;
    late _MockFunctionsClient functionsClient;
    _FakeAnalyticsNotifier? analyticsNotifier;

    setUp(() {
      supabaseClient = _MockSupabaseClient();
      functionsClient = _MockFunctionsClient();
      analyticsNotifier = null;
      when(() => supabaseClient.functions).thenReturn(functionsClient);
    });

    test(
      'keeps the save successful when category retry throws after primary success',
      () async {
        final primaryResponse = _MockFunctionResponse();
        when(() => primaryResponse.data).thenReturn({
          'success': true,
          'data': {'category': 'food'},
        });

        var callCount = 0;
        final requestBodies = <Map<String, dynamic>>[];
        when(
          () => functionsClient.invoke(
            'update-expense',
            body: any(named: 'body'),
          ),
        ).thenAnswer((invocation) async {
          callCount += 1;
          requestBodies.add(
            Map<String, dynamic>.from(
              invocation.namedArguments[#body] as Map<String, dynamic>,
            ),
          );
          if (callCount == 1) {
            return primaryResponse;
          }
          throw Exception('retry failed');
        });

        final container = createContainer(
          supabaseClient: supabaseClient,
          onAnalyticsNotifierCreated: (notifier) =>
              analyticsNotifier = notifier,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(transactionEditProvider.notifier)
            .updateExpense('expense-1', {
          'category': 'comida y bebidas',
          'raw_text': 'Transferencia a Alcides Ruiz por Asaditos',
        });

        final state = container.read(transactionEditProvider);
        expect(result, isTrue);
        expect(state.error, isNull);
        expect(state.isLoading, isFalse);
        expect(analyticsNotifier?.loadedUserId, 'user-1');
        expect(callCount, 2);
        expect(
          (requestBodies.first['updates'] as Map<String, dynamic>).keys,
          containsAll(<String>['category', 'raw_text']),
        );
        expect(
          (requestBodies.last['updates'] as Map<String, dynamic>).keys,
          <String>['category'],
        );
      },
    );

    test(
      'keeps the save successful when category retry returns an error payload',
      () async {
        final primaryResponse = _MockFunctionResponse();
        when(() => primaryResponse.data).thenReturn({
          'success': true,
          'data': {'category': 'food'},
        });

        final retryResponse = _MockFunctionResponse();
        when(() => retryResponse.data).thenReturn({
          'success': false,
          'error': 'retry failed',
          'code': 'SERVER_ERROR',
          'data': {'category': 'food'},
        });

        var callCount = 0;
        final requestBodies = <Map<String, dynamic>>[];
        when(
          () => functionsClient.invoke(
            'update-expense',
            body: any(named: 'body'),
          ),
        ).thenAnswer((invocation) async {
          callCount += 1;
          requestBodies.add(
            Map<String, dynamic>.from(
              invocation.namedArguments[#body] as Map<String, dynamic>,
            ),
          );
          return callCount == 1 ? primaryResponse : retryResponse;
        });

        final container = createContainer(
          supabaseClient: supabaseClient,
          onAnalyticsNotifierCreated: (notifier) =>
              analyticsNotifier = notifier,
        );
        addTearDown(container.dispose);

        final result = await container
            .read(transactionEditProvider.notifier)
            .updateExpense('expense-1', {
          'category': 'comida y bebidas',
          'raw_text': 'Transferencia a Alcides Ruiz por Asaditos',
        });

        final state = container.read(transactionEditProvider);
        expect(result, isTrue);
        expect(state.error, isNull);
        expect(state.isLoading, isFalse);
        expect(analyticsNotifier?.loadedUserId, 'user-1');
        expect(callCount, 2);
        expect(
          (requestBodies.first['updates'] as Map<String, dynamic>).keys,
          containsAll(<String>['category', 'raw_text']),
        );
        expect(
          (requestBodies.last['updates'] as Map<String, dynamic>).keys,
          <String>['category'],
        );
      },
    );

    test('returns failure when the primary update response is unsuccessful',
        () async {
      final failedResponse = _MockFunctionResponse();
      when(() => failedResponse.data).thenReturn({
        'success': false,
        'error': 'Failed to update expense',
        'code': 'SERVER_ERROR',
      });

      when(
        () => functionsClient.invoke(
          'update-expense',
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => failedResponse);

      final container = createContainer(
        supabaseClient: supabaseClient,
        onAnalyticsNotifierCreated: (notifier) => analyticsNotifier = notifier,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(transactionEditProvider.notifier)
          .updateExpense('expense-1', {
        'category': 'comida y bebidas',
        'raw_text': 'Transferencia a Alcides Ruiz por Asaditos',
      });

      final state = container.read(transactionEditProvider);
      expect(result, isFalse);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
      expect(analyticsNotifier?.loadedUserId, isNull);
      verify(
        () => functionsClient.invoke(
          'update-expense',
          body: any(named: 'body'),
        ),
      ).called(1);
    });
  });
}
