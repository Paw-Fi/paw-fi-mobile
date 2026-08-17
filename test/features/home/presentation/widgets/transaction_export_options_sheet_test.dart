import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_export_options_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets('keeps localized export format labels within a narrow sheet',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        _testApp(
          locale: locale,
          child: const TransactionExportOptionsSheet(
            spaces: [],
            personalLabel: 'Personal',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: locale.toLanguageTag());
    }
  });

  testWidgets('returns the selected receipt export request', (tester) async {
    TransactionExportRequest? request;

    await tester.pumpWidget(
      _testApp(
        locale: const Locale('es'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              request = await showTransactionExportOptionsSheet(
                context: context,
                spaces: const [],
                personalLabel: 'Personal',
              );
            },
            child: const Text('Open export'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprobantes (ZIP)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar transacciones').last);
    await tester.pumpAndSettle();

    expect(request, isNotNull);
    expect(request!.format, TransactionExportFormat.receiptsZip);
    expect(request!.space.type, TransactionExportSpaceType.all);
    expect(
        request!.dateRange.end.isAfter(request!.dateRange.start) ||
            request!.dateRange.end.isAtSameMomentAs(request!.dateRange.start),
        isTrue);
  });
}

Widget _testApp({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
