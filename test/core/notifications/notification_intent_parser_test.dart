import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/notifications/notification_intent.dart';
import 'package:moneko/core/notifications/notification_intent_parser.dart';

void main() {
  final parser = NotificationIntentParser();

  group('server event inventory mapping', () {
    test('maps every required household event type deterministically', () {
      final expectations = <String, NotificationIntentAction>{
        'expense_added': NotificationIntentAction.openExpenseSheet,
        'expense_edited': NotificationIntentAction.openExpenseSheet,
        'expense_deleted': NotificationIntentAction.openHouseholdDashboard,
        'income_added': NotificationIntentAction.openExpenseSheet,
        'income_edited': NotificationIntentAction.openExpenseSheet,
        'budget_warn': NotificationIntentAction.openBudgetStatus,
        'budget_alert': NotificationIntentAction.openBudgetStatus,
        'split_created': NotificationIntentAction.openExpenseSheet,
        'split_settled': NotificationIntentAction.openSettlementHistory,
        'settlement_completed': NotificationIntentAction.openSettlementHistory,
        'invite_accepted': NotificationIntentAction.openHouseholdDashboard,
        'member_joined': NotificationIntentAction.openHouseholdDashboard,
        'member_left': NotificationIntentAction.openHouseholdDashboard,
        'member_removed': NotificationIntentAction.openHouseholdDashboard,
        'member_reminded': NotificationIntentAction.openHouseholdDashboard,
        'invite_reminder_inviter':
            NotificationIntentAction.openHouseholdInvites,
        'invite_reminder_invitee':
            NotificationIntentAction.openHouseholdInviteAcceptance,
        'recurring_reminder': NotificationIntentAction.openRecurringEditor,
        'log_expense_reminder':
            NotificationIntentAction.openLogExpenseQuickEntry,
      };

      for (final entry in expectations.entries) {
        final intent = parser.fromData(<String, dynamic>{
          'event_type': entry.key,
          'household_id': 'hh-1',
          'expense_id': 'exp-1',
          'invite_token': 'token-1',
        });
        expect(intent.action, entry.value, reason: 'event: ${entry.key}');
      }
    });

    test('treats unsupported server-only invite events as unknown intent', () {
      final sent = parser.fromData(<String, dynamic>{
        'event_type': 'invite_sent',
      });
      final revoked = parser.fromData(<String, dynamic>{
        'event_type': 'invite_revoked',
      });

      expect(sent.action, NotificationIntentAction.unknown);
      expect(revoked.action, NotificationIntentAction.unknown);
      expect(parser.isSupportedEvent('invite_sent'), isFalse);
      expect(parser.isSupportedEvent('invite_revoked'), isFalse);
    });
  });

  group('notification data parsing', () {
    test('parses expense event to expense sheet intent', () {
      final intent = parser.fromData(<String, dynamic>{
        'event_type': 'expense_added',
        'notification_id': 'n-1',
        'expense_id': 'exp-1',
      });

      expect(intent.action, NotificationIntentAction.openExpenseSheet);
      expect(intent.expenseId, 'exp-1');
      expect(intent.notificationId, 'n-1');
    });

    test('parses inviter reminder to invites page intent', () {
      final intent = parser.fromData(<String, dynamic>{
        'event_type': 'invite_reminder_inviter',
        'household_id': 'hh-1',
      });

      expect(intent.action, NotificationIntentAction.openHouseholdInvites);
      expect(intent.householdId, 'hh-1');
    });

    test('parses invitee reminder to invitation sheet intent', () {
      final intent = parser.fromData(<String, dynamic>{
        'event_type': 'invite_reminder_invitee',
        'invite_token': 'token-1',
      });

      expect(intent.action,
          NotificationIntentAction.openHouseholdInviteAcceptance);
      expect(intent.inviteToken, 'token-1');
    });

    test('parses recurring reminder to recurring editor intent', () {
      final intent = parser.fromData(<String, dynamic>{
        'event_type': 'recurring_reminder',
        'expense_id': 'rec-1',
        'type': 'income',
      });

      expect(intent.action, NotificationIntentAction.openRecurringEditor);
      expect(intent.recurringId, 'rec-1');
      expect(intent.recurringType, 'income');
    });

    test('parses log reminder to quick entry intent', () {
      final intent = parser.fromData(<String, dynamic>{
        'event_type': 'log_expense_reminder',
      });

      expect(intent.action, NotificationIntentAction.openLogExpenseQuickEntry);
    });

    test('uses split_group_id fallback for split-created payload', () {
      final intent = parser.fromData(<String, dynamic>{
        'event_type': 'split_created',
        'split_group_id': 'sg-1',
      });

      expect(intent.action, NotificationIntentAction.openExpenseSheet);
      expect(intent.splitGroupId, 'sg-1');
    });

    test('handles nested json-stringified payload values', () {
      final intent = parser.fromData(<String, dynamic>{
        'event_type': 'expense_added',
        'expense_data': '{"amount_cents":4500}',
      });

      expect(intent.action, NotificationIntentAction.openExpenseSheet);
      expect(intent.raw['expense_data'], isA<Map<String, dynamic>>());
    });
  });

  group('deep link parsing', () {
    test('maps household invitation deep link to acceptance intent', () {
      final intent =
          parser.fromUri(Uri.parse('moneko://households/join?token=my-token'));
      expect(intent?.action,
          NotificationIntentAction.openHouseholdInviteAcceptance);
      expect(intent?.inviteToken, 'my-token');
    });

    test('maps expense deep link to expense intent', () {
      final intent = parser.fromUri(Uri.parse('moneko://expense/exp-777'));
      expect(intent?.action, NotificationIntentAction.openExpenseSheet);
      expect(intent?.expenseId, 'exp-777');
    });

    test('maps household deep link to household dashboard intent', () {
      final intent = parser.fromUri(Uri.parse('moneko://household/hh-999'));
      expect(intent?.action, NotificationIntentAction.openHouseholdDashboard);
      expect(intent?.householdId, 'hh-999');
    });

    test('maps budget deep link to budget status intent', () {
      final intent = parser.fromUri(Uri.parse('moneko://budget/bud-1'));
      expect(intent?.action, NotificationIntentAction.openBudgetStatus);
      expect(intent?.budgetId, 'bud-1');
    });

    test('maps split deep link to expense intent with split id', () {
      final intent = parser.fromUri(Uri.parse('moneko://split/sg-1'));
      expect(intent?.action, NotificationIntentAction.openExpenseSheet);
      expect(intent?.splitId, 'sg-1');
    });

    test('maps recurring deep link to recurring editor intent', () {
      final intent = parser.fromUri(Uri.parse('moneko://recurring/rec-1'));
      expect(intent?.action, NotificationIntentAction.openRecurringEditor);
      expect(intent?.recurringId, 'rec-1');
    });

    test('maps log deep link to quick entry intent', () {
      final intent = parser.fromUri(Uri.parse('moneko://expenses/log'));
      expect(intent?.action, NotificationIntentAction.openLogExpenseQuickEntry);
    });

    test('maps household settings tab=2 deep link to invites intent', () {
      final intent =
          parser.fromUri(Uri.parse('moneko://household/hh-1/settings?tab=2'));
      expect(intent?.action, NotificationIntentAction.openHouseholdInvites);
      expect(intent?.householdId, 'hh-1');
    });
  });
}
