import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moneko/features/home/presentation/widgets/hold_recording_indicator.dart';
import 'package:moneko/l10n/app_localizations.dart';

void main() {
  group('normalizeHoldRecordingLevel', () {
    test('keeps silence at the minimum bar height', () {
      expect(normalizeHoldRecordingLevel(-160), holdRecordingMinimumLevel);
      expect(
        normalizeHoldRecordingLevel(holdRecordingSilenceFloorDb),
        holdRecordingMinimumLevel,
      );
      expect(
          normalizeHoldRecordingLevel(double.nan), holdRecordingMinimumLevel);
    });

    test('fills the bar for loud input and grows monotonically', () {
      expect(normalizeHoldRecordingLevel(0), 1);
      expect(normalizeHoldRecordingLevel(holdRecordingLoudCeilingDb), 1);
      final quiet = normalizeHoldRecordingLevel(-40);
      final speech = normalizeHoldRecordingLevel(-25);
      expect(quiet, greaterThan(holdRecordingMinimumLevel));
      expect(speech, greaterThan(quiet));
      expect(speech, lessThan(1));
    });
  });

  test('smoothHoldRecordingLevel attacks faster than it releases', () {
    final rise = smoothHoldRecordingLevel(0.2, 1) - 0.2;
    final fall = 1 - smoothHoldRecordingLevel(1, 0.2);
    expect(rise, greaterThan(fall));
  });

  group('holdCancelProgress', () {
    test('counts only leftward drags and clamps to the threshold', () {
      expect(holdCancelProgress(40, 110), 0);
      expect(holdCancelProgress(0, 110), 0);
      expect(holdCancelProgress(-55, 110), closeTo(0.5, 1e-9));
      expect(holdCancelProgress(-110, 110), 1);
      expect(holdCancelProgress(-400, 110), 1);
      expect(holdCancelProgress(-10, 0), 0);
    });
  });

  group('holdDragVisualOffset', () {
    test('tracks leftward drags 1:1 up to the threshold', () {
      expect(holdDragVisualOffset(-40, 110), -40);
      expect(holdDragVisualOffset(-300, 110), -110);
    });

    test('rubber-bands rightward drags to a small bounded offset', () {
      final small = holdDragVisualOffset(20, 110);
      final large = holdDragVisualOffset(400, 110);
      expect(small, greaterThan(0));
      expect(small, lessThan(20));
      expect(large, greaterThan(small));
      expect(large, lessThanOrEqualTo(10));
    });
  });

  testWidgets('HoldRecordingVoiceHalo follows the latest level',
      (tester) async {
    final levels = HoldRecordingLevels();
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: HoldRecordingVoiceHalo(
          levels: levels,
          isActive: true,
          cancelProgress: 0,
        ),
      ),
    ));
    double outerScale() => tester
        .widgetList<AnimatedScale>(find.byType(AnimatedScale))
        .first
        .scale;
    final quietScale = outerScale();

    levels.addDecibels(-10);
    await tester.pump();
    expect(outerScale(), greaterThan(quietScale));

    await tester.pumpWidget(const SizedBox.shrink());
    levels.dispose();
  });

  test('HoldRecordingLevels keeps a bounded rolling window', () {
    final levels = HoldRecordingLevels(capacity: 3);
    var notifications = 0;
    levels.addListener(() => notifications++);

    for (final db in [-60.0, -30.0, -20.0, -10.0]) {
      levels.addDecibels(db);
    }

    expect(levels.levels, hasLength(3));
    expect(levels.levels.last, greaterThan(levels.levels.first));
    expect(notifications, 4);

    levels.clear();
    expect(levels.levels, isEmpty);
    levels.dispose();
  });

  group('HoldRecordingIndicator', () {
    Widget harness({
      required bool isRecording,
      required bool isCancelled,
      double cancelProgress = 0,
      required HoldRecordingLevels levels,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: HoldRecordingIndicator(
              isVisible: true,
              isRecording: isRecording,
              isCancelled: isCancelled,
              cancelProgress: cancelProgress,
              levels: levels,
              startedAt: DateTime.now(),
              width: 300,
            ),
          ),
        ),
      );
    }

    testWidgets('shows timer and slide hint while recording', (tester) async {
      final levels = HoldRecordingLevels()..addDecibels(-20);
      await tester.pumpWidget(
        harness(isRecording: true, isCancelled: false, levels: levels),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Slide to cancel'), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

      await tester.pumpWidget(harness(
        isRecording: true,
        isCancelled: false,
        cancelProgress: 0.6,
        levels: levels,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      levels.dispose();
    });

    testWidgets('swaps to the cancelled state after a cancel commit',
        (tester) async {
      final levels = HoldRecordingLevels();
      await tester.pumpWidget(
        harness(isRecording: false, isCancelled: true, levels: levels),
      );
      await tester.pumpAndSettle();

      expect(find.text('Canceled'), findsOneWidget);
      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
      expect(find.text('Slide to cancel'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      levels.dispose();
    });
  });
}
