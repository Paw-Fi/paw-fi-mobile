import 'dart:convert';

import 'package:moneko/core/constants/deep_links.dart';
import 'package:moneko/core/notifications/notification_event_contract.dart';
import 'package:moneko/core/notifications/notification_intent.dart';

class NotificationIntentParser {
  NotificationIntent? fromUri(Uri uri, {Map<String, dynamic>? raw}) {
    if (DeepLinks.isHouseholdInvitation(uri)) {
      final token = _extractInviteToken(uri);
      if (token == null || token.isEmpty) {
        return null;
      }
      return NotificationIntent(
        action: NotificationIntentAction.openHouseholdInviteAcceptance,
        args: <String, dynamic>{'invite_token': token},
        raw: raw ?? const <String, dynamic>{},
      );
    }

    if (DeepLinks.isExpenseLink(uri)) {
      return NotificationIntent(
        action: NotificationIntentAction.openExpenseSheet,
        args: <String, dynamic>{'expense_id': uri.pathSegments.first},
        raw: raw ?? const <String, dynamic>{},
      );
    }

    if (DeepLinks.isBudgetLink(uri)) {
      return NotificationIntent(
        action: NotificationIntentAction.openBudgetStatus,
        args: <String, dynamic>{'budget_id': uri.pathSegments.first},
        raw: raw ?? const <String, dynamic>{},
      );
    }

    if (DeepLinks.isSplitLink(uri)) {
      return NotificationIntent(
        action: NotificationIntentAction.openExpenseSheet,
        args: <String, dynamic>{'split_id': uri.pathSegments.first},
        raw: raw ?? const <String, dynamic>{},
      );
    }

    if (DeepLinks.isRecurringLink(uri)) {
      return NotificationIntent(
        action: NotificationIntentAction.openRecurringEditor,
        args: <String, dynamic>{'recurring_id': uri.pathSegments.first},
        raw: raw ?? const <String, dynamic>{},
      );
    }

    if (DeepLinks.isLogExpenseLink(uri)) {
      return const NotificationIntent(
        action: NotificationIntentAction.openLogExpenseQuickEntry,
      );
    }

    if (DeepLinks.isHouseholdLink(uri)) {
      final householdId = uri.pathSegments.first;
      final subRoute = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
      if (subRoute == 'settings' && uri.queryParameters['tab'] == '2') {
        return NotificationIntent(
          action: NotificationIntentAction.openHouseholdInvites,
          args: <String, dynamic>{'household_id': householdId},
          raw: raw ?? const <String, dynamic>{},
        );
      }

      return NotificationIntent(
        action: NotificationIntentAction.openHouseholdDashboard,
        args: <String, dynamic>{
          'household_id': householdId,
          if (subRoute != null) 'sub_route': subRoute,
        },
        raw: raw ?? const <String, dynamic>{},
      );
    }

    return null;
  }

