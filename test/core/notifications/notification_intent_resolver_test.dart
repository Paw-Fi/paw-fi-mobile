import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/notifications/notification_intent.dart';
import 'package:moneko/core/notifications/notification_intent_resolver.dart';

void main() {
  test('resolves split group id into expense id', () async {
    final resolver = NotificationIntentResolver(
      lookupExpenseIdBySplitGroup: (splitGroupId) async {
        expect(splitGroupId, 'sg-1');
        return 'exp-123';
      },
    );

    final resolved = await resolver.resolve(
      const NotificationIntent(
        action: NotificationIntentAction.openExpenseSheet,
        args: <String, dynamic>{'split_group_id': 'sg-1'},
      ),
    );

    expect(resolved.expenseId, 'exp-123');
  });
}
