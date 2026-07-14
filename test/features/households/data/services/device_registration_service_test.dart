import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/data/services/device_registration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'households:splits:v1:household-1:all': 'splits',
      'households:expenses:v1:household-1:1000': 'expenses',
      'households:summary:v1:household-1:USD': 'summary',
      'households:settlement-payments:v1:household-1:user-1': 'payments',
      'households:splits:v1:household-2:all': 'other-household',
      'unrelated': 'keep',
    });
  });

  test('settlement push evicts every affected household cache', () async {
    final householdId = await clearHouseholdMutationCaches(
      const {
        'event_type': 'split_settled',
        'household_id': 'household-1',
      },
    );
    final preferences = await SharedPreferences.getInstance();

    expect(householdId, 'household-1');
    expect(
      preferences.getKeys().where((key) => key.contains('household-1')),
      isEmpty,
    );
    expect(preferences.getString('households:splits:v1:household-2:all'),
        'other-household');
    expect(preferences.getString('unrelated'), 'keep');
  });

  test('unrelated push does not evict household caches', () async {
    final householdId = await clearHouseholdMutationCaches(
      const {
        'event_type': 'member_reminded',
        'household_id': 'household-1',
      },
    );
    final preferences = await SharedPreferences.getInstance();

    expect(householdId, isNull);
    expect(preferences.getString('households:splits:v1:household-1:all'),
        'splits');
  });
}
