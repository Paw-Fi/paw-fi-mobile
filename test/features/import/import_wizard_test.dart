import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/import/presentation/pages/import_wizard_page.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_notifier.dart';
import 'package:moneko/features/import/presentation/state/import_wizard_state.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockImportWizardNotifier extends StateNotifier<ImportWizardState>
    with Mock
    implements ImportWizardNotifier {
  MockImportWizardNotifier() : super(const ImportWizardState());
}

void main() {
  Widget createWidgetUnderTest(MockImportWizardNotifier mockNotifier) {
    return ProviderScope(
      overrides: [
        importWizardProvider.overrideWith((ref) => mockNotifier),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportWizardPage(),
      ),
    );
  }

  testWidgets('ImportWizardPage renders initial step correctly',
      (WidgetTester tester) async {
    final mockNotifier = MockImportWizardNotifier();
    await tester.pumpWidget(createWidgetUnderTest(mockNotifier));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Import data'), findsOneWidget);

    // Verify Stepper
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    // Verify Initial Step Content (Select File)
    expect(find.text('Select File'), findsOneWidget); // Instruction Card Title
    expect(find.text('FILE'), findsOneWidget); // Section Title
    expect(find.text('No file selected'), findsOneWidget);
  });

  testWidgets('ImportWizardPage disposes cleanly', (WidgetTester tester) async {
    final mockNotifier = MockImportWizardNotifier();

    await tester.pumpWidget(createWidgetUnderTest(mockNotifier));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
