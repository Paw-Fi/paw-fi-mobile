import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';

void main() {
  testWidgets('disabled disclosure row omits the chevron', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MonekoDisclosureRow(
            label: 'Wallet',
            value: 'No wallet',
            onTap: null,
          ),
        ),
      ),
    );

    expect(find.text('No wallet'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });
}
