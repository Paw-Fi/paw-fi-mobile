import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_auth_headers_provider.dart';

class _MockAuth extends Mock implements GoTrueClient {}

Session _session(String token,
        {String userId = 'user', bool expired = false}) =>
    Session(
      accessToken: token,
      tokenType: 'bearer',
      user: User(
          id: userId,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-10-05T00:00:00Z'),
    )..expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        (expired ? -3600 : 3600);

void main() {
  group('authenticated wallet reads', () {
    late _MockAuth auth;
    late Session? current;
    setUp(() {
      auth = _MockAuth();
      current = _session('old');
      when(() => auth.currentSession).thenAnswer((_) => current);
      when(() => auth.refreshSession()).thenAnswer((_) async {
        current = _session('new');
        return AuthResponse(session: current);
      });
    });

    test('expired startup session refreshes before dispatch', () async {
      current = _session('old', expired: true);
      final result = await runAuthenticatedWalletRead(
        auth: auth,
        userId: 'user',
        invoke: (headers) async => headers['Authorization'],
      );
      expect(result, 'Bearer new');
      verify(() => auth.refreshSession()).called(1);
    });

    test('an account switch during startup refresh prevents dispatch',
        () async {
      current = _session('old', expired: true);
      when(() => auth.refreshSession()).thenAnswer((_) async {
        current = _session('other', userId: 'other');
        return AuthResponse(session: current);
      });
      var invoked = false;
      await expectLater(
          runAuthenticatedWalletRead(
              auth: auth,
              userId: 'user',
              invoke: (_) async {
                invoked = true;
                return 'wallets';
              }),
          throwsA(isA<AuthException>()));
      expect(invoked, isFalse);
    });

    test('a refresh failure prevents replay', () async {
      when(() => auth.refreshSession())
          .thenThrow(const AuthException('refresh failed'));
      var calls = 0;
      await expectLater(
          runAuthenticatedWalletRead(
              auth: auth,
              userId: 'user',
              invoke: (_) async {
                calls++;
                throw const FunctionException(status: 401);
              }),
          throwsA(isA<AuthException>()));
      expect(calls, 1);
    });

    test('an account switch during the retry blocks its successful response',
        () async {
      var calls = 0;
      await expectLater(
          runAuthenticatedWalletRead(
              auth: auth,
              userId: 'user',
              invoke: (_) async {
                if (++calls == 1) throw const FunctionException(status: 401);
                current = null;
                return 'old wallets';
              }),
          throwsA(isA<AuthException>()));
      expect(calls, 2);
    });

    test('401 refreshes and replays a read once', () async {
      final tokens = <String?>[];
      await runAuthenticatedWalletRead(
          auth: auth,
          userId: 'user',
          invoke: (headers) async {
            tokens.add(headers['Authorization']);
            if (tokens.length == 1) throw const FunctionException(status: 401);
            return 'wallets';
          });
      expect(tokens, ['Bearer old', 'Bearer new']);
      verify(() => auth.refreshSession()).called(1);
    });

    test('an already rotated token is reused without another refresh',
        () async {
      var calls = 0;
      await runAuthenticatedWalletRead(
          auth: auth,
          userId: 'user',
          invoke: (headers) async {
            calls++;
            if (calls == 1) {
              current = _session('rotated');
              throw const FunctionException(status: 401);
            }
            expect(headers['Authorization'], 'Bearer rotated');
            return 'wallets';
          });
      verifyNever(() => auth.refreshSession());
    });

    for (final status in [403, 503]) {
      test('$status propagates without retry or refresh', () async {
        var calls = 0;
        await expectLater(
            runAuthenticatedWalletRead(
                auth: auth,
                userId: 'user',
                invoke: (_) async {
                  calls++;
                  throw FunctionException(status: status);
                }),
            throwsA(isA<FunctionException>()));
        expect(calls, 1);
        verifyNever(() => auth.refreshSession());
      });
    }

    test('a rejected retry propagates after two requests', () async {
      var calls = 0;
      await expectLater(
          runAuthenticatedWalletRead(
              auth: auth,
              userId: 'user',
              invoke: (_) async {
                calls++;
                throw const FunctionException(status: 401);
              }),
          throwsA(isA<FunctionException>()));
      expect(calls, 2);
    });

    test('an account change blocks replay', () async {
      var calls = 0;
      await expectLater(
          runAuthenticatedWalletRead(
              auth: auth,
              userId: 'user',
              invoke: (_) async {
                calls++;
                current = _session('other', userId: 'another-user');
                throw const FunctionException(status: 401);
              }),
          throwsA(isA<AuthException>()));
      expect(calls, 1);
      verifyNever(() => auth.refreshSession());
    });

    for (final nextUser in ['another-user', 'signed-out']) {
      test('$nextUser blocks a successful in-flight wallet response', () async {
        final pending = Completer<String>();
        final request = runAuthenticatedWalletRead(
          auth: auth,
          userId: 'user',
          invoke: (_) => pending.future,
        );
        final assertion = expectLater(request, throwsA(isA<AuthException>()));
        current = nextUser == 'signed-out'
            ? null
            : _session('other', userId: nextUser);
        pending.complete('prior user wallets');
        await assertion;
      });
    }
  });
  test('buildWalletAuthHeaders returns null when token is missing', () {
    expect(buildWalletAuthHeaders(null), isNull);
    expect(buildWalletAuthHeaders('   '), isNull);
  });

  test('buildWalletAuthHeaders returns bearer auth header', () {
    expect(
      buildWalletAuthHeaders('token-123'),
      {'Authorization': 'Bearer token-123'},
    );
  });
}
