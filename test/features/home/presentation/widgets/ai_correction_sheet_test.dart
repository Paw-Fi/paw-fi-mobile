import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/services/interactive_ai_analysis.dart';
import 'package:moneko/features/home/presentation/widgets/ai_correction_sheet.dart';

void main() {
  const question = AiAnalysisQuestion(
      question: 'Who gets the remaining 30?',
      choices: ['Give 30 to Alice', 'Give 30 to myself']);

  Future<void> mount(WidgetTester tester, void Function(String?) result) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async =>
                      result(await showAiCorrectionSheet(context, question)),
                  child: const Text('Open'),
                )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('choice returns the selected answer without any persistence',
      (tester) async {
    String? result;
    await mount(tester, (value) => result = value);
    await tester.tap(find.text('Give 30 to Alice'));
    await tester.pumpAndSettle();
    expect(result, 'Give 30 to Alice');
  });

  testWidgets('custom answer accepts multilingual financial corrections',
      (tester) async {
    String? result;
    await mount(tester, (value) => result = value);
    await tester.enterText(find.byType(EditableText), '合計は70です');
    await tester.pump();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, '合計は70です');
  });

  testWidgets('cancel returns null and does not select a default choice',
      (tester) async {
    String? result = 'not completed';
    await mount(tester, (value) => result = value);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
