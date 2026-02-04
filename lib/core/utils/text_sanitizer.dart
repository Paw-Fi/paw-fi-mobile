String sanitizeUtf16(String input) {
  if (input.isEmpty) return input;

  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final unit = input.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 < input.length) {
        final next = input.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer.writeCharCode(unit);
          buffer.writeCharCode(next);
          i++;
          continue;
        }
      }
      buffer.write('\uFFFD');
      continue;
    }

    if (unit >= 0xDC00 && unit <= 0xDFFF) {
      buffer.write('\uFFFD');
      continue;
    }

    buffer.writeCharCode(unit);
  }

  return buffer.toString();
}
