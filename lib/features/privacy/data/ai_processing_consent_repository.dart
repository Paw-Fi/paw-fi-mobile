import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const aiProcessingDisclosureVersion = '2026-10-10.v1';

final aiProcessingConsentRepositoryProvider =
    Provider<AiProcessingConsentRepository>(
        (ref) => SharedPreferencesAiProcessingConsentRepository(
              () => ref.read(sharedPreferencesProvider),
            ));

abstract interface class AiProcessingConsentRepository {
  Future<Object?> getConsent(String userId);
  Future<Object?> setConsent(String userId, bool granted);
}

class SharedPreferencesAiProcessingConsentRepository
    implements AiProcessingConsentRepository {
  SharedPreferencesAiProcessingConsentRepository(this._preferences);

  final SharedPreferences Function() _preferences;

  static String storageKey(String userId) => 'ai_processing_consent_v1_$userId';

  void _requireUser(String userId) {
    if (userId.isEmpty) {
      throw StateError('Consent requires an account');
    }
  }

  @override
  Future<Object?> getConsent(String userId) async {
    _requireUser(userId);
    final stored = _preferences().getString(storageKey(userId));
    return stored == null
        ? {
            'user_id': userId,
            'granted': false,
            'disclosure_version': null,
            'granted_at': null,
            'revoked_at': null,
          }
        : jsonDecode(stored);
  }

  @override
  Future<Object?> setConsent(String userId, bool granted) async {
    _requireUser(userId);
    final preferences = _preferences();
    final key = storageKey(userId);
    final previous = preferences.getString(key);
    final previousConsent = previous == null
        ? null
        : AiProcessingConsent.fromResponse(jsonDecode(previous), userId);
    final now = DateTime.now().toUtc().toIso8601String();
    final response = {
      'user_id': userId,
      'granted': granted,
      'disclosure_version': aiProcessingDisclosureVersion,
      'granted_at':
          granted ? now : previousConsent?.grantedAt?.toIso8601String(),
      'revoked_at': granted ? null : now,
    };
    try {
      if (!await preferences.setString(key, jsonEncode(response))) {
        throw StateError('Consent preference could not be saved');
      }
    } catch (_) {
      // SharedPreferences updates its memory cache before reporting failure.
      if (previous == null) {
        await preferences.remove(key);
      } else {
        await preferences.setString(key, previous);
      }
      rethrow;
    }
    return response;
  }
}

class AiProcessingConsent {
  const AiProcessingConsent({
    required this.userId,
    required this.granted,
    required this.disclosureVersion,
    required this.grantedAt,
    required this.revokedAt,
  });

  final String userId;
  final bool granted;
  final String? disclosureVersion;
  final DateTime? grantedAt;
  final DateTime? revokedAt;

  bool get isCurrent =>
      granted &&
      disclosureVersion == aiProcessingDisclosureVersion &&
      grantedAt != null &&
      revokedAt == null;

  factory AiProcessingConsent.fromResponse(Object? response, String userId) {
    if (response is! Map ||
        response['user_id'] != userId ||
        response['granted'] is! bool ||
        (response['disclosure_version'] != null &&
            response['disclosure_version'] is! String)) {
      throw const FormatException('Invalid consent response');
    }
    DateTime? timestamp(String key) {
      final value = response[key];
      if (value == null) return null;
      if (value is! String || DateTime.tryParse(value) == null) {
        throw const FormatException('Invalid consent timestamp');
      }
      return DateTime.parse(value);
    }

    final consent = AiProcessingConsent(
      userId: userId,
      granted: response['granted'] as bool,
      disclosureVersion: response['disclosure_version'] as String?,
      grantedAt: timestamp('granted_at'),
      revokedAt: timestamp('revoked_at'),
    );
    if (consent.granted &&
        (consent.grantedAt == null || consent.revokedAt != null)) {
      throw const FormatException('Unconfirmed consent');
    }
    return consent;
  }
}
