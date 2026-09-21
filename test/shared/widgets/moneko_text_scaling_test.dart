import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/shared/widgets/moneko_settings_tile.dart';
import 'package:moneko/shared/widgets/transaction_list_tile.dart';

Widget _scaleHarness({required double scale, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('accessible scaling keeps the system scaler unchanged',
      (tester) async {
    await tester.pumpWidget(
      _scaleHarness(
        scale: 2,
        child: MonekoTextScale(
          mode: MonekoTextScaling.accessible,
          child: Builder(
            builder: (context) => Text(
              '${MediaQuery.textScalerOf(context).scale(16)}',
            ),
          ),
        ),
      ),
    );

    expect(find.text('32.0'), findsOneWidget);
  });

  testWidgets('constrained scaling preserves default scale and clamps extremes',
      (tester) async {
    await tester.pumpWidget(
      _scaleHarness(
        scale: 1,
        child: MonekoTextScale(
          mode: MonekoTextScaling.constrained,
          child: Builder(
            builder: (context) => Text(
              '${MediaQuery.textScalerOf(context).scale(16)}',
            ),
          ),
        ),
      ),
    );
    expect(find.text('16.0'), findsOneWidget);

    await tester.pumpWidget(
      _scaleHarness(
        scale: 2,
        child: MonekoTextScale(
          mode: MonekoTextScaling.constrained,
          child: Builder(
            builder: (context) => Text(
              '${MediaQuery.textScalerOf(context).scale(16)}',
            ),
          ),
        ),
      ),
    );
    expect(find.text('21.6'), findsOneWidget);
  });

  testWidgets('shared financial rows remain usable at large text',
      (tester) async {
    await tester.pumpWidget(
      _scaleHarness(
        scale: 2,
        child: const Column(
          children: [
            TransactionListTile(
              category: 'food',
              title: 'A very long localized transaction title',
              subtitle: 'A very long localized subtitle',
              amount: 12482.10,
              currency: 'USD',
              isIncome: false,
              showCurrencyFlag: false,
            ),
            MonekoSettingsTile(
              label: 'A very long localized setting label',
              value: 'A very long localized setting value',
            ),
            MonekoDisclosureRow(
              label: 'A very long localized label',
              value: 'A very long localized value',
              onTap: null,
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('\$'), findsWidgets);
  });
}
