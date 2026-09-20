import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/insights/presentation/pages/browse_page.dart';
import 'package:moneko/features/subscription/data/models/subscription.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  Future<Subscription?> build() async => null;
}

void main() {
  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        subscriptionNotifierProvider
            .overrideWith(() => _TestSubscriptionNotifier()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets(
      'BrowsePage renders original categorized cards without description',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const BrowsePage()));
    await tester.pumpAndSettle();

    // Verify category header
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Financial health'), findsOneWidget);

    // Verify cards are rendered by title
    expect(find.text('Health report'), findsOneWidget);
    expect(find.text('Account Overview'), findsOneWidget);
  });

  testWidgets(
      'BrowsePage search filters tools dynamically and shows empty state',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const BrowsePage()));
    await tester.pumpAndSettle();

    // Search for Telegram
    await tester.enterText(find.byType(TextField), 'telegram');
    await tester.pumpAndSettle();

    expect(find.textContaining('Telegram'), findsWidgets);

    // Search for non-existent tool
    await tester.enterText(find.byType(TextField), 'nonexistenttool123');
    await tester.pumpAndSettle();

    expect(find.text('No tools match your search.'), findsOneWidget);

    // Clear search
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('No tools match your search.'), findsNothing);
    expect(find.text('Account'), findsOneWidget);
  });
}
