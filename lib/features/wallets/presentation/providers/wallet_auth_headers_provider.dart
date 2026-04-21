import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';

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
