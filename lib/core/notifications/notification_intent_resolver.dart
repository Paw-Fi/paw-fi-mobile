import 'package:moneko/core/notifications/notification_intent.dart';
import 'package:moneko/core/resources/lib/supabase.dart';

class NotificationIntentResolver {
  NotificationIntentResolver({
    Future<String?> Function(String splitGroupId)? lookupExpenseIdBySplitGroup,
  }) : _lookupExpenseIdBySplitGroup = lookupExpenseIdBySplitGroup;

  final Future<String?> Function(String splitGroupId)?
      _lookupExpenseIdBySplitGroup;

  Future<NotificationIntent> resolve(NotificationIntent intent) async {
    if (intent.action != NotificationIntentAction.openExpenseSheet) {
      return intent;
    }

    if (intent.expenseId != null && intent.expenseId!.isNotEmpty) {
      return intent;
    }

    final splitGroupId = intent.splitGroupId;
    if (splitGroupId != null && splitGroupId.isNotEmpty) {
      final expenseId = await _resolveExpenseIdBySplitGroup(splitGroupId);
      if (expenseId != null) {
        return intent.copyWith(
          args: <String, dynamic>{
            ...intent.args,
            'expense_id': expenseId,
          },
        );
      }
    }

    return intent;
  }

  Future<String?> _resolveExpenseIdBySplitGroup(String splitGroupId) async {
    if (_lookupExpenseIdBySplitGroup != null) {
      return _lookupExpenseIdBySplitGroup!(splitGroupId);
    }

    try {
      final response = await supabase
          .from('expense_split_groups')
          .select('expense_id')
          .eq('id', splitGroupId)
          .maybeSingle();

      final expenseId = response?['expense_id']?.toString();
      if (expenseId == null || expenseId.isEmpty) {
        return null;
      }
      return expenseId;
    } catch (_) {
      return null;
    }
  }
}
