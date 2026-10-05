import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/ui/widgets/transaction_category_picker.dart';
import 'package:moneko/core/ui/widgets/transaction_date_picker.dart';
import 'package:moneko/features/home/presentation/widgets/category_picker_bottom_sheet.dart';
import 'package:moneko/l10n/app_localizations.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

Future<void> pumpParentSheet(
  WidgetTester tester,
  VoidCallback Function(BuildContext) action,
) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  builder: (sheetContext) => TextButton(
                    onPressed: action(sheetContext),
                    child: const Text('Open picker'),
                  ),
                ),
                child: const Text('Open parent'),
              ),
            )),
  ));
  await tester.tap(find.text('Open parent'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open picker'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('date completion cannot pop its bool parent twice',
      (tester) async {
    DateTime? result;
    await pumpParentSheet(
        tester,
        (context) => () async {
              result = await showTransactionDatePicker(
                context: context,
                currentDate: DateTime(2026, 10, 5),
              );
            });
    final done = find.widgetWithText(CupertinoButton, 'Done');
    await tester.tap(done);
    // During the exit animation, the popup is still mounted and tappable.
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result, DateTime(2026, 10, 5));
    expect(find.text('Open picker'), findsOneWidget);
  });

  testWidgets('dialog completion cannot pop its bool parent twice',
      (tester) async {
    MonekoAlertDialogResult? result;
    await pumpParentSheet(
        tester,
        (context) => () async {
              result = await MonekoAlertDialog.show(
                context: context,
                title: 'Delete transaction',
                confirmLabel: 'Confirm',
              );
            });
    await tester.tap(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(result?.confirmed, isTrue);
    expect(find.text('Open picker'), findsOneWidget);
  });

  testWidgets('late category callback ignores a dismissed sheet',
      (tester) async {
    await pumpParentSheet(
        tester,
        (context) => () => showCategoryPicker(
              context: context,
              currentCategory: 'groceries',
              isIncome: false,
              allCategories: const ['groceries'],
            ));
    final picker = tester.widget<CategoryPickerBottomSheet>(
      find.byType(CategoryPickerBottomSheet),
    );
    picker.onChanged(const ['groceries']);
    picker.onChanged(const ['groceries']);
    await tester.pumpAndSettle();
    picker.onChanged(const ['groceries']);
    expect(tester.takeException(), isNull);
    expect(find.text('Open picker'), findsOneWidget);
  });
}
