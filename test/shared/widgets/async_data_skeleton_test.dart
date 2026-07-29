import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/shared/widgets/async_data_skeleton.dart';

void main() {
  testWidgets('renders stable data-shaped rows without a progress spinner',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AsyncDataSkeleton(rowCount: 4),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('async-skeleton-row')), findsNWidgets(4));
  });

  testWidgets('refresh strip retains its height while visibility changes',
      (tester) async {
    Future<void> pump({required bool isRefreshing}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AsyncRefreshStrip(isRefreshing: isRefreshing),
                const Text('Cached content'),
              ],
            ),
          ),
        ),
      );
    }

    await pump(isRefreshing: false);
    final hiddenHeight = tester
        .getSize(
          find.byKey(const ValueKey('async-refresh-strip')),
        )
        .height;
    expect(find.text('Cached content'), findsOneWidget);

    await pump(isRefreshing: true);
    await tester.pump(const Duration(milliseconds: 200));
    final visibleHeight = tester
        .getSize(
          find.byKey(const ValueKey('async-refresh-strip')),
        )
        .height;

    expect(visibleHeight, hiddenHeight);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cached content'), findsOneWidget);
  });
}
