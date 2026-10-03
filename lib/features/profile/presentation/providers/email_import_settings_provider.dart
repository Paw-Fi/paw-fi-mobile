import 'dart:async';
import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/profile/data/email_import_settings_service.dart';
import 'package:moneko/features/profile/domain/email_import_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final emailImportSettingsServiceProvider = Provider<EmailImportSettingsService>(
  (ref) => EmailImportSettingsService(),
);

final emailImportSettingsProvider = AsyncNotifierProvider.autoDispose
    .family<EmailImportSettingsController, EmailImportSettings, String>(
  EmailImportSettingsController.new,
);

class EmailImportSettingsController
    extends AutoDisposeFamilyAsyncNotifier<EmailImportSettings, String> {
  late String _userId;
  late EmailImportSettingsService _service;
  bool _disposed = false;
  int _revision = 0;
  int _readGeneration = 0;
  final Map<String, EmailImportWhitelistEntry> _pending = {};

  @override
  Future<EmailImportSettings> build(String userId) async {
    _disposed = false;
    ++_revision;
    _userId = userId;
    if (ref.read(authProvider).uid != userId) {
      throw StateError('Email settings belong to another account');
    }
    _service = ref.watch(emailImportSettingsServiceProvider);
    ref.onDispose(() => _disposed = true);
    final subscription = _service.watchSenders(userId).skip(1).listen(
          (_) => unawaited(refresh().catchError((Object _) {})),
          onError: (Object _) {},
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    final prefs = ref.read(sharedPreferencesProvider);
    final cached = prefs.getString('email-import-settings:$userId');
    if (cached != null) {
      try {
        final settings = EmailImportSettings.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        if (settings.ownerUserId != null && settings.ownerUserId != userId) {
          throw const FormatException('Invalid email settings cache owner');
        }
        for (final entry in settings.whitelistEmails) {
          if (entry.id.startsWith('local:')) {
            _pending[entry.normalizedEmail] = entry;
          }
        }
        Future<void>.delayed(Duration.zero, () async {
          if (!_disposed) await refresh().catchError((Object _) {});
        });
        return settings;
      } catch (_) {
        /* An invalid cache cannot establish sender authorization. */
      }
    }
    final settings = await _service.getSettings();
    if (!_ownsUser ||
        (settings.ownerUserId != null && settings.ownerUserId != _userId)) {
      throw StateError('Email settings account changed while loading');
    }
    if (!_disposed) await _persist(settings);
    return settings;
  }

  bool get _ownsUser => !_disposed && ref.read(authProvider).uid == _userId;

  Future<void> _persist(EmailImportSettings settings) async {
    if (_disposed) return;
    await ref.read(sharedPreferencesProvider).setString(
          'email-import-settings:$_userId',
          jsonEncode({...settings.toJson(), 'userId': _userId}),
        );
  }

  EmailImportSettings _overlay(EmailImportSettings settings) {
    final entries = {
      for (final row in settings.whitelistEmails) row.normalizedEmail: row
    };
    for (final entry in _pending.entries) {
      entries.putIfAbsent(entry.key, () => entry.value);
    }
    return settings.copyWith(
        whitelistEmails: entries.values.toList(growable: false));
  }

  Future<void> refresh() async {
    final revision = _revision;
    final generation = ++_readGeneration;
    final settings = await _service.getSettings();
    if (settings.ownerUserId != null && settings.ownerUserId != _userId) {
      throw StateError('Email settings belong to another account');
    }
    if (!_ownsUser || revision != _revision || generation != _readGeneration) {
      return;
    }
    for (final entry in settings.whitelistEmails) {
      _pending.remove(entry.normalizedEmail);
    }
    final projected = _overlay(settings);
    state = AsyncData(projected);
    await _persist(projected);
  }

  Future<bool> requestVerification(String email) async {
    final normalized = normalizeWhitelistEmail(email);
    if (normalized == null) throw const FormatException('Invalid sender email');
    final previous = state.valueOrNull ?? await future;
    if (!_ownsUser) return false;
    final revision = ++_revision;
    _pending[normalized] = EmailImportWhitelistEntry(
        id: 'local:$normalized',
        email: normalized,
        normalizedEmail: normalized,
        isVerified: false);
    final projected = _overlay(previous);
    state = AsyncData(projected);
    await _persist(projected);
    try {
      final saved = await _service.addWhitelistEmail(normalized);
      if (!_ownsUser || revision != _revision) return false;
      if (saved.ownerUserId != null && saved.ownerUserId != _userId) {
        throw const FormatException('Invalid email settings response owner');
      }
      if (saved.whitelistEmails
          .any((entry) => entry.normalizedEmail == normalized)) {
        _pending.remove(normalized);
      }
      final reconciled = _overlay(saved);
      state = AsyncData(reconciled);
      await _persist(reconciled);
      return !saved.whitelistEmails.any(
          (entry) => entry.normalizedEmail == normalized && entry.isVerified);
    } catch (error) {
      if (_ownsUser &&
          revision == _revision &&
          error is FunctionException &&
          error.status >= 400 &&
          error.status < 500 &&
          error.status != 408 &&
          error.status != 429) {
        _pending.remove(normalized);
        state = AsyncData(previous);
        await _persist(previous);
      }
      rethrow;
    }
  }

  Future<void> updateSettings(
      {required bool enabled,
      required String scopeId,
      required bool isPortfolio,
      String? accountId}) async {
    final revision = ++_revision;
    final saved = await _service.updateSettings(
        enabled: enabled,
        scopeId: scopeId,
        isPortfolio: isPortfolio,
        accountId: accountId);
    if (!_ownsUser || revision != _revision) return;
    if (saved.ownerUserId != null && saved.ownerUserId != _userId) {
      throw const FormatException('Invalid email settings response owner');
    }
    final projected = _overlay(saved);
    state = AsyncData(projected);
    await _persist(projected);
  }

  Future<void> removeSender(String email) async {
    final revision = ++_revision;
    final saved = await _service.removeWhitelistEmail(email);
    if (!_ownsUser || revision != _revision) return;
    if (saved.ownerUserId != null && saved.ownerUserId != _userId) {
      throw const FormatException('Invalid email settings response owner');
    }
    _pending.remove(normalizeWhitelistEmail(email));
    final projected = _overlay(saved);
    state = AsyncData(projected);
    await _persist(projected);
  }

  void acceptVerifiedSender(EmailImportWhitelistEntry entry) {
    if (!_ownsUser || !entry.isVerified) return;
    ++_revision;
    _pending.remove(entry.normalizedEmail);
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final entries = {
      for (final row in current.whitelistEmails) row.normalizedEmail: row,
      entry.normalizedEmail: entry
    };
    final updated = current.copyWith(
        whitelistEmails: entries.values.toList(growable: false));
    state = AsyncData(updated);
    unawaited(_persist(updated));
  }
}
