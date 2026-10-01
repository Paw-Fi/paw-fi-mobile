import 'package:moneko/core/utils/user_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

bool _timezonesInitialized = false;

DateTime walletTransferWallNow({String? preferredTimezone, DateTime? at}) {
  final instant = at ?? DateTime.now();
  final zone = preferredTimezone?.trim() ?? '';
  final offset = tryParseTimezoneOffsetMinutes(zone);
  if (offset != null) {
    return instant.toUtc().add(Duration(minutes: offset));
  }
  if (zone.isNotEmpty) {
    if (!_timezonesInitialized) {
      timezone_data.initializeTimeZones();
      _timezonesInitialized = true;
    }
    final location = timezone.timeZoneDatabase.locations[zone];
    if (location != null) return timezone.TZDateTime.from(instant, location);
  }
  return instant.toLocal();
}
