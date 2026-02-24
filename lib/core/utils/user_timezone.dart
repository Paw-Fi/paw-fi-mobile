int? tryParseTimezoneOffsetMinutes(String timezone) {
  if (timezone == 'UTC' || timezone == 'GMT') return 0;

  final match =
      RegExp(r'^(?:UTC|GMT)?([+-])(\d{2}):(\d{2})$').firstMatch(timezone);
  if (match == null) return null;

  final sign = match.group(1) == '-' ? -1 : 1;
  final hours = int.parse(match.group(2)!);
  final minutes = int.parse(match.group(3)!);
  return sign * (hours * 60 + minutes);
}

DateTime? tryParseDateOnlyYmd(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

DateTime? parseCalendarDateFromFlexibleInput(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  // Calendar-day values are often serialized as full ISO timestamps (sometimes
  // in UTC at midnight). For calendar semantics we must not apply timezone
  // conversion (which can shift the day). Instead, prefer extracting the
  // YYYY-MM-DD prefix when present.
  final ymdPrefix =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
  if (ymdPrefix != null) {
    final year = int.parse(ymdPrefix.group(1)!);
    final month = int.parse(ymdPrefix.group(2)!);
    final day = int.parse(ymdPrefix.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return null;

  // As a fallback, keep the calendar day as expressed by the parsed value
  // without shifting it through `toLocal()`.
  return DateTime(parsed.year, parsed.month, parsed.day);
}
int resolveUserTimezoneOffsetMinutes(
  String? preferredTimezone, {
  int? fallbackOffsetMinutes,
  DateTime? at,
}) {
  final deviceOffsetMinutes =
      (at ?? DateTime.now()).toLocal().timeZoneOffset.inMinutes;
  final trimmed = preferredTimezone?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallbackOffsetMinutes ?? deviceOffsetMinutes;
  }

  final parsed = tryParseTimezoneOffsetMinutes(trimmed);
  if (parsed != null) return parsed;

  return fallbackOffsetMinutes ?? deviceOffsetMinutes;
}

int effectiveOffsetMinutes({required String? preferredTimezone, DateTime? at}) {
  final parsed = tryParseTimezoneOffsetMinutes(preferredTimezone?.trim() ?? '');
  if (parsed != null) return parsed;
  return (at ?? DateTime.now()).toLocal().timeZoneOffset.inMinutes;
}

DateTime effectiveNow({required String? preferredTimezone}) {
  final parsed = tryParseTimezoneOffsetMinutes(preferredTimezone?.trim() ?? '');
  if (parsed == null) return DateTime.now().toLocal();
  return DateTime.now().toUtc().add(Duration(minutes: parsed));
}

DateTime effectiveToday({required String? preferredTimezone}) {
  final now = effectiveNow(preferredTimezone: preferredTimezone);
  return DateTime(now.year, now.month, now.day);
}

DateTime toEffectiveWallTime({
  required DateTime utcOrLocalInstant,
  required String? preferredTimezone,
}) {
  final parsed = tryParseTimezoneOffsetMinutes(preferredTimezone?.trim() ?? '');
  final utc =
      utcOrLocalInstant.isUtc ? utcOrLocalInstant : utcOrLocalInstant.toUtc();
  if (parsed == null) return utc.toLocal();
  return utc.add(Duration(minutes: parsed));
}

DateTime utcInstantFromEffectiveLocalDateTime({
  required DateTime localDateTimeWall,
  required String? preferredTimezone,
}) {
  final parsed = tryParseTimezoneOffsetMinutes(preferredTimezone?.trim() ?? '');
  if (parsed == null) return localDateTimeWall.toUtc();
  return utcInstantForUserLocalDateTime(
    localDateTime: localDateTimeWall,
    offsetMinutes: parsed,
  );
}

DateTime userNowFromOffsetMinutes(int offsetMinutes) {
  return DateTime.now().toUtc().add(Duration(minutes: offsetMinutes));
}

DateTime userTodayFromOffsetMinutes(int offsetMinutes) {
  final wallNow = userNowFromOffsetMinutes(offsetMinutes);
  return DateTime(wallNow.year, wallNow.month, wallNow.day);
}

DateTime utcInstantForUserLocalMidnight({
  required DateTime localDate,
  required int offsetMinutes,
}) {
  return DateTime.utc(localDate.year, localDate.month, localDate.day)
      .subtract(Duration(minutes: offsetMinutes));
}

DateTime utcInstantForUserLocalDateTime({
  required DateTime localDateTime,
  required int offsetMinutes,
}) {
  return DateTime.utc(
    localDateTime.year,
    localDateTime.month,
    localDateTime.day,
    localDateTime.hour,
    localDateTime.minute,
    localDateTime.second,
    localDateTime.millisecond,
    localDateTime.microsecond,
  ).subtract(Duration(minutes: offsetMinutes));
}

DateTime toUserWallTime({
  required DateTime dateTime,
  required int offsetMinutes,
}) {
  final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
  return utc.add(Duration(minutes: offsetMinutes));
}

DateTime combineUserDateWithUserTime({
  required DateTime date,
  required DateTime timeSource,
  required int offsetMinutes,
}) {
  final userDate = toUserWallTime(dateTime: date, offsetMinutes: offsetMinutes);
  final userTime =
      toUserWallTime(dateTime: timeSource, offsetMinutes: offsetMinutes);
  return DateTime(
    userDate.year,
    userDate.month,
    userDate.day,
    userTime.hour,
    userTime.minute,
    userTime.second,
    userTime.millisecond,
    userTime.microsecond,
  );
}

String formatDateOnlyYmd(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
