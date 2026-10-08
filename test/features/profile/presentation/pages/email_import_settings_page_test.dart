import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/repositories/household_repository.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/profile/domain/email_import_settings.dart';
import 'package:moneko/features/profile/presentation/pages/email_import_settings_page.dart';
import 'package:moneko/features/profile/presentation/providers/email_import_settings_provider.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/email_import_settings_provider_test.dart'
    show FakeService, TestAuth, userId, email, pendingRow, verifiedRow;

class TestHouseholdRepository extends Mock implements HouseholdRepository {}

class TestSubscription extends SubscriptionNotifier {
  @override
  Future<Subscription?> build() async => Subscription(
      id: 'lifetime',
      userId: userId,
      plan: 'lifetime',
      status: 'active',
      createdAt: DateTime(2026));
}

void main() {
  for (final action in [
    'Confirm',
    'Cancel',
    'Switch account',
    'Loading then confirm'
  ]) {
    testWidgets('prefilled sender requires confirmation: $action',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = FakeService();
      final initialRead = Completer<EmailImportSettings>();
      if (action == 'Loading then confirm') {
        service.get = () => initialRead.future;
      }
      var requests = 0;
      service.add = () async {
        requests++;
        return service.settings.copyWith(whitelistEmails: const [pendingRow]);
      };
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(TestAuth.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
          emailImportSettingsServiceProvider.overrideWithValue(service),
          subscriptionNotifierProvider.overrideWith(TestSubscription.new),
          walletsByHouseholdIdProvider(null).overrideWith((ref) async => []),
          userHouseholdsProvider(userId).overrideWith((ref) =>
              UserHouseholdsNotifier(TestHouseholdRepository(), userId, ref,
                  initialHouseholds: [])),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmailImportSettingsPage(initialSenderEmail: email),
        ),
      ));
      if (action == 'Loading then confirm') {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(EditableText), findsNothing);
        expect(requests, 0);
        initialRead.complete(service.settings);
      }
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsOneWidget);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          email);
      expect(find.textContaining('relay@example.com'), findsWidgets);
      expect(
          find.textContaining('forward your attachment again'), findsOneWidget);
      expect(requests, 0);
      if (action == 'Switch account') {
        final container = ProviderScope.containerOf(
            tester.element(find.byType(EmailImportSettingsPage)));
        container.read(authProvider.notifier).state =
            const AppUser(uid: '', email: '');
        // Confirm before the old dialog can be removed by the next build.
        await tester.tap(find.text('Confirm'));
      } else {
        await tester.tap(
            find.text(action == 'Loading then confirm' ? 'Confirm' : action));
      }
      await tester.pumpAndSettle();
      expect(requests,
          action == 'Confirm' || action == 'Loading then confirm' ? 1 : 0);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpWidget(const SizedBox.shrink());
      await service.changes.close();
    });
  }

  testWidgets(
      'adding shows pending immediately and confirmation replaces it without a reload',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = FakeService();
    service.settings = service.settings.copyWith(enabled: true);
    final send = Completer<EmailImportSettings>();
    service.add = () => send.future;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(TestAuth.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
          emailImportSettingsServiceProvider.overrideWithValue(service),
          subscriptionNotifierProvider.overrideWith(TestSubscription.new),
          walletsByHouseholdIdProvider(null).overrideWith((ref) async => []),
          userHouseholdsProvider(userId).overrideWith((ref) =>
              UserHouseholdsNotifier(TestHouseholdRepository(), userId, ref,
                  initialHouseholds: [])),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmailImportSettingsPage(),
        )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), email);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text(email), findsOneWidget);
    expect(find.text('Pending verification'), findsOneWidget);
    send.complete(
        service.settings.copyWith(whitelistEmails: const [pendingRow]));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(EmailImportSettingsPage)));
    container
        .read(emailImportSettingsProvider(userId).notifier)
        .acceptVerifiedSender(verifiedRow);
    await tester.pumpAndSettle();
    expect(find.text('Pending verification'), findsNothing);
    expect(find.text(email), findsOneWidget);
    expect(find.text('Allowed sender'), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await service.changes.close();
  });
}
