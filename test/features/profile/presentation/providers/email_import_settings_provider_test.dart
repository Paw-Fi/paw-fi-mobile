import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/profile/data/email_import_settings_service.dart';
import 'package:moneko/features/profile/domain/email_import_settings.dart';
import 'package:moneko/features/profile/presentation/providers/email_import_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const userId = '11111111-1111-4111-8111-111111111111';
const email = 'sender@example.com';
const pendingRow = EmailImportWhitelistEntry(
    id: 'sender-1', email: email, normalizedEmail: email, isVerified: false);
const verifiedRow = EmailImportWhitelistEntry(
    id: 'sender-1', email: email, normalizedEmail: email);

class TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: userId, email: 'relay@example.com');
}

class FakeService extends EmailImportSettingsService {
  FakeService()
      : super(
            client: SupabaseClient('https://example.test', 'test-key',
                authOptions: const AuthClientOptions(autoRefreshToken: false)));
  EmailImportSettings settings =
      EmailImportSettings.disabled(defaultEmail: 'relay@example.com');
  final changes = StreamController<void>.broadcast();
  Future<EmailImportSettings> Function()? get;
  Future<EmailImportSettings> Function()? add;
  @override
  Future<EmailImportSettings> getSettings() =>
      get?.call() ?? Future.value(settings);
  @override
  Future<EmailImportSettings> addWhitelistEmail(String value) {
    expect(value, email);
    return add?.call() ??
        Future.value(settings.copyWith(whitelistEmails: const [pendingRow]));
  }

  @override
  Stream<void> watchSenders(String id) async* {
    expect(id, userId);
    yield null;
    yield* changes.stream;
  }
}

void main() {
  late SharedPreferences prefs;
  late FakeService service;
  late ProviderContainer container;
  final provider = emailImportSettingsProvider(userId);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = FakeService();
    container = ProviderContainer(overrides: [
      authProvider.overrideWith(TestAuth.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
      emailImportSettingsServiceProvider.overrideWithValue(service),
    ]);
    container.listen(provider, (_, __) {});
  });
  tearDown(() async {
    container.dispose();
    await service.changes.close();
  });

  test('uncached settings remain loading until authoritative data arrives',
      () async {
    final read = Completer<EmailImportSettings>();
    service.get = () => read.future;
    container.invalidate(provider);
    expect(container.read(provider).isLoading, isTrue);
    read.complete(service.settings);
    await container.read(provider.future);
    expect(container.read(provider).hasValue, isTrue);
  });

  test(
      'pending sender is visible and persisted before email dispatch completes',
      () async {
    await container.read(provider.future);
    final request = Completer<EmailImportSettings>();
    service.add = () => request.future;
    final saving = container.read(provider.notifier).requestVerification(email);
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(provider).requireValue.whitelistEmails.single.isVerified,
        isFalse);
    final cached = jsonDecode(prefs.getString('email-import-settings:$userId')!)
        as Map<String, dynamic>;
    expect(
        EmailImportSettings.fromJson(cached).whitelistEmails.single.isVerified,
        isFalse);
    request.complete(
        service.settings.copyWith(whitelistEmails: const [pendingRow]));
    await saving;
    expect(container.read(provider).requireValue.whitelistEmails.single.id,
        'sender-1');
  });

  test('empty success snapshot cannot erase a newly requested pending sender',
      () async {
    await container.read(provider.future);
    service.add = () async => service.settings;
    await container.read(provider.notifier).requestVerification(email);
    expect(
        container.read(provider).requireValue.whitelistEmails.single.isVerified,
        isFalse);
  });

  test('retryable email delivery failure keeps pending state', () async {
    await container.read(provider.future);
    service.add = () async => throw const FunctionException(status: 503);
    await expectLater(
        container.read(provider.notifier).requestVerification(email),
        throwsA(isA<FunctionException>()));
    expect(
        container.read(provider).requireValue.whitelistEmails.single.isVerified,
        isFalse);
  });

  test('terminal rejection restores the prior snapshot', () async {
    await container.read(provider.future);
    service.add = () async => throw const FunctionException(status: 403);
    await expectLater(
        container.read(provider.notifier).requestVerification(email),
        throwsA(isA<FunctionException>()));
    expect(container.read(provider).requireValue.whitelistEmails, isEmpty);
  });

  test('verification projects immediately and an older request cannot undo it',
      () async {
    await container.read(provider.future);
    final request = Completer<EmailImportSettings>();
    service.add = () => request.future;
    final saving = container.read(provider.notifier).requestVerification(email);
    await Future<void>.delayed(Duration.zero);
    container.read(provider.notifier).acceptVerifiedSender(verifiedRow);
    expect(
        container.read(provider).requireValue.whitelistEmails.single.isVerified,
        isTrue);
    request.complete(
        service.settings.copyWith(whitelistEmails: const [pendingRow]));
    await saving;
    expect(
        container.read(provider).requireValue.whitelistEmails.single.isVerified,
        isTrue);
  });

  test('cached content remains visible during refresh and stale responses lose',
      () async {
    await container.read(provider.future);
    final first = Completer<EmailImportSettings>();
    final second = Completer<EmailImportSettings>();
    var requests = 0;
    service.get = () => requests++ == 0 ? first.future : second.future;
    final older = container.read(provider.notifier).refresh();
    final newer = container.read(provider.notifier).refresh();
    expect(container.read(provider).hasValue, isTrue);
    second.complete(
        service.settings.copyWith(whitelistEmails: const [verifiedRow]));
    await newer;
    first.complete(service.settings);
    await older;
    expect(
        container.read(provider).requireValue.whitelistEmails.single.isVerified,
        isTrue);
  });

  test('realtime confirmation refreshes the same user-scoped settings',
      () async {
    await container.read(provider.future);
    await Future<void>.delayed(Duration.zero);
    service.settings =
        service.settings.copyWith(whitelistEmails: const [verifiedRow]);
    service.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(provider).requireValue.whitelistEmails.single.isVerified,
        isTrue);
  });
}
