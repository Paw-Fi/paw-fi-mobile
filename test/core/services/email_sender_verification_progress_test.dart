import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/app/router.dart';
import 'package:moneko/core/services/deep_link_service.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/profile/presentation/providers/email_import_settings_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/presentation/providers/email_import_settings_provider_test.dart'
    show FakeService, TestAuth, userId;

class VerificationProgressService extends FakeService {
  final verification = Completer<Map<String, dynamic>>();
  int verificationCalls = 0;

  @override
  Future<Map<String, dynamic>> verifySender(String token) {
    verificationCalls++;
    return verification.future;
  }
}

void main() {
  for (final outcome in [
    'success',
    'expired',
    'invalid',
    'failed',
    'other account'
  ]) {
    testWidgets('sender verification displays pending then $outcome',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final remote = VerificationProgressService();
      final service = DeepLinkService();
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/dashboard',
        routes: [
          for (final path in ['/dashboard', '/email-import-settings'])
            GoRoute(path: path, builder: (_, __) => Scaffold(body: Text(path))),
        ],
      );
      late WidgetRef widgetRef;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(TestAuth.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
          emailImportSettingsServiceProvider.overrideWithValue(remote),
          routerProvider.overrideWithValue(router),
        ],
        child: Consumer(builder: (_, ref, __) {
          widgetRef = ref;
          return MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        }),
      ));
      await tester.pumpAndSettle();
      final link = Uri.parse('moneko://verify-email-sender#${'A' * 43}');
      service.handleDeepLinkUri(link, widgetRef);
      service.handleDeepLinkUri(link, widgetRef);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(l10n.verifyingSender), findsOneWidget);
      expect(find.byType(BlockingProcessingDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(BlockingProcessingDialog), findsOneWidget);
      expect(remote.verificationCalls, 1);

      if (outcome == 'expired' || outcome == 'invalid' || outcome == 'failed') {
        remote.verification.completeError(FunctionException(
          status: outcome == 'expired'
              ? 410
              : outcome == 'invalid'
                  ? 400
                  : 503,
          details: {
            'code': switch (outcome) {
              'expired' => 'VERIFICATION_LINK_EXPIRED',
              'invalid' => 'INVALID_VERIFICATION_LINK',
              _ => 'SERVER_ERROR',
            }
          },
        ));
      } else {
        remote.verification.complete({
          'userId': outcome == 'success' ? userId : 'other-user',
          'sender': {
            'id': 'sender-1',
            'email': 'sender@example.com',
            'normalizedEmail': 'sender@example.com',
            'verified': true
          },
        });
      }
      await tester.pumpAndSettle();
      final expectedMessage = switch (outcome) {
        'success' => l10n.emailSenderVerificationComplete,
        'expired' => l10n.senderVerificationLinkExpired,
        'invalid' => l10n.invalidSenderVerificationLink,
        'other account' => l10n.emailSenderVerifiedOtherAccount,
        _ => l10n.senderVerificationFailed,
      };
      expect(find.text(expectedMessage), findsOneWidget);
      expect(find.byType(BlockingProcessingDialog), findsNothing);
      expect(find.text('/email-import-settings'),
          outcome == 'success' ? findsOneWidget : findsNothing);
      await tester.pump(const Duration(seconds: 8));
      service.dispose();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      await remote.changes.close();
    });
  }
}
