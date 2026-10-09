import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';

Future<Uint8List> _numberPixels(TextStyle style) async {
  final recorder = ui.PictureRecorder();
  final painter = TextPainter(
    text: TextSpan(text: '0123456789.,-%', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(Canvas(recorder), Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 80);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  painter.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS renders actual SF Rounded instead of the Nunito fallback',
      (tester) async {
    await WidgetTextStyles.initializeRoundedNumbers();
    const base = TextStyle(fontSize: 40, fontWeight: FontWeight.w700);
    final native = WidgetTextStyles.roundedNumber(
      ThemeData(platform: TargetPlatform.iOS),
      baseStyle: base,
    );
    expect(native.fontFamily, 'MonekoSFRounded700');

    final fallback = WidgetTextStyles.roundedNumber(
      ThemeData(platform: TargetPlatform.android),
      baseStyle: base,
    );
    expect(fallback.fontFamily, 'Nunito');
    // If Flutter rejects the native font bytes, both styles render Nunito.
    final nativePixels = await _numberPixels(native);
    final fallbackPixels = await _numberPixels(fallback);
    expect(nativePixels.any((value) => value != 0), isTrue);
    expect(listEquals(nativePixels, fallbackPixels), isFalse);
  });
}
