enum NotificationIntentAction {
  openExpenseSheet,
  openBudgetStatus,
  openHouseholdDashboard,
  openHouseholdInvites,
  openSettlementHistory,
  openRecurringEditor,
  openRecurringPage,
  openLogExpenseQuickEntry,
  openPocketsPage,
  openInsightsPage,
  openHouseholdInviteAcceptance,
  unknown,
}

class NotificationIntent {
  const NotificationIntent({
    required this.action,
    this.eventType,
    this.notificationId,
    this.args = const <String, dynamic>{},
    this.raw = const <String, dynamic>{},
  });

  final NotificationIntentAction action;
  final String? eventType;
  final String? notificationId;
  final Map<String, dynamic> args;
  final Map<String, dynamic> raw;

  String? get householdId => args['household_id'] as String?;
  String? get expenseId => args['expense_id'] as String?;
  String? get budgetId => args['budget_id'] as String?;
  String? get splitId => args['split_id'] as String?;
  String? get splitGroupId => args['split_group_id'] as String?;
  String? get recurringId => args['recurring_id'] as String?;
  String? get recurringType => args['recurring_type'] as String?;
  String? get inviteToken => args['invite_token'] as String?;
  String? get toastMessage => args['toast_message'] as String?;

  String? get dedupeId {
    if (notificationId != null && notificationId!.isNotEmpty) {
      return notificationId;
    }
    final eventId = raw['event_id']?.toString();
    if (eventId != null && eventId.isNotEmpty) {
      return eventId;
    }
    return null;
  }

  bool get requiresAuth =>
      action != NotificationIntentAction.openHouseholdInviteAcceptance;

  NotificationIntent copyWith({
    NotificationIntentAction? action,
    String? eventType,
    String? notificationId,
    Map<String, dynamic>? args,
    Map<String, dynamic>? raw,
  }) {
    return NotificationIntent(
      action: action ?? this.action,
      eventType: eventType ?? this.eventType,
      notificationId: notificationId ?? this.notificationId,
      args: args ?? this.args,
      raw: raw ?? this.raw,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'action': action.name,
      'event_type': eventType,
      'notification_id': notificationId,
      'args': args,
      'raw': raw,
    };
  }

  static NotificationIntent fromJson(Map<String, dynamic> json) {
    final actionName = json['action']?.toString() ?? 'unknown';
    final action = NotificationIntentAction.values.firstWhere(
      (value) => value.name == actionName,
      orElse: () => NotificationIntentAction.unknown,
    );

    return NotificationIntent(
      action: action,
      eventType: json['event_type']?.toString(),
      notificationId: json['notification_id']?.toString(),
      args: (json['args'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      raw: (json['raw'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}
