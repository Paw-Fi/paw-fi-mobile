import 'package:flutter/material.dart';

class MonekoRichText extends StatelessWidget {
  const MonekoRichText({
    super.key,
    required this.text,
    this.style,
    this.highlightStyle,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = style ?? theme.textTheme.bodyMedium;
    final accentStyle = highlightStyle ??
        defaultStyle?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        );

    final List<TextSpan> spans = [];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    final matches = regex.allMatches(text);
    for (final match in matches) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: defaultStyle,
        ));
      }

      // Add the highlighted text (without the markers)
      spans.add(TextSpan(
        text: match.group(1),
        style: accentStyle,
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
    );
  }
}
