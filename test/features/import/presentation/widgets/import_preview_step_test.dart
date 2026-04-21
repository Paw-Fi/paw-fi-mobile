import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:moneko/features/import/presentation/widgets/import_preview_step.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets('TransactionPreviewTile localizes category fallback titles',
      (tester) async {
    const row = ImportParsedRow(
      index: 0,
      date: null,
      amountCents: 1299,
      category: 'software tools',
      description: null,
      currency: 'USD',
      type: 'expense',
      errors: [],
      rawValues: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TransactionPreviewTile(
            row: row,
            isFirst: true,
            isLast: true,
            onTap: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('fr'));
    expect(find.text(l10n.categorySoftwareTools), findsOneWidget);
    expect(find.text('software tools'), findsNothing);
  });
}
