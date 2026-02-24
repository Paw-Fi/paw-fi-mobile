import 'package:hooks_riverpod/hooks_riverpod.dart';

class RecurringPageCommand {
  const RecurringPageCommand({
    required this.recurringId,
    this.recurringType,
    this.requestId = 0,
  });

  final String recurringId;
  final String? recurringType;
  final int requestId;
}

final recurringPageCommandProvider =
    StateProvider<RecurringPageCommand?>((ref) => null);
