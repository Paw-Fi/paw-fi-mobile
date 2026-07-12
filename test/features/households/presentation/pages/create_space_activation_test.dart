import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/presentation/pages/create_space_page.dart';

void main() {
  test('activates a created private space before closing the creation page',
      () async {
    final events = <String>[];

    await activateCreatedSpaceBeforeClosing(
      householdId: 'ce1aabf8-90b1-41d1-9fe6-a4188b36a27f',
      selectHousehold: (householdId) async {
        events.add('select-start:$householdId');
        await Future<void>.delayed(Duration.zero);
        events.add('select-complete');
      },
      setHouseholdMode: () => events.add('mode'),
      closeCreationPage: () => events.add('close'),
    );

    expect(events, [
      'select-start:ce1aabf8-90b1-41d1-9fe6-a4188b36a27f',
      'select-complete',
      'mode',
      'close',
    ]);
  });
}
