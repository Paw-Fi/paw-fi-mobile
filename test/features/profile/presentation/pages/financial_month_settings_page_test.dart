import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/financial_month_start_provider.dart';
import 'package:moneko/features/profile/presentation/pages/financial_month_settings_page.dart';

class _TestAuth extends Auth {
  @override
  AppUser build() => const AppUser(uid: 'user_1', email: 'user@example.com');
}

void main() {
  testWidgets('explains the feature and short-month behavior', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuth.new),
          financialMonthStartDayProvider.overrideWithValue(31),
        ],
        child: const MaterialApp(home: FinancialMonthSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make your month match your money'), findsOneWidget);
    expect(find.text('Your current financial month'), findsOneWidget);
    expect(find.text('What this changes'), findsOneWidget);
    expect(
      find.textContaining('only changes how activity is grouped'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Some months do not have a day 31'),
      findsOneWidget,
    );
    expect(find.text('Save start day'), findsNothing);
    expect(find.text('Day 31'), findsNothing);

    await tester.tap(find.byTooltip('Edit financial month start day'));
    await tester.pumpAndSettle();

    expect(find.text('Start financial month on'), findsOneWidget);
    expect(
      find.text('Your choice saves as soon as you select a day.'),
      findsOneWidget,
    );
    expect(find.text('Day 31'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
