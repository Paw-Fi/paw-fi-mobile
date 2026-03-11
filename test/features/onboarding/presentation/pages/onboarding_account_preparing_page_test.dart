import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:moneko/features/auth/domain/app_user.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/onboarding/presentation/pages/onboarding_account_preparing_page.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class _TestAuth extends Auth {
  _TestAuth(this._user);

  final AppUser _user;

  @override
  AppUser build() => _user;
}

Future<void> pumpPage(
  WidgetTester tester, {
  required SharedPreferences prefs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(
          () => _TestAuth(const AppUser(uid: 'u1', email: 'u1@example.com')),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const OnboardingAccountPreparingPage(autoStart: false),
      ),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('Continue stays disabled while setup is still in progress',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await pumpPage(tester, prefs: prefs);

    final continueText = find.text('Continue');
    expect(continueText, findsOneWidget);

    final ignorePointer = tester.widget<IgnorePointer>(find
        .ancestor(
          of: find.byType(PrimaryAdaptiveButton),
          matching: find.byType(IgnorePointer),
        )
        .first);
    expect(ignorePointer.ignoring, isTrue);

    final cupertinoButton = tester.widget<CupertinoButton>(
      find.descendant(
        of: find.byType(PrimaryAdaptiveButton),
        matching: find.byType(CupertinoButton),
      ),
    );
    expect(cupertinoButton.onPressed, isNull);
  });
}
