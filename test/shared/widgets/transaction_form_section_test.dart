import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/transaction_form_section.dart';

void main() {
  Widget buildSubject({required String category}) {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TransactionFormSection(
          amount: 12.99,
          category: category,
          date: DateTime(2026, 2, 1),
          description: null,
          currency: 'USD',
          isIncome: false,
          onEditAmount: () {},
          onEditCategory: () {},
          onEditDate: () {},
          onEditDescription: () {},
          onEditCurrency: () {},
          onToggleType: () {},
        ),
      ),
    );
  }

  testWidgets('localizes canonical category values by default', (tester) async {
    await tester.pumpWidget(buildSubject(category: 'software tools'));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('fr'));
    expect(find.text(l10n.categorySoftwareTools), findsOneWidget);
    expect(find.text('software tools'), findsNothing);
  });

  testWidgets('localizes uncategorized fallback by default', (tester) async {
    await tester.pumpWidget(buildSubject(category: ''));
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('fr'));
    expect(find.text(l10n.categoryUncategorized), findsOneWidget);
    expect(find.text('Uncategorized'), findsNothing);
  });
}