  NotificationIntent fromData(Map<String, dynamic> data) {
    final normalized = _normalizeMap(data);
    final eventType = normalized['event_type']?.toString();
    final notificationId = normalized['notification_id']?.toString() ??
        normalized['event_id']?.toString();

    final deepLink = normalized['deep_link']?.toString();
    if (deepLink != null && deepLink.isNotEmpty) {
      final uri = Uri.tryParse(deepLink);
      if (uri != null) {
        final deepLinkIntent = fromUri(uri, raw: normalized);
        if (deepLinkIntent != null &&
            eventType != 'invite_reminder_inviter' &&
            eventType != 'settlement_completed' &&
            eventType != 'split_settled' &&
            eventType != 'log_expense_reminder' &&
            eventType != 'recurring_reminder') {
          return deepLinkIntent.copyWith(
            eventType: eventType,
            notificationId: notificationId,
            raw: normalized,
          );
        }
      }
    }

    final args = <String, dynamic>{
      if (_readId(normalized, 'household_id') != null)
        'household_id': _readId(normalized, 'household_id'),
      if (_readId(normalized, 'expense_id') != null)
        'expense_id': _readId(normalized, 'expense_id'),
      if (_readId(normalized, 'budget_id') != null)
        'budget_id': _readId(normalized, 'budget_id'),
      if (_readId(normalized, 'split_id') != null)
        'split_id': _readId(normalized, 'split_id'),
      if (_readId(normalized, 'split_group_id') != null)
        'split_group_id': _readId(normalized, 'split_group_id'),
      if (_readId(normalized, 'invite_token') != null)
        'invite_token': _readId(normalized, 'invite_token'),
      if (_readId(normalized, 'sender_name') != null)
        'toast_message': _readId(normalized, 'sender_name'),
      if (_readId(normalized, 'type') != null)
        'recurring_type': _readId(normalized, 'type'),
      ..._pickBudgetNumbers(normalized),
    };

    switch (eventType) {
      case 'expense_added':
      case 'expense_edited':
      case 'income_added':
      case 'income_edited':
        return NotificationIntent(
          action: NotificationIntentAction.openExpenseSheet,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
      case 'split_created':
        return NotificationIntent(
          action: NotificationIntentAction.openExpenseSheet,
          eventType: eventType,
          notificationId: notificationId,
          args: <String, dynamic>{
            ...args,
            if (!args.containsKey('split_group_id') && args['split_id'] != null)
              'split_group_id': args['split_id'],
          },
          raw: normalized,
        );
      case 'expense_deleted':
        return NotificationIntent(
          action: NotificationIntentAction.openHouseholdDashboard,
          eventType: eventType,
          notificationId: notificationId,
          args: <String, dynamic>{
            ...args,
            'toast_message': 'Expense was deleted',
          },
          raw: normalized,
        );
      case 'budget_warn':
      case 'budget_alert':
        return NotificationIntent(
          action: NotificationIntentAction.openBudgetStatus,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
      case 'split_settled':
      case 'settlement_completed':
        return NotificationIntent(
          action: NotificationIntentAction.openSettlementHistory,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
      case 'invite_reminder_inviter':
        return NotificationIntent(
          action: NotificationIntentAction.openHouseholdInvites,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
      case 'invite_reminder_invitee':
        return NotificationIntent(
          action: NotificationIntentAction.openHouseholdInviteAcceptance,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
      case 'recurring_reminder':
        return NotificationIntent(
          action: NotificationIntentAction.openRecurringEditor,
          eventType: eventType,
          notificationId: notificationId,
          args: <String, dynamic>{
            ...args,
            if (!args.containsKey('recurring_id') && args['expense_id'] != null)
              'recurring_id': args['expense_id'],
          },
          raw: normalized,
        );
      case 'log_expense_reminder':
        return NotificationIntent(
          action: NotificationIntentAction.openLogExpenseQuickEntry,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
      case 'invite_accepted':
      case 'member_joined':
      case 'member_left':
      case 'member_removed':
      case 'member_reminded':
        return NotificationIntent(
          action: NotificationIntentAction.openHouseholdDashboard,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
      default:
        return NotificationIntent(
          action: NotificationIntentAction.unknown,
          eventType: eventType,
          notificationId: notificationId,
          args: args,
          raw: normalized,
        );
    }
  }

  bool isSupportedEvent(String? eventType) {
    return householdNotificationSupportedEvents.contains(eventType);
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> source) {
    final normalized = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = entry.key;
      final value = entry.value;
      normalized[key] = _decodeNested(value);
    }
    return normalized;
  }

  dynamic _decodeNested(dynamic value) {
    if (value is! String) {
      return value;
    }

    final trimmed = value.trim();
    if (!(trimmed.startsWith('{') && trimmed.endsWith('}')) &&
        !(trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return value;
    }

    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }

  String? _readId(Map<String, dynamic> source, String key) {
    final value = source[key]?.toString();
    if (value == null || value.isEmpty || value == 'null') {
      return null;
    }
    return value;
  }

  Map<String, dynamic> _pickBudgetNumbers(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final key in <String>[
      'spent_cents',
      'budget_cents',
      'percentage_used',
      'budget_name',
      'currency',
      'household_name',
    ]) {
      final value = source[key];
      if (value != null && value.toString().isNotEmpty) {
        result[key] = value.toString();
      }
    }
    return result;
  }

  String? _extractInviteToken(Uri uri) {
    if (uri.scheme == DeepLinks.appScheme) {
      return uri.queryParameters['token'];
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'invites') {
      return uri.pathSegments[1];
    }
    return null;
  }
}
