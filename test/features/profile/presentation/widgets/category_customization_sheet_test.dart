import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/profile/presentation/widgets/category_customization_sheet.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  testWidgets('custom categories preserve stored names across settings UI', (
    tester,
  ) async {
    const categoryName = 'utilities (electricity and water)';
    const config = UserCategoryConfig(
      visibleExpenseCategories: <String>['groceries', 'other', 'uncategorized'],
      visibleIncomeCategories: <String>['income', 'other'],
      hiddenExpenseCategories: <String>{},
      hiddenIncomeCategories: <String>{},
      customCategories: <UserCustomCategory>[
        UserCustomCategory(
          name: categoryName,
          transactionType: 'expense',
          colorArgb: 0xFF336699,
          iconKey: 'tag',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userCategoryConfigProvider.overrideWith((ref) async => config),
          userCategoryRemapsProvider.overrideWith(
            (ref) async => const <UserCategoryRemapPreference>[],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CategoryCustomizationSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(categoryName), findsOneWidget);

    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    expect(find.text(categoryName), findsWidgets);

    await tester.tap(find.text(l10n.delete).last);
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.customCategoryDeleteConfirmation(categoryName)),
      findsOneWidget,
    );
  });

  testWidgets('category remaps are visible in customization sheet', (
    tester,
  ) async {
    const config = UserCategoryConfig(
      visibleExpenseCategories: <String>['groceries', 'restaurants', 'other'],
      visibleIncomeCategories: <String>['income', 'other'],
      hiddenExpenseCategories: <String>{},
      hiddenIncomeCategories: <String>{},
      customCategories: <UserCustomCategory>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userCategoryConfigProvider.overrideWith((ref) async => config),
          userCategoryRemapsProvider.overrideWith(
            (ref) async => const <UserCategoryRemapPreference>[
              UserCategoryRemapPreference(
                transactionType: 'expense',
                fromCategory: 'restaurants',
                toCategory: 'groceries',
                useCount: 2,
                lastUsedAt: null,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CategoryCustomizationSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('AI MAPPINGS'), findsOneWidget);
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });
}
