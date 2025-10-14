/// Converts any DateTime to the device's local timezone
/// Always returns a DateTime in local time regardless of input timezone
DateTime toLocalTime(DateTime dateTime) {
  return dateTime.toLocal();
}
