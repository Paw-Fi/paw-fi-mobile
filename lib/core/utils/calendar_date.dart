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
  final ymdPrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
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

String formatDateOnlyYmd(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
