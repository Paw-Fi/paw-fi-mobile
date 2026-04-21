import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  group('normalizeCategory', () {
    test('returns canonical category when already normalized', () {
      expect(normalizeCategory('groceries'), 'groceries');
      expect(normalizeCategory('restaurants'), 'restaurants');
      expect(normalizeCategory('rent'), 'rent');
      expect(normalizeCategory('travel'), 'travel');
    });

    test('normalizes to lowercase and trims whitespace', () {
      expect(normalizeCategory('  Groceries  '), 'groceries');
      expect(normalizeCategory('RESTAURANTS'), 'restaurants');
      expect(normalizeCategory('  RENT  '), 'rent');
    });

    test('maps food aliases to food & drinks', () {
      expect(normalizeCategory('food'), 'food & drinks');
      expect(normalizeCategory('food and drinks'), 'food & drinks');
      expect(normalizeCategory('Food'), 'food & drinks');
    });

    test('maps restaurant alias to restaurants', () {
      expect(normalizeCategory('restaurant'), 'restaurants');
      expect(normalizeCategory('Restaurant'), 'restaurants');
    });

    test('maps takeout and delivery aliases', () {
      expect(normalizeCategory('takeout'), 'takeout & delivery');
      expect(normalizeCategory('delivery'), 'takeout & delivery');
      expect(normalizeCategory('Takeout'), 'takeout & delivery');
    });

    test('maps coffee and tea aliases', () {
      expect(normalizeCategory('coffee'), 'coffee & tea');
      expect(normalizeCategory('tea'), 'coffee & tea');
      expect(normalizeCategory('Coffee'), 'coffee & tea');
    });

    test('maps snack to snacks', () {
      expect(normalizeCategory('snack'), 'snacks');
      expect(normalizeCategory('Snack'), 'snacks');
    });

    test('maps grocery to groceries', () {
      expect(normalizeCategory('grocery'), 'groceries');
      expect(normalizeCategory('Grocery'), 'groceries');
    });

    test('maps home to home repairs', () {
      expect(normalizeCategory('home'), 'home repairs');
      expect(normalizeCategory('Home'), 'home repairs');
    });

    test('maps appliance to appliances', () {
      expect(normalizeCategory('appliance'), 'appliances');
      expect(normalizeCategory('Appliance'), 'appliances');
    });

    test('maps decor to home decor', () {
      expect(normalizeCategory('decor'), 'home decor');
      expect(normalizeCategory('Decor'), 'home decor');
    });

    test('maps electric to electricity', () {
      expect(normalizeCategory('electric'), 'electricity');
      expect(normalizeCategory('Electric'), 'electricity');
    });

    test('maps gas to heating & gas', () {
      expect(normalizeCategory('gas'), 'heating & gas');
      expect(normalizeCategory('Gas'), 'heating & gas');
    });

    test('maps phone to phone bill', () {
      expect(normalizeCategory('phone'), 'phone bill');
      expect(normalizeCategory('Phone'), 'phone bill');
    });

    test('maps trash to trash & recycling', () {
      expect(normalizeCategory('trash'), 'trash & recycling');
      expect(normalizeCategory('Trash'), 'trash & recycling');
    });

    test('maps security to home security', () {
      expect(normalizeCategory('security'), 'home security');
      expect(normalizeCategory('Security'), 'home security');
    });

    test('maps laundry to laundry / dry cleaning', () {
      expect(normalizeCategory('laundry'), 'laundry / dry cleaning');
      expect(normalizeCategory('Laundry'), 'laundry / dry cleaning');
    });

    test('maps moving to moving costs', () {
      expect(normalizeCategory('moving'), 'moving costs');
      expect(normalizeCategory('Moving'), 'moving costs');
    });

    test('maps transport to public transport', () {
      expect(normalizeCategory('transport'), 'public transport');
      expect(normalizeCategory('Transport'), 'public transport');
    });

    test('maps uber and taxi to taxi & ride apps', () {
      expect(normalizeCategory('uber'), 'taxi & ride apps');
      expect(normalizeCategory('taxi'), 'taxi & ride apps');
      expect(normalizeCategory('Uber'), 'taxi & ride apps');
      expect(normalizeCategory('Taxi'), 'taxi & ride apps');
    });

    test('maps public transit aliases', () {
      expect(normalizeCategory('bus'), 'public transport');
      expect(normalizeCategory('train'), 'public transport');
      expect(normalizeCategory('subway'), 'public transport');
      expect(normalizeCategory('metro'), 'public transport');
      expect(normalizeCategory('Bus'), 'public transport');
    });

    test('maps gasoline and fuel to fuel / gas', () {
      expect(normalizeCategory('gasoline'), 'fuel / gas');
      expect(normalizeCategory('fuel'), 'fuel / gas');
      expect(normalizeCategory('Fuel'), 'fuel / gas');
    });

    test('maps car and auto to car repairs', () {
      expect(normalizeCategory('car'), 'car repairs');
      expect(normalizeCategory('auto'), 'car repairs');
      expect(normalizeCategory('Car'), 'car repairs');
    });

    test('maps generic insurance to insurance', () {
      expect(normalizeCategory('insurance'), 'insurance');
      expect(normalizeCategory('Insurance'), 'insurance');
      expect(normalizeCategory('auto insurance'), 'car insurance');
    });

    test('maps health aliases to medical care', () {
      expect(normalizeCategory('health'), 'medical care');
      expect(normalizeCategory('dental'), 'dental care');
      expect(normalizeCategory('vision'), 'eye care');
      expect(normalizeCategory('pharmacy'), 'pharmacy');
      expect(normalizeCategory('doctor'), 'medical care');
      expect(normalizeCategory('hospital'), 'medical care');
    });

    test('maps gym and fitness aliases', () {
      expect(normalizeCategory('gym'), 'fitness & gym');
      expect(normalizeCategory('fitness'), 'fitness & gym');
      expect(normalizeCategory('sports'), 'sports & exercise');
      expect(normalizeCategory('Gym'), 'fitness & gym');
    });

    test('maps education aliases', () {
      expect(normalizeCategory('education'), 'courses & classes');
      expect(normalizeCategory('school'), 'courses & classes');
      expect(normalizeCategory('university'), 'courses & classes');
      expect(normalizeCategory('college'), 'courses & classes');
      expect(normalizeCategory('course'), 'courses & classes');
    });

    test('maps book aliases', () {
      expect(normalizeCategory('book'), 'books & study materials');
      expect(normalizeCategory('books'), 'books & study materials');
      expect(normalizeCategory('supplies'), 'household supplies');
    });

    test('maps clothing aliases', () {
      expect(normalizeCategory('clothing'), 'clothing & shoes');
      expect(normalizeCategory('shoes'), 'clothing & shoes');
      expect(normalizeCategory('accessories'), 'clothing & shoes');
      expect(normalizeCategory('Clothing'), 'clothing & shoes');
    });

    test('maps entertainment aliases', () {
      expect(normalizeCategory('entertainment'), 'movies & shows');
      expect(normalizeCategory('movie'), 'movies & shows');
      expect(normalizeCategory('cinema'), 'movies & shows');
      expect(normalizeCategory('theater'), 'movies & shows');
      expect(normalizeCategory('concert'), 'concerts & events');
      expect(normalizeCategory('music'), 'music & streaming');
      expect(normalizeCategory('game'), 'games & apps');
      expect(normalizeCategory('gaming'), 'games & apps');
      expect(normalizeCategory('streaming'), 'music & streaming');
      expect(normalizeCategory('netflix'), 'music & streaming');
      expect(normalizeCategory('disney'), 'music & streaming');
    });

    test('maps travel aliases', () {
      expect(normalizeCategory('travel'), 'travel');
      expect(normalizeCategory('vacation'), 'travel');
      expect(normalizeCategory('hotel'), 'hotels');
      expect(normalizeCategory('airbnb'), 'hotels');
      expect(normalizeCategory('flight'), 'flights');
      expect(normalizeCategory('airline'), 'flights');
    });

    test('maps donation and charity', () {
      expect(normalizeCategory('donation'), 'charity');
      expect(normalizeCategory('charity'), 'charity');
      expect(normalizeCategory('Donation'), 'charity');
    });

    test('maps pet aliases', () {
      expect(normalizeCategory('pet'), 'pet supplies');
      expect(normalizeCategory('pet food'), 'pet food');
      expect(normalizeCategory('pet supplies'), 'pet supplies');
      expect(normalizeCategory('vet'), 'vet visits');
    });

    test('maps personal care aliases', () {
      expect(normalizeCategory('personal'), 'personal care');
      expect(normalizeCategory('haircut'), 'personal care');
      expect(normalizeCategory('salon'), 'personal care');
      expect(normalizeCategory('spa'), 'personal care');
      expect(normalizeCategory('beauty'), 'personal care');
      expect(normalizeCategory('cosmetics'), 'personal care');
      expect(normalizeCategory('skincare'), 'personal care');
    });

    test('maps banking aliases', () {
      expect(normalizeCategory('bank'), 'bank fees');
      expect(normalizeCategory('atm'), 'bank fees');
      expect(normalizeCategory('fee'), 'bank fees');
      expect(normalizeCategory('interest'), 'interest income');
    });

    test('maps tax aliases', () {
      expect(normalizeCategory('tax'), 'taxes');
      expect(normalizeCategory('government'), 'taxes');
      expect(normalizeCategory('fine'), 'fines');
    });

    test('maps legal aliases', () {
      expect(normalizeCategory('legal'), 'professional services');
      expect(normalizeCategory('lawyer'), 'professional services');
      expect(normalizeCategory('court'), 'professional services');
    });

    test('maps business aliases', () {
      expect(normalizeCategory('business'), 'business expenses');
      expect(normalizeCategory('office'), 'business expenses');
      expect(normalizeCategory('work'), 'business expenses');
      expect(normalizeCategory('professional'), 'business expenses');
    });

    test('performs fuzzy matching for partial matches', () {
      expect(normalizeCategory('grocery store'), 'groceries');
      expect(normalizeCategory('restaurant bill'), 'restaurants');
      expect(normalizeCategory('car payment'), 'car repairs');
    });

    test('returns normalized input when no mapping found', () {
      expect(normalizeCategory('unknown category'), 'unknown category');
      expect(normalizeCategory('random'), 'random');
      expect(normalizeCategory('xyz'), 'xyz');
    });

    test('handles empty string', () {
      expect(normalizeCategory(''), '');
    });

    test('handles special characters', () {
      expect(normalizeCategory('food & drinks'), 'food & drinks');
      expect(normalizeCategory('laundry / dry cleaning'),
          'laundry / dry cleaning');
    });

    test('handles mixed case with spaces', () {
      expect(normalizeCategory('  Food And Drinks  '), 'food & drinks');
      expect(normalizeCategory('  GROCERY STORE  '), 'groceries');
    });
  });

  group('getIncomeCategories', () {
    test('returns list of income categories', () {
      final categories = getIncomeCategories();

      expect(categories, isA<List<String>>());
      expect(categories, isNotEmpty);
      expect(categories, contains('income'));
      expect(categories, contains('salary'));
      expect(categories, contains('bonus'));
      expect(categories, contains('freelance income'));
    });

    test('includes all expected income categories', () {
      final categories = getIncomeCategories();

      expect(categories, contains('tips'));
      expect(categories, contains('rental income'));
      expect(categories, contains('interest income'));
      expect(categories, contains('gift'));
      expect(categories, contains('cashback'));
      expect(categories, contains('pension'));
      expect(categories, contains('refunds'));
      expect(categories, contains('transfers'));
      expect(categories, contains('investments'));
    });
  });

  group('getExpenseCategories', () {
    test('returns list of expense categories', () {
      final categories = getExpenseCategories();

      expect(categories, isA<List<String>>());
      expect(categories, isNotEmpty);
    });

    test('excludes income categories', () {
      final categories = getExpenseCategories();
      final incomeCategories = getIncomeCategories();

      for (final income in incomeCategories) {
        expect(categories, isNot(contains(income)));
      }
      expect(categories, isNot(contains('income')));
    });

    test('includes expense categories', () {
      final categories = getExpenseCategories();

      expect(categories, contains('groceries'));
      expect(categories, contains('restaurants'));
      expect(categories, contains('rent'));
      expect(categories, contains('travel'));
    });

    test('returns sorted list', () {
      final categories = getExpenseCategories();
      final sorted = List<String>.from(categories)..sort();

      expect(categories, equals(sorted));
    });
  });

  group('resolveBuiltinCategoryKey', () {
    Future<String?> resolveForLocale(
      WidgetTester tester,
      String value, {
      Locale locale = const Locale('en'),
    }) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              result = resolveBuiltinCategoryKey(context, value);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('returns canonical key for canonical category', (tester) async {
      expect(await resolveForLocale(tester, 'groceries'), 'groceries');
    });

    testWidgets('returns canonical key for localized builtin category',
        (tester) async {
      late String localizedGroceries;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              localizedGroceries = getCategoryTranslation(context, 'groceries');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        await resolveForLocale(
          tester,
          localizedGroceries,
          locale: const Locale('zh'),
        ),
        'groceries',
      );
    });

    testWidgets('returns null for non-builtin custom category', (tester) async {
      expect(await resolveForLocale(tester, 'shopping'), isNull);
    });
  });

  group('resolveBuiltinCategoryKeyAcrossLocales', () {
    test('resolves localized built-in categories across all supported locales',
        () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);

        expect(
          resolveBuiltinCategoryKeyAcrossLocales(l10n.categorySoftwareTools),
          'software tools',
          reason: 'software tools should resolve for $locale',
        );
        expect(
          resolveBuiltinCategoryKeyAcrossLocales(l10n.categoryLicensingFees),
          'licensing & fees',
          reason: 'licensing & fees should resolve for $locale',
        );
        expect(
          resolveBuiltinCategoryKeyAcrossLocales(l10n.categoryUncategorized),
          'uncategorized',
          reason: 'uncategorized should resolve for $locale',
        );
      }
    });

    test('keeps custom categories unresolved', () {
      expect(resolveBuiltinCategoryKeyAcrossLocales('My custom label'), isNull);
    });
  });
}
