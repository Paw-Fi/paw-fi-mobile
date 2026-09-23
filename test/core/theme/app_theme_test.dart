import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'moneko_theme_mode': 'dark',
    });
  });

  test('persists theme mode for the next notifier instance', () async {
    final notifier = ThemeModeNotifier();

    await notifier.setThemeMode(ThemeMode.light);

    final restartedNotifier = ThemeModeNotifier();
    await Future<void>.delayed(Duration.zero);

    expect(restartedNotifier.state, ThemeMode.light);
  });

  test('uses the saved theme before the first frame', () async {
    final preferences = await SharedPreferences.getInstance();
    final notifier = ThemeModeNotifier(preferences: preferences);

    expect(notifier.state, ThemeMode.dark);

    await notifier.setThemeMode(ThemeMode.light);

    expect(preferences.getString('moneko_theme_mode'), 'light');
  });

  test('startup load cannot overwrite a newer selection', () async {
    final notifier = ThemeModeNotifier();

    await notifier.setThemeMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state, ThemeMode.light);
  });
}
