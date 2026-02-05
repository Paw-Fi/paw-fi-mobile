import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/pockets/presentation/widgets/create_budget_from_template_sheet.dart';

void main() {
  test('updatePocketEntryById returns same list when id missing', () {
    final entries = [
      PocketEntry(
        id: 'a',
        name: 'Alpha',
        color: Colors.red,
        categories: const ['c1'],
        amount: 10,
      ),
      PocketEntry(
        id: 'b',
        name: 'Beta',
        color: Colors.blue,
        categories: const ['c2'],
        amount: 20,
      ),
    ];

    final updated = updatePocketEntryById(
      entries,
      id: 'missing',
      update: (entry) => entry.copyWith(amount: 99),
    );

    expect(updated.length, entries.length);
    expect(updated[0].id, 'a');
    expect(updated[1].id, 'b');
    expect(updated[0].amount, 10);
    expect(updated[1].amount, 20);
  });

  test('updatePocketEntryById updates matching entry by id', () {
    final entries = [
      PocketEntry(
        id: 'a',
        name: 'Alpha',
        color: Colors.red,
        categories: const ['c1'],
        amount: 10,
      ),
      PocketEntry(
        id: 'b',
        name: 'Beta',
        color: Colors.blue,
        categories: const ['c2'],
        amount: 20,
      ),
    ];

    final updated = updatePocketEntryById(
      entries,
      id: 'b',
      update: (entry) => entry.copyWith(amount: 42),
    );

    expect(updated[0].amount, 10);
    expect(updated[1].amount, 42);
  });

  test('removePocketEntryById removes matching entry by id', () {
    final entries = [
      PocketEntry(
        id: 'a',
        name: 'Alpha',
        color: Colors.red,
        categories: const ['c1'],
        amount: 10,
      ),
      PocketEntry(
        id: 'b',
        name: 'Beta',
        color: Colors.blue,
        categories: const ['c2'],
        amount: 20,
      ),
    ];

    final updated = removePocketEntryById(entries, id: 'a');

    expect(updated.length, 1);
    expect(updated.first.id, 'b');
  });
}
