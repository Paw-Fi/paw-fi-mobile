import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest initialize_app_v2 definition returns is_portfolio', () {
    final migrations = Directory('../moneko-web/supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .where((file) {
      final sql = file.readAsStringSync().toLowerCase();
      return sql.contains('create or replace function') &&
          sql.contains('initialize_app_v2(');
    }).toList()
      ..sort((left, right) => left.path.compareTo(right.path));

    expect(migrations, isNotEmpty);
    final latestDefinition = migrations.last.readAsStringSync();
    expect(
      latestDefinition,
      contains('h.is_portfolio'),
      reason: 'Startup hydration must preserve private-space metadata.',
    );
  });
}
