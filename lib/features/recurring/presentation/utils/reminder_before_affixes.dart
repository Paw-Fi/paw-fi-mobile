class ReminderBeforeAffixes {
  final String prefix;
  final String suffix;

  const ReminderBeforeAffixes({
    required this.prefix,
    required this.suffix,
  });
}

ReminderBeforeAffixes resolveReminderBeforeAffixes({
  required String before,
  required String beforePrefix,
  required String beforeSuffix,
}) {
  final explicitPrefix = beforePrefix.trim();
  final explicitSuffix = beforeSuffix.trim();

  // Prefer explicit affixes from localization files.
  if (explicitPrefix.isNotEmpty || explicitSuffix.isNotEmpty) {
    return ReminderBeforeAffixes(
      prefix: explicitPrefix,
      suffix: explicitSuffix,
    );
  }

  // Fallback for locales still encoding affixes as "prefix...suffix".
  final rawBefore = before.trim();
  if (rawBefore.isEmpty) {
    return const ReminderBeforeAffixes(prefix: '', suffix: '');
  }

  const marker = '...';
  if (rawBefore.contains(marker)) {
    final markerIndex = rawBefore.indexOf(marker);
    return ReminderBeforeAffixes(
      prefix: rawBefore.substring(0, markerIndex).trim(),
      suffix: rawBefore.substring(markerIndex + marker.length).trim(),
    );
  }

  return ReminderBeforeAffixes(prefix: rawBefore, suffix: '');
}
