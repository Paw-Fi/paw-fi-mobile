import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/import/data/import_mapping.dart';
import 'package:moneko/features/import/data/import_parser.dart';
import 'package:moneko/features/import/domain/import_models.dart';
import 'package:intl/intl.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  test('decodeImportTextFromBytes supports UTF-8', () {
    final bytes = Uint8List.fromList(
      utf8.encode('date,description\n2026-02-01,Coffee shop'),
    );

    final decoded = decodeImportTextFromBytes(bytes);

    expect(decoded, contains('Coffee shop'));
  });

  test('decodeImportTextFromBytes falls back to latin1', () {
    final bytes = Uint8List.fromList(
      latin1.encode('date,description\n2026-02-01,Café'),
    );

    final decoded = decodeImportTextFromBytes(bytes);

    expect(decoded, contains('Café'));
  });

  test('decodeImportTextFromBytes handles UTF-16 LE BOM', () {
    const text = 'date,description\n2026-02-01,Salary';
    final codeUnits = text.codeUnits;
    final bytes = <int>[0xFF, 0xFE];
    for (final unit in codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }

    final decoded = decodeImportTextFromBytes(Uint8List.fromList(bytes));

    expect(decoded, contains('Salary'));
  });

  test('detectDelimiter prefers the most frequent delimiter', () {
    expect(detectDelimiter('date,amount,category'), ',');
    expect(detectDelimiter('date\tamount\tcategory'), '\t');
    expect(detectDelimiter('date;amount;category'), ';');
  });

  test('parseImportTable reads header and rows', () {
    const content = 'date,amount,category\n2026-02-01,12.5,Food';
    final table = parseImportTable(content);

    expect(table.headers, ['date', 'amount', 'category']);
    expect(table.rows.length, 1);
    expect(table.rows.first, ['2026-02-01', '12.5', 'Food']);
  });

  test('localized CSV headers, dates, and transaction types parse correctly',
      () {
    const content = '日期,收支类型,类别,账户,金额,备注\n'
        '2023年01月01日,支出,礼物,未关联,3.99,给宝买的花\n'
        '2023年01月02日,收入,餐饮,未关联,21,退款';
    final table = parseImportTable(content);
    final mappingResult = autoMapFieldsWithConfidence(
      table.headers,
      sampleRows: table.rows,
    );

    expect(table.headers, ['日期', '收支类型', '类别', '账户', '金额', '备注']);
    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.date], 0);
    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.type], 1);
    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.category], 2);
    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.amount], 4);
    expect(
        mappingResult.mapping.fieldToColumnIndex[ImportField.description], 5);

    final expense = parseRow(table.rows.first, mappingResult.mapping);
    expect(expense.isValid, isTrue);
    expect(expense.date, DateTime(2023, 1, 1));
    expect(expense.amountCents, 399);
    expect(expense.type, 'expense');
    expect(expense.category, 'gifts');
    expect(expense.description, '给宝买的花');

    final income = parseRow(table.rows.last, mappingResult.mapping);
    expect(income.date, DateTime(2023, 1, 2));
    expect(income.amountCents, 2100);
    expect(income.type, 'income');
  });

  test('supported app locales map localized headers and type values', () {
    expect(AppLocalizations.supportedLocales, hasLength(15));

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final content =
          '${l10n.date},${l10n.type},${l10n.category},${l10n.amount},${l10n.notes}\n'
          '2025-01-02,${l10n.expense},${l10n.categoryGroceries},12.50,local expense\n'
          '2025-01-03,${l10n.income},${l10n.categoryIncome},1000,local income';
      final table = parseImportTable(content);
      final mappingResult = autoMapFieldsWithConfidence(
        table.headers,
        sampleRows: table.rows,
      );

      expect(
        mappingResult.mapping.fieldToColumnIndex[ImportField.date],
        0,
        reason: locale.toLanguageTag(),
      );
      expect(
        mappingResult.mapping.fieldToColumnIndex[ImportField.type],
        1,
        reason: locale.toLanguageTag(),
      );
      expect(
        mappingResult.mapping.fieldToColumnIndex[ImportField.category],
        2,
        reason: locale.toLanguageTag(),
      );
      expect(
        mappingResult.mapping.fieldToColumnIndex[ImportField.amount],
        3,
        reason: locale.toLanguageTag(),
      );

      final expense = parseRow(table.rows.first, mappingResult.mapping);
      final income = parseRow(table.rows.last, mappingResult.mapping);
      expect(expense.isValid, isTrue, reason: locale.toLanguageTag());
      expect(expense.type, 'expense', reason: locale.toLanguageTag());
      expect(income.isValid, isTrue, reason: locale.toLanguageTag());
      expect(income.type, 'income', reason: locale.toLanguageTag());
    }
  });

  test('absolute amounts use bank transaction code direction columns', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.type: 1,
        ImportField.amount: 2,
        ImportField.description: 3,
      },
    );

    final debit = parseRow(['2025-01-02', 'DB', '12.50', 'Groceries'], mapping);
    final credit = parseRow(['2025-01-03', 'CR', '1000', 'Salary'], mapping);

    expect(debit.isValid, isTrue);
    expect(debit.amountCents, 1250);
    expect(debit.type, 'expense');
    expect(credit.isValid, isTrue);
    expect(credit.amountCents, 100000);
    expect(credit.type, 'income');
  });

  test('parseImportTable handles quoted CSV rows with trailing spaces', () {
    const content = '"TIME","TYPE","AMOUNT","CATEGORY","ACCOUNT","NOTES" \n'
        '"Feb 05, 2025 7:08 AM","(-) Expense","200.00","Food","Cash","chanay aur dahi" \n'
        '"Apr 14, 2025 1:10 PM","(*) Transfer","5000.00","  -  ","Cash->Meezan","mama withdraw" \n'
        '"Apr 14, 2025 6:03 PM","(+) Income","222407.00","Direct","Meezan","Andre" ';

    final table = parseImportTable(content);

    expect(
      table.headers,
      ['TIME', 'TYPE', 'AMOUNT', 'CATEGORY', 'ACCOUNT', 'NOTES'],
    );
    expect(table.rows.length, 3);
    expect(table.rows[0], [
      'Feb 05, 2025 7:08 AM',
      '(-) Expense',
      '200.00',
      'Food',
      'Cash',
      'chanay aur dahi',
    ]);
    expect(table.rows[1][5], 'mama withdraw');
    expect(table.rows[2][4], 'Meezan');
  });

  test('parseImportTable preserves embedded newlines inside quoted fields', () {
    const content = '"date","notes","amount"\n'
        '"2025-02-05","first line  \nsecond line","12.50"\n'
        '"2025-02-06","single line","9.00"';

    final table = parseImportTable(content);

    expect(table.rows.length, 2);
    expect(table.rows.first[1], 'first line  \nsecond line');
    expect(table.rows.last[1], 'single line');
  });

  test('parseImportTable keeps first row when file has no header row', () {
    const content = '2025-02-05,-12.50,Coffee shop\n'
        '2025-02-06,-9.00,Bakery';

    final table = parseImportTable(content);

    expect(table.headers, ['Column 1', 'Column 2', 'Column 3']);
    expect(table.rows.length, 2);
    expect(table.rows.first, ['2025-02-05', '-12.50', 'Coffee shop']);
  });

  test('parseRow maps required fields and validates', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.category: 2,
      },
    );
    final row = ['2026-02-01', '12.50', 'Food'];
    final parsed = parseRow(row, mapping);

    expect(parsed.errors, isEmpty);
    expect(parsed.date, DateTime(2026, 2, 1));
    expect(parsed.amountCents, 1250);
    expect(parsed.category, 'food & drinks');
  });

  test('parseRow rejects zero-amount transactions before save', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.category: 2,
      },
    );

    final parsed = parseRow(['2026-02-01', '0.00', 'Food'], mapping);

    expect(parsed.isValid, isFalse);
    expect(parsed.errors, contains('invalid_amount'));
  });

  test('parseRow rejects categories the batch endpoint cannot sanitize', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.category: 2,
      },
    );
    final overlongCategory = 'a' * 97;

    final parsed = parseRow(['2026-02-01', '12.50', overlongCategory], mapping);

    expect(parsed.isValid, isFalse);
    expect(parsed.errors, contains('invalid_category'));
  });

  test('parseRow preserves merchant separately from description', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.merchant: 2,
        ImportField.description: 3,
      },
    );

    final parsed = parseRow(
      ['2026-02-01', '-12.50', 'Blue Bottle', 'coffee beans'],
      mapping,
    );

    expect(parsed.isValid, isTrue);
    expect(parsed.merchant, 'Blue Bottle');
    expect(parsed.description, 'coffee beans');
  });

  test('parseRow uses merchant to infer category when description is absent',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.merchant: 2,
      },
    );

    final parsed = parseRow(
      ['2026-02-01', '-99.00', 'Twilio'],
      mapping,
    );

    expect(parsed.merchant, 'Twilio');
    expect(parsed.category, 'software tools');
  });

  test('parseRow canonicalizes localized built-in category labels', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.category: 2,
      },
    );
    final ru = lookupAppLocalizations(const Locale('ru'));
    final parsed = parseRow(
      ['2026-02-01', '12.50', ru.categorySoftwareTools],
      mapping,
    );

    expect(parsed.category, 'software tools');
  });

  test('parseRow treats a single mapped debit column as an expense', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.description: 0,
        ImportField.date: 1,
        ImportField.debit: 2,
      },
    );
    final parsed = parseRow(
      ['Resend', '10/01/2025', r'$20'],
      mapping,
    );

    expect(parsed.isValid, isTrue);
    expect(parsed.amountCents, 2000);
    expect(parsed.type, 'expense');
  });

  test('parseRow respects an inferred day-first date order hint', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.description: 0,
        ImportField.date: 1,
        ImportField.debit: 2,
      },
    );
    final parsed = parseRow(
      ['Resend', '10/01/2025', r'$20'],
      mapping,
      dateOrderHint: ImportDateOrderHint.dayMonthYear,
    );

    expect(parsed.date, DateTime(2025, 1, 10));
  });

  test(
      'parseRow infers software tools category from high-confidence SaaS merchants',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.description: 0,
        ImportField.date: 1,
        ImportField.debit: 2,
      },
    );
    final parsed = parseRow(
      ['Twilio (WhatsApp)', '26/01/2026', r'$99'],
      mapping,
    );

    expect(parsed.category, 'software tools');
  });

  test('parseDateValue parses English month with 12-hour time', () {
    final parsed = parseDateValue('Feb 05, 2025 7:08 AM');

    expect(parsed, DateTime(2025, 2, 5));
  });

  test(
      'parseDateValue parses English month with 12-hour time on non-English locale',
      () {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'fr_FR';

    addTearDown(() {
      Intl.defaultLocale = previousLocale;
    });

    final parsed = parseDateValue('  "Apr 14, 2025 1:10 PM"  ');

    expect(parsed, DateTime(2025, 4, 14));
  });

  test(
      'parseDateValue parses English month with 24-hour time on non-English locale',
      () {
    final previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'fr_FR';

    addTearDown(() {
      Intl.defaultLocale = previousLocale;
    });

    final parsed = parseDateValue('Apr 14, 2025 13:10');

    expect(parsed, DateTime(2025, 4, 14));
  });

  test('parseDateValue parses year-first dates with localized separators', () {
    expect(parseDateValue('2023年01月01日'), DateTime(2023, 1, 1));
    expect(parseDateValue('2024년 7월 3일'), DateTime(2024, 7, 3));
    expect(parseDateValue('２０２５年１２月０５日 09:15'), DateTime(2025, 12, 5));
  });

  test('parseDateValue parses localized month names used by CSV importers', () {
    expect(parseDateValue('5 May 2021'), DateTime(2021, 5, 5));
    expect(parseDateValue('5 Mai 2021'), DateTime(2021, 5, 5));
    expect(parseDateValue('5 mai 2021'), DateTime(2021, 5, 5));
    expect(parseDateValue('5 maggio 2021'), DateTime(2021, 5, 5));
    expect(parseDateValue('5 mei 2021'), DateTime(2021, 5, 5));
    expect(parseDateValue('5 мая 2021'), DateTime(2021, 5, 5));
    expect(parseDateValue('5 травня 2021'), DateTime(2021, 5, 5));
    expect(parseDateValue('๕ พฤษภาคม ๒๕๖๕'), DateTime(2022, 5, 5));
  });

  test('parseRow validates exported app CSV rows with TIME and AMOUNT columns',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.type: 1,
        ImportField.amount: 2,
        ImportField.category: 3,
        ImportField.description: 5,
      },
    );

    final parsed = parseRow(
      [
        'Feb 05, 2025 7:08 AM',
        '(-) Expense',
        '200.00',
        'Food',
        'Cash',
        'chanay aur dahi',
      ],
      mapping,
    );

    expect(parsed.isValid, isTrue);
    expect(parsed.date, DateTime(2025, 2, 5));
    expect(parsed.amountCents, 20000);
    expect(parsed.type, 'expense');
    expect(parsed.description, 'chanay aur dahi');
  });

  test(
      'parseRow infers currency from amount text when no currency column exists',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
      },
    );

    final parsed = parseRow(
      ['2025-02-05', 'EUR 12.50'],
      mapping,
    );

    expect(parsed.currency, 'EUR');
    expect(parsed.amountCents, 1250);
  });

  test('parseRow recognizes RUR aliases from amount text in local imports', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.debit: 1,
      },
    );

    final parsed = parseRow(
      ['04.01.2026', '1 110,00 RUR'],
      mapping,
      dateOrderHint: ImportDateOrderHint.dayMonthYear,
    );

    expect(parsed.currency, 'RUB');
    expect(parsed.type, 'expense');
    expect(parsed.amountCents, 111000);
  });

  test('parseRow does not use opaque reference ids as description fallback',
      () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.reference: 2,
      },
    );
    final row = ['2026-02-01', '12.50', '9f3b5c2a-4b37-4c0d-9f7a-4f9c5c2b1e88'];
    final parsed = parseRow(row, mapping);

    expect(parsed.description, isNull);
  });

  test('parseRow uses meaningful reference text as description fallback', () {
    const mapping = ImportMapping(
      fieldToColumnIndex: {
        ImportField.date: 0,
        ImportField.amount: 1,
        ImportField.reference: 2,
      },
    );
    final row = ['2026-02-01', '12.50', 'Blue Bottle coffee beans'];
    final parsed = parseRow(row, mapping);

    expect(parsed.description, 'Blue Bottle coffee beans');
  });

  test('actual website expenses CSV auto-maps and stays expense-only',
      () async {
    final content =
        await File('../Moneko Expenses - Website.csv').readAsString();
    final table = parseImportTable(content);
    final sampleRows =
        table.rows.length > 10 ? table.rows.sublist(0, 10) : table.rows;
    final mappingResult = autoMapFieldsWithConfidence(
      table.headers,
      sampleRows: sampleRows,
    );
    final dateOrderHint = inferDateOrderHint(
      table.rows,
      mappingResult.mapping.fieldToColumnIndex[ImportField.date],
    );

    final parsed = table.rows
        .map(
          (row) => parseRow(
            row,
            mappingResult.mapping,
            dateOrderHint: dateOrderHint,
          ),
        )
        .where((row) => row.amountCents != null)
        .toList(growable: false);

    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.date], 1);
    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.debit], 2);
    expect(
      mappingResult.mapping.fieldToColumnIndex.containsKey(ImportField.amount),
      isFalse,
    );
    expect(parsed, isNotEmpty);
    expect(parsed.every((row) => row.type == 'expense'), isTrue);
  });

  test('headerless exports still auto-map date and amount columns', () {
    const content = '2025-02-05,-12.50,Coffee shop\n'
        '2025-02-06,-9.00,Bakery';
    final table = parseImportTable(content);
    final mappingResult = autoMapFieldsWithConfidence(
      table.headers,
      sampleRows: table.rows,
    );

    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.date], 0);
    expect(mappingResult.mapping.fieldToColumnIndex[ImportField.amount], 1);
  });

  test('parseAmountCents handles spaced, apostrophe, and unicode-minus values',
      () {
    expect(parseAmountCents('1 234,56'), 123456);
    expect(parseAmountCents("1'234.56"), 123456);
    expect(parseAmountCents('−1 234,56'), -123456);
    expect(parseAmountCents('1 234,56'), 123456);
  });

  test('parseAmountCents handles non-Latin digits and currency text', () {
    expect(parseAmountCents('د.إ ١٬٢٣٤٫٥٦'), 123456);
    expect(parseAmountCents('￥１，２３４．５６'), 123456);
  });

  test('parseAmountCents does not treat arbitrary text with digits as money',
      () {
    expect(parseAmountCents('Column 1'), isNull);
    expect(parseAmountCents('Food 12'), isNull);
  });
}
