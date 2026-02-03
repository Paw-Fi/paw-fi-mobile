/// Converts any DateTime to the device's local timezone
/// Always returns a DateTime in local time regardless of input timezone
DateTime toLocalTime(DateTime dateTime) {
  return dateTime.toLocal();
}

DateTime combineLocalDateWithLocalTime({
  required DateTime date,
  required DateTime timeSource,
}) {
  final localDate = date.toLocal();
  final localTime = timeSource.toLocal();
  return DateTime(
    localDate.year,
    localDate.month,
    localDate.day,
    localTime.hour,
    localTime.minute,
    localTime.second,
    localTime.millisecond,
    localTime.microsecond,
  );
}
