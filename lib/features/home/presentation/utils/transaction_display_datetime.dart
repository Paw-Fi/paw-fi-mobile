import 'package:moneko/core/utils/user_timezone.dart';

DateTime composeTransactionDisplayDateTime({
  required DateTime transactionDate,
  required DateTime createdAt,
  required String? preferredTimezone,
}) {
  final createdAtWall = toEffectiveWallTime(
    utcOrLocalInstant: createdAt,
    preferredTimezone: preferredTimezone,
  );

  return DateTime(
    transactionDate.year,
    transactionDate.month,
    transactionDate.day,
    createdAtWall.hour,
    createdAtWall.minute,
    createdAtWall.second,
    createdAtWall.millisecond,
    createdAtWall.microsecond,
  );
}
