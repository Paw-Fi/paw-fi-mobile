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
