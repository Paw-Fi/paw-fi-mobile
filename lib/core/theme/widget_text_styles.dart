import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared text styling constants matching CategoryBreakdownChart.tsx web component
class WidgetTextStyles {
  static const _roundedFontChannel = MethodChannel('moneko/rounded_font');
  static final _iosFontVariations = <int, List<FontVariation>>{};

  /// Load the device's SF Rounded faces, not guessed hidden font-family names.
  /// Apple fonts stay on the device; only Nunito is distributed with the app.
  static Future<void> initializeRoundedNumbers() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final faces = await _roundedFontChannel
          .invokeMapMethod<String, dynamic>('loadRoundedFonts')
          .timeout(const Duration(seconds: 10));
      if (faces == null) return;
      for (final entry in faces.entries) {
        final weight = int.parse(entry.key);
        final face = Map<String, dynamic>.from(entry.value as Map);
        final loader = FontLoader('MonekoSFRounded$weight')
          ..addFont(
              Future.value(ByteData.sublistView(face['data'] as Uint8List)));
        await loader.load();
        final variations = Map<String, dynamic>.from(face['variations'] as Map);
        _iosFontVariations[weight] = [
          for (final axis in variations.entries)
            FontVariation(axis.key, (axis.value as num).toDouble()),
        ];
      }
    } catch (error) {
      // Font failure must not prevent launch. Nunito remains a rounded fallback.
      debugPrint('SF Rounded initialization failed: $error');
    }
  }

  static TextStyle roundedNumber(
    ThemeData theme, {
    TextStyle? baseStyle,
  }) {
    final base = baseStyle ?? const TextStyle();
    final weight = (base.fontWeight ?? FontWeight.w400).value;
    final iosVariations = theme.platform == TargetPlatform.iOS
        ? _iosFontVariations[weight]
        : null;
    return base.copyWith(
      fontFamily: iosVariations == null ? 'Nunito' : 'MonekoSFRounded$weight',
      fontFamilyFallback: const ['Nunito'],
      fontVariations:
          iosVariations ?? [FontVariation('wght', weight.toDouble())],
    );
  }

  // Primary title style (matches web h1)
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  // Date range subtitle style (matches web p tag)
  static const TextStyle subtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  // Primary amount style (compact, matching web financial amounts)
  static const TextStyle amount = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  // Category name style
  static const TextStyle category = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  // Category amount style
  static const TextStyle categoryAmount = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // Date range label style (non-uppercase)
  static TextStyle dateLabel(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        color: color,
      );
}
