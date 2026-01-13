import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';

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

    test('maps transport to transportation', () {
      expect(normalizeCategory('transport'), 'transportation');
      expect(normalizeCategory('Transport'), 'transportation');
    });

    test('maps uber and taxi to rideshare', () {
      expect(normalizeCategory('uber'), 'rideshare');
      expect(normalizeCategory('taxi'), 'rideshare');
      expect(normalizeCategory('Uber'), 'rideshare');
      expect(normalizeCategory('Taxi'), 'rideshare');
    });

    test('maps public transit aliases', () {
      expect(normalizeCategory('bus'), 'public transit');
      expect(normalizeCategory('train'), 'public transit');
      expect(normalizeCategory('subway'), 'public transit');
      expect(normalizeCategory('metro'), 'public transit');
      expect(normalizeCategory('Bus'), 'public transit');
    });

    test('maps gasoline and fuel to gas & fuel', () {
      expect(normalizeCategory('gasoline'), 'gas & fuel');
      expect(normalizeCategory('fuel'), 'gas & fuel');
      expect(normalizeCategory('Fuel'), 'gas & fuel');
    });

    test('maps car and auto to car repairs', () {
      expect(normalizeCategory('car'), 'car repairs');
      expect(normalizeCategory('auto'), 'car repairs');
      expect(normalizeCategory('Car'), 'car repairs');
    });

    test('maps insurance to insurance', () {
      expect(normalizeCategory('insurance'), 'insurance');
      expect(normalizeCategory('Insurance'), 'insurance');
    });

    test('maps health aliases to healthcare', () {
      expect(normalizeCategory('health'), 'healthcare');
      expect(normalizeCategory('dental'), 'healthcare');
      expect(normalizeCategory('vision'), 'healthcare');
      expect(normalizeCategory('pharmacy'), 'healthcare');
      expect(normalizeCategory('doctor'), 'healthcare');
      expect(normalizeCategory('hospital'), 'healthcare');
    });

    test('maps gym and fitness aliases', () {
      expect(normalizeCategory('gym'), 'fitness');
      expect(normalizeCategory('fitness'), 'fitness');
      expect(normalizeCategory('sports'), 'fitness');
      expect(normalizeCategory('Gym'), 'fitness');
    });

    test('maps education aliases', () {
      expect(normalizeCategory('education'), 'education');
      expect(normalizeCategory('school'), 'education');
      expect(normalizeCategory('university'), 'education');
      expect(normalizeCategory('college'), 'education');
      expect(normalizeCategory('course'), 'education');
    });

    test('maps book aliases to books & supplies', () {
      expect(normalizeCategory('book'), 'books & supplies');
      expect(normalizeCategory('books'), 'books & supplies');
      expect(normalizeCategory('supplies'), 'books & supplies');
    });

    test('maps clothing aliases', () {
      expect(normalizeCategory('clothing'), 'clothing');
      expect(normalizeCategory('shoes'), 'clothing');
      expect(normalizeCategory('accessories'), 'clothing');
      expect(normalizeCategory('Clothing'), 'clothing');
    });

    test('maps entertainment aliases', () {
      expect(normalizeCategory('entertainment'), 'entertainment');
      expect(normalizeCategory('movie'), 'entertainment');
      expect(normalizeCategory('cinema'), 'entertainment');
      expect(normalizeCategory('theater'), 'entertainment');
      expect(normalizeCategory('concert'), 'entertainment');
      expect(normalizeCategory('music'), 'entertainment');
      expect(normalizeCategory('game'), 'entertainment');
      expect(normalizeCategory('gaming'), 'entertainment');
      expect(normalizeCategory('streaming'), 'entertainment');
      expect(normalizeCategory('netflix'), 'entertainment');
      expect(normalizeCategory('disney'), 'entertainment');
    });

    test('maps travel aliases', () {
      expect(normalizeCategory('travel'), 'travel');
      expect(normalizeCategory('vacation'), 'travel');
      expect(normalizeCategory('hotel'), 'travel');
      expect(normalizeCategory('airbnb'), 'travel');
      expect(normalizeCategory('flight'), 'travel');
      expect(normalizeCategory('airline'), 'travel');
    });

    test('maps donation and charity', () {
      expect(normalizeCategory('donation'), 'charity');
      expect(normalizeCategory('charity'), 'charity');
      expect(normalizeCategory('Donation'), 'charity');
    });

    test('maps pet aliases', () {
      expect(normalizeCategory('pet'), 'pets');
      expect(normalizeCategory('pet food'), 'pets');
      expect(normalizeCategory('pet supplies'), 'pets');
      expect(normalizeCategory('vet'), 'pets');
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
      expect(normalizeCategory('bank'), 'banking');
      expect(normalizeCategory('atm'), 'banking');
      expect(normalizeCategory('fee'), 'banking');
      expect(normalizeCategory('interest'), 'banking');
    });

    test('maps tax aliases', () {
      expect(normalizeCategory('tax'), 'taxes');
      expect(normalizeCategory('government'), 'taxes');
      expect(normalizeCategory('fine'), 'taxes');
    });

    test('maps legal aliases', () {
      expect(normalizeCategory('legal'), 'legal');
      expect(normalizeCategory('lawyer'), 'legal');
      expect(normalizeCategory('court'), 'legal');
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
      expect(normalizeCategory('car payment'), 'car maintenance');
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
      expect(normalizeCategory('laundry / dry cleaning'), 'laundry / dry cleaning');
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
}
