import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/notifications/notification_event_contract.dart';

void main() {
  test('all household notification events are explicitly listed', () {
    expect(householdNotificationSupportedEvents, contains('expense_added'));
    expect(householdNotificationSupportedEvents, contains('expense_edited'));
    expect(householdNotificationSupportedEvents, contains('expense_deleted'));
    expect(householdNotificationSupportedEvents, contains('income_added'));
    expect(householdNotificationSupportedEvents, contains('income_edited'));
    expect(householdNotificationSupportedEvents, contains('budget_warn'));
    expect(householdNotificationSupportedEvents, contains('budget_alert'));
    expect(householdNotificationSupportedEvents, contains('split_created'));
    expect(householdNotificationSupportedEvents, contains('split_settled'));
    expect(
        householdNotificationSupportedEvents, contains('settlement_completed'));
    expect(householdNotificationSupportedEvents, contains('invite_accepted'));
    expect(householdNotificationSupportedEvents, contains('member_joined'));
    expect(householdNotificationSupportedEvents, contains('member_left'));
    expect(householdNotificationSupportedEvents, contains('member_removed'));
    expect(householdNotificationSupportedEvents, contains('member_reminded'));
    expect(householdNotificationSupportedEvents,
        contains('invite_reminder_inviter'));
    expect(householdNotificationSupportedEvents,
        contains('invite_reminder_invitee'));
    expect(
        householdNotificationSupportedEvents, contains('recurring_reminder'));
    expect(
        householdNotificationSupportedEvents, contains('log_expense_reminder'));
  });

  test('all listed events have a default action mapping', () {
    for (final event in householdNotificationSupportedEvents) {
      expect(householdNotificationDefaultAction.containsKey(event), isTrue);
    }
  });
}
