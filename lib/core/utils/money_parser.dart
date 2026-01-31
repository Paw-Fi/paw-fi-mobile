/// Money parsing utilities for user-entered amounts.
///
/// We intentionally avoid `double.parse` for persistence/validation because
/// floating point can introduce rounding errors (e.g. extra cents).
///
/// This parser accepts common user input formats:
/// - "1234"
/// - "1,234"
/// - "1234.56"
/// - "1,234.56"
/// - "1234,56" (comma decimal)
/// - with optional leading currency symbol (ignored)
int? tryParseMoneyToCents(String input) {
  var raw = input.trim();
  if (raw.isEmpty) return null;

  // Keep leading sign, but strip everything else that's not a digit or separator.
  var sign = 1;
  if (raw.startsWith('-')) {
    sign = -1;
    raw = raw.substring(1);
  } else if (raw.startsWith('+')) {
    raw = raw.substring(1);
  }

  raw = raw.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^0-9,\.]'), '');
  if (raw.isEmpty) return null;

  final lastDot = raw.lastIndexOf('.');
  final lastComma = raw.lastIndexOf(',');

  String normalized;
  if (lastDot != -1 && lastComma != -1) {
    // Both present: treat the last one as decimal separator.
    if (lastDot > lastComma) {
      // Dot decimals: remove commas.
      normalized = raw.replaceAll(',', '');
    } else {
      // Comma decimals: remove dots, replace comma with dot.
      normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (lastComma != -1) {
    // Only comma present: decide if it's decimal or thousands.
    final digitsAfter = raw.length - lastComma - 1;
    if (digitsAfter >= 1 && digitsAfter <= 2 && raw.indexOf(',') == lastComma) {
      normalized = raw.replaceAll(',', '.');
    } else {
      normalized = raw.replaceAll(',', '');
    }
  } else {
    // Dot only or none.
    normalized = raw;
  }

  final parts = normalized.split('.');
  if (parts.length > 2) return null;

  final wholePart = parts[0].isEmpty ? '0' : parts[0];
  final fracPart = parts.length == 2 ? parts[1] : '';

  final whole = int.tryParse(wholePart);
  if (whole == null) return null;

  int cents = whole.abs() * 100;

  if (fracPart.isNotEmpty) {
    final digits = fracPart.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      // nothing
    } else if (digits.length == 1) {
      cents += int.parse(digits) * 10;
    } else {
      cents += int.parse(digits.substring(0, 2));
      if (digits.length > 2) {
        final third = int.parse(digits[2]);
        if (third >= 5) {
          cents += 1;
        }
      }
    }
  }

  return sign * cents;
}

double centsToAmount(int cents) => cents / 100.0;
