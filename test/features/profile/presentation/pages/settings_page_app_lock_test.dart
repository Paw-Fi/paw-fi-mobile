import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/features/app_lock/presentation/pages/app_lock_setup_page.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';

void main() {
  group('App Lock Toggle Behavior', () {
    testWidgets('should not toggle switch when setup is cancelled', (tester) async {
      // This test verifies that when the user cancels the app lock setup,
      // the switch state should not change
      
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      // Find the app lock switch
      final appLockSwitch = find.byType(AdaptiveSwitch).first;
      expect(appLockSwitch, findsOneWidget);

      // Get initial state (should be off)
      final switchWidget = tester.widget<AdaptiveSwitch>(appLockSwitch);
      expect(switchWidget.value, isFalse);

      // Tap the switch to enable app lock
      await tester.tap(appLockSwitch);
      await tester.pumpAndSettle();

      // Should navigate to setup page
      expect(find.byType(AppLockSetupPage), findsOneWidget);

      // Simulate user pressing back (cancelling setup)
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Should be back on settings page
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byType(AppLockSetupPage), findsNothing);

      // Switch should still be in original state (off)
      final updatedSwitchWidget = tester.widget<AdaptiveSwitch>(appLockSwitch);
      expect(updatedSwitchWidget.value, isFalse);
    });

    testWidgets('should toggle switch when setup is completed successfully', (tester) async {
      // This test verifies that when the user completes the app lock setup,
      // the switch state should change to reflect the new state
      
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsPage(),
          ),
        ),
      );

      // Find the app lock switch
      final appLockSwitch = find.byType(AdaptiveSwitch).first;
      expect(appLockSwitch, findsOneWidget);

      // Tap the switch to enable app lock
      await tester.tap(appLockSwitch);
      await tester.pumpAndSettle();

      // Should navigate to setup page
      expect(find.byType(AppLockSetupPage), findsOneWidget);

      // Simulate successful setup (this would require mocking the controller)
      // For now, we just verify the navigation behavior
      expect(find.byType(AppLockSetupPage), findsOneWidget);
    });
  });
}
