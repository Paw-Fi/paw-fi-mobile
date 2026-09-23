import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:moneko/core/ui/widgets/transaction_frequency_picker.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

class _IosModalHarness extends StatelessWidget {
  const _IosModalHarness();

  @override
  Widget build(BuildContext context) {
    final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
    return Stack(
      children: [
        Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-parent'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (sheetContext) => Container(
                  width: double.infinity,
                  height: 620,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      TextButton(
                        key: const ValueKey('open-frequency'),
                        onPressed: () => showRecurrencePicker(
                          context: sheetContext,
                          currentFrequency: 'monthly',
                          currentInterval: null,
                        ),
                        child: const Text('Frequency'),
                      ),
                      TextButton(
                        key: const ValueKey('close-parent'),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Close parent'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Open parent'),
            ),
          ),
        ),
        if (PlatformInfo.isIOS26OrHigher())
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IOS26NativeTabBar(
              key: const ValueKey('ios26-native-tab-bar'),
              destinations: const [
                AdaptiveNavigationDestination(
                  icon: 'house.fill',
                  label: 'Home',
                ),
                AdaptiveNavigationDestination(
                  icon: 'repeat',
                  label: 'Recurring',
                ),
              ],
              selectedIndex: 1,
              onTap: (_) {},
              showNativeView: isTopRoute,
            ),
          ),
      ],
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom recurrence stays in one route on iOS', (tester) async {
    expect(Platform.isIOS, isTrue);
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _IosModalHarness(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-parent')));
    await tester.pumpAndSettle();
    await _capture(binding, 'recurrence_parent_before_picker');

    for (var attempt = 0; attempt < 2; attempt += 1) {
      await tester.tap(find.byKey(const ValueKey('open-frequency')));
      await tester.pumpAndSettle();
      final pushesBeforeCustom = observer.pushCount;

      tester
          .widget<CupertinoPicker>(find.byType(CupertinoPicker))
          .onSelectedItemChanged
          ?.call(7);
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(observer.pushCount, pushesBeforeCustom);
      expect(find.byType(CupertinoPicker), findsNWidgets(2));
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(PlatformViewLink), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(binding, 'recurrence_custom_picker_$attempt');
      if (attempt == 1 && const bool.fromEnvironment('MONEKO_VISUAL_PAUSE')) {
        await Future<void>.delayed(const Duration(seconds: 120));
      }

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const ValueKey('close-parent')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom recurrence remains bounded at large iOS text scale',
      (tester) async {
    expect(Platform.isIOS, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showRecurrencePicker(
                  context: context,
                  currentFrequency: 'daily',
                  currentInterval: 45,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    expect(find.text('45 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(binding, 'recurrence_custom_picker_large_text');
  });
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final file = File('${Directory.systemTemp.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
}
