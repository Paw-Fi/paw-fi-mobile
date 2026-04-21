import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/recurring/presentation/utils/reminder_before_affixes.dart';

void main() {
  group('resolveReminderBeforeAffixes', () {
    test('uses explicit prefix and suffix when provided', () {
      final affixes = resolveReminderBeforeAffixes(
        before: '在...之前',
        beforePrefix: '在',
        beforeSuffix: '之前',
      );

      expect(affixes.prefix, '在');
      expect(affixes.suffix, '之前');
    });

    test('supports prefix-only languages', () {
      final affixes = resolveReminderBeforeAffixes(
        before: 'before',
        beforePrefix: 'before',
        beforeSuffix: '',
      );

      expect(affixes.prefix, 'before');
      expect(affixes.suffix, isEmpty);
    });

    test('supports suffix-only languages', () {
      final affixes = resolveReminderBeforeAffixes(
        before: '...전에',
        beforePrefix: '',
        beforeSuffix: '전에',
      );

      expect(affixes.prefix, isEmpty);
      expect(affixes.suffix, '전에');
    });

    test('falls back to parsing marker from before token', () {
      final affixes = resolveReminderBeforeAffixes(
        before: '在...之前',
        beforePrefix: '',
        beforeSuffix: '',
      );

      expect(affixes.prefix, '在');
      expect(affixes.suffix, '之前');
    });

    test('falls back to before token as prefix without marker', () {
      final affixes = resolveReminderBeforeAffixes(
        before: 'avant',
        beforePrefix: '',
        beforeSuffix: '',
      );

      expect(affixes.prefix, 'avant');
      expect(affixes.suffix, isEmpty);
    });
  });
}
