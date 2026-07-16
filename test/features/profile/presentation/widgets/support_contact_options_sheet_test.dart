import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/profile/presentation/widgets/support_contact_options_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    ValueChanged<SupportContactOption?>? onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final option = await SupportContactOptionsSheet.show(context);
                onSelected?.call(option);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers Reddit before ticket submission', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Ask on Reddit'), findsOneWidget);
    expect(find.text('Submit a ticket'), findsOneWidget);

    final redditTop = tester.getTopLeft(find.text('Ask on Reddit')).dy;
    final ticketTop = tester.getTopLeft(find.text('Submit a ticket')).dy;
    expect(redditTop, lessThan(ticketTop));
  });

  testWidgets('returns the Reddit option and dismisses the sheet',
      (tester) async {
    SupportContactOption? selectedOption;
    await pumpSheet(tester, onSelected: (option) => selectedOption = option);

    await tester.tap(find.text('Ask on Reddit'));
    await tester.pumpAndSettle();
    expect(selectedOption, SupportContactOption.reddit);
    expect(find.text('Ask on Reddit'), findsNothing);
  });

  testWidgets('returns the ticket option and dismisses the sheet',
      (tester) async {
    SupportContactOption? selectedOption;
    await pumpSheet(tester, onSelected: (option) => selectedOption = option);

    await tester.tap(find.text('Submit a ticket'));
    await tester.pumpAndSettle();
    expect(selectedOption, SupportContactOption.ticket);
    expect(find.text('Submit a ticket'), findsNothing);
  });
}
