import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Refreshes only through GoTrue and never replays a read for another account.
Future<T> runAuthenticatedWalletRead<T>({
  required GoTrueClient auth,
  required String userId,
  required Future<T> Function(Map<String, String> headers) invoke,
}) async {
  Session sessionForOwner() {
    final session = auth.currentSession;
    if (session == null ||
        session.user.id != userId ||
        session.accessToken.trim().isEmpty) {
      throw const AuthException('Wallet session is unavailable');
    }
    return session;
  }

  var session = sessionForOwner();
  if (session.isExpired) {
    await auth.refreshSession();
    session = sessionForOwner();
  }
  final token = session.accessToken;
  try {
    final result = await invoke(buildWalletAuthHeaders(token)!);
    sessionForOwner();
    return result;
  } on FunctionException catch (error) {
    if (error.status != 401) rethrow;
    // A refresh may have completed while the first request was in flight.
    if (sessionForOwner().accessToken == token) {
      await auth.refreshSession();
    }
    final result = await invoke(
      buildWalletAuthHeaders(sessionForOwner().accessToken)!,
    );
    sessionForOwner();
    return result;
  }
}

@visibleForTesting
Map<String, String>? buildWalletAuthHeaders(String? accessToken) {
  final normalizedToken = accessToken?.trim();
  if (normalizedToken == null || normalizedToken.isEmpty) {
    return null;
  }

  return <String, String>{
    'Authorization': 'Bearer $normalizedToken',
  };
}

final walletAuthHeadersProvider = Provider<Map<String, String>?>((ref) {
  final user = ref.watch(authProvider);
  if (user.uid.trim().isEmpty) {
    return null;
  }

  final accessToken = ref.watch(authAccessTokenProvider);
  return buildWalletAuthHeaders(accessToken);
});
