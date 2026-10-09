import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/theme/widget_text_styles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform has a real rounded fallback, preserving amount styling',
        () {
      const base = TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.1,
      );
      final style = WidgetTextStyles.roundedNumber(
        ThemeData(platform: platform),
        baseStyle: base,
      );
      expect(style.fontFamily, 'Nunito');
      expect(style.fontSize, base.fontSize);
      expect(style.fontWeight, base.fontWeight);
      expect(style.letterSpacing, base.letterSpacing);
      expect(style.height, base.height);
      expect(style.fontVariations!.single.value, 800);
    });
  }

  test('Nunito is bundled, registered, and licensed for offline rendering', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Nunito'));
    expect(pubspec, contains('asset: lib/assets/fonts/Nunito.ttf'));
    final bytes = File('lib/assets/fonts/Nunito.ttf').readAsBytesSync();
    expect(bytes.take(4), [0, 1, 0, 0]);
    expect(File('lib/assets/fonts/OFL.txt').readAsStringSync(),
        contains('SIL OPEN FONT LICENSE'));
  });

  test('iOS loads native rounded faces before choosing their Flutter family',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('moneko/rounded_font');
    var calls = 0;
    final font = File('lib/assets/fonts/Nunito.ttf').readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'loadRoundedFonts');
      calls++;
      return {
        '700': {
          'data': font,
          'variations': {'wght': 700.0},
        },
        '800': {
          'data': font,
          'variations': {'wght': 800.0},
        },
      };
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await WidgetTextStyles.initializeRoundedNumbers();
    for (final weight in [FontWeight.w700, FontWeight.w800]) {
      final style = WidgetTextStyles.roundedNumber(
        ThemeData(platform: TargetPlatform.iOS),
        baseStyle: TextStyle(fontWeight: weight),
      );
      expect(style.fontFamily, 'MonekoSFRounded${weight.value}');
      expect(style.fontFamilyFallback, contains('Nunito'));
      expect(style.fontVariations!.single.value, weight.value);
    }
    expect(calls, 1);
    expect(
      WidgetTextStyles.roundedNumber(
              ThemeData(platform: TargetPlatform.android))
          .fontFamily,
      'Nunito',
    );
  });

  test('Android never requests an Apple system font', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('moneko/rounded_font');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      fail('Android must use the bundled rounded font');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await WidgetTextStyles.initializeRoundedNumbers();
  });

  test(
      'unavailable native fonts do not prevent launch or lose rounded fallback',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const channel = MethodChannel('moneko/rounded_font');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await WidgetTextStyles.initializeRoundedNumbers();
    expect(
      WidgetTextStyles.roundedNumber(ThemeData(platform: TargetPlatform.iOS))
          .fontFamily,
      'Nunito',
    );
  });

  test('font asset appears in Flutter FontManifest', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    expect(
        manifest.any((dynamic entry) => entry['family'] == 'Nunito'), isTrue);
    await rootBundle.load('lib/assets/fonts/Nunito.ttf');
  });
}
