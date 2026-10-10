import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/widgets/dashboard_budget_header.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/l10n/app_localizations.dart';

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Locale locale = const Locale('en'),
  String currency = 'USD',
  bool dark = false,
  HomePeriodMode mode = HomePeriodMode.monthly,
  AsyncValue<BudgetCompanionSummary> summary = const AsyncData(
    BudgetCompanionSummary(spent: 400, budget: 700),
  ),
  VoidCallback? onRetry,
  VoidCallback? onBudgetTap,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 1200),
        textScaler: TextScaler.linear(scale),
        disableAnimations: true,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: DashboardBudgetHeader(
            summary: summary,
            currency: currency,
            mode: mode,
            selectedDate: DateTime(2026, 10, 9),
            onBudgetTap: onBudgetTap ?? () {},
            onRetry: onRetry ?? () {},
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting());

  testWidgets('short caption stays inside the gauge above a standalone amount',
      (tester) async {
    await _pump(tester);
    final primary =
        find.byKey(const ValueKey('budget-companion-primary-amount'));
    final amount = tester.widget<Text>(primary);
    expect(amount.data, r'$300');
    expect(amount.textSpan, isNull);
    expect(amount.style!.fontSize, 34);
    expect(find.text('Spent'), findsNothing);
    final detail = find.byKey(const ValueKey('budget-companion-budget-amount'));
    expect(tester.widget<Text>(detail).semanticsLabel,
        r'Spent $400 / Budget $700');
    expect(find.text('57%'), findsNothing);
    expect(find.text('Oct · Remaining'), findsOneWidget);
    expect(find.text(r'$300 left'), findsNothing);
    final gauge = tester.getRect(find.byType(BudgetGaugeIndicator));
    final period = tester.getRect(find.text('Oct · Remaining'));
    expect(gauge.contains(period.topLeft), isTrue);
    expect(gauge.contains(period.bottomRight), isTrue);
    expect(
        tester.getRect(primary).center.dx,
        closeTo(
            tester.getRect(find.byType(DashboardBudgetHeader)).center.dx, .1));
    expect(tester.getTopLeft(primary).dy, greaterThan(gauge.bottom));
    expect(tester.getRect(detail).top - tester.getRect(primary).bottom,
        lessThanOrEqualTo(4));
    expect(tester.getSize(detail).height, lessThan(24));
  });

  for (final sample in [
    (const Locale('en'), 'IDR'),
    (const Locale('de'), 'EUR'),
    (const Locale('zh'), 'VND'),
    (const Locale('ur'), 'PKR'),
  ]) {
    for (final width in [280.0, 320.0]) {
      for (final scale in [1.0, 1.5, 2.0, 3.0]) {
        testWidgets(
            'exact ${sample.$2} amount at ${sample.$1} ${width}px ${scale}x',
            (tester) async {
          await _pump(tester,
              width: width,
              scale: scale,
              locale: sample.$1,
              currency: sample.$2,
              dark: scale >= 2,
              summary: const AsyncData(BudgetCompanionSummary(
                  spent: 123456789012.34, budget: 987654321098.76)));
          final context = tester.element(find.byType(DashboardBudgetHeader));
          final formatted = formatCurrency(
              987654321098.76 - 123456789012.34, sample.$2,
              context: context);
          final finder =
              find.byKey(const ValueKey('budget-companion-primary-amount'));
          expect(finder, findsOneWidget);
          final text = tester.widget<Text>(finder);
          expect(text.maxLines, isNull);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          expect(text.textScaler, isNull);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(text.data, formatted);
          expect(text.textSpan, isNull);
          expect(text.style!.fontSize, greaterThanOrEqualTo(28));
          expect(
              rect.center.dx,
              closeTo(
                  tester.getRect(find.byType(DashboardBudgetHeader)).center.dx,
                  .1));
          final bubble = tester
              .getRect(find.byKey(const ValueKey('budget-companion-bubble')));
          final image = tester.getRect(find.byType(Image));
          expect(bubble.overlaps(image), isFalse);
          expect(
              bubble.bottom,
              lessThan(
                  tester.getTopLeft(find.byType(BudgetGaugeIndicator)).dy));
          final l10n = AppLocalizations.of(context)!;
          expect(find.text(l10n.budgetCompanionLeft(formatted)), findsNothing);
          final spent =
              formatCurrency(123456789012.34, sample.$2, context: context);
          final budget =
              formatCurrency(987654321098.76, sample.$2, context: context);
          final detail = tester.widget<Text>(
              find.byKey(const ValueKey('budget-companion-budget-amount')));
          expect(detail.semanticsLabel,
              l10n.dashboardBudgetSpentAndLimit(spent, budget));
          expect(detail.data, contains(' /\n'));
          expect(detail.maxLines, isNull);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('uncached loading has no fake financial values', (tester) async {
    await _pump(tester, summary: const AsyncLoading());
    expect(find.byType(DashboardBudgetHeaderSkeleton), findsOneWidget);
    expect(find.text(r'$0'), findsNothing);
    expect(find.byKey(const ValueKey('budget-companion-primary-amount')),
        findsOneWidget);
  });

  testWidgets('cached refresh and failed refresh keep the real amount',
      (tester) async {
    const cached = AsyncData(BudgetCompanionSummary(spent: 400, budget: 700));
    for (final summary in [
      const AsyncLoading<BudgetCompanionSummary>().copyWithPrevious(cached),
      const AsyncError<BudgetCompanionSummary>('offline', StackTrace.empty)
          .copyWithPrevious(cached),
    ]) {
      await _pump(tester, summary: summary);
      expect(find.text(r'$300'), findsOneWidget);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('budget-companion-budget-amount')))
              .semanticsLabel,
          r'Spent $400 / Budget $700');
      expect(find.byType(DashboardBudgetHeaderSkeleton), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('missing budget keeps spending and budget setup reachable',
      (tester) async {
    var taps = 0;
    await _pump(tester,
        width: 280,
        scale: 3,
        summary: const AsyncData(BudgetCompanionSummary(spent: 400)),
        onBudgetTap: () => taps++);
    expect(find.text(r'$400'), findsOneWidget);
    expect(find.text('Oct · Spent'), findsOneWidget);
    expect(find.text('No budget set yet'), findsOneWidget);
    final action = find.text('Set Budget');
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected historical day stays accurate with large text',
      (tester) async {
    await _pump(tester,
        width: 280,
        scale: 3,
        mode: HomePeriodMode.daily,
        summary: const AsyncData(BudgetCompanionSummary(spent: 123456789.01)));
    expect(find.text('Oct 9, 2026 · Spent'), findsOneWidget);
    expect(find.text(r'$123,456,789.01'), findsOneWidget);
    expect(find.text('spent today'), findsNothing);
    expect(find.byType(BudgetGaugeIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large-text error can grow and retry remains reachable',
      (tester) async {
    var retries = 0;
    await _pump(tester,
        width: 280,
        scale: 3,
        locale: const Locale('de'),
        summary: const AsyncError('offline', StackTrace.empty),
        onRetry: () => retries++);
    final context = tester.element(find.byType(DashboardBudgetHeader));
    final retry = find.text(AppLocalizations.of(context)!.retry);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overspending replaces remaining with the exact excess',
      (tester) async {
    await _pump(tester,
        summary:
            const AsyncData(BudgetCompanionSummary(spent: 800, budget: 700)));
    expect(find.text(r'$100'), findsOneWidget);
    expect(find.text('Oct · Over budget'), findsOneWidget);
    expect(find.text('Oct · Remaining'), findsNothing);
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('budget-companion-budget-amount')))
            .semanticsLabel,
        r'Spent $800 / Budget $700');
    expect(find.text(r'$100 left'), findsNothing);
    expect(find.text('No budget set yet'), findsNothing);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
        '$locale keeps the main number centered without attached labels',
        (tester) async {
      await _pump(tester, locale: locale, width: 320, scale: 2);
      final primary =
          find.byKey(const ValueKey('budget-companion-primary-amount'));
      final text = tester.widget<Text>(primary);
      final context = tester.element(primary);
      expect(text.data, formatCurrency(300, 'USD', context: context));
      expect(text.textSpan, isNull);
      expect(text.textDirection, TextDirection.ltr);
      final header = tester.getRect(find.byType(DashboardBudgetHeader));
      expect(tester.getRect(primary).center.dx, closeTo(header.center.dx, .1));
      final caption =
          tester.getRect(find.byKey(const ValueKey('budget-companion-period')));
      final gaugeFinder = find.byType(BudgetGaugeIndicator);
      final gauge = tester.getRect(gaugeFinder);
      expect(gauge.contains(caption.topLeft), isTrue);
      expect(gauge.contains(caption.bottomRight), isTrue);
      final stroke =
          tester.widget<BudgetGaugeIndicator>(gaugeFinder).strokeWidth;
      final radiusX = (gauge.width - stroke) / 2 - stroke / 2 - 4;
      final radiusY = gauge.height - stroke - stroke / 2 - 4;
      final center = Offset(gauge.center.dx, gauge.bottom - stroke / 2);
      for (final corner in [
        caption.topLeft,
        caption.topRight,
        caption.bottomLeft,
        caption.bottomRight
      ]) {
        final x = (corner.dx - center.dx) / radiusX;
        final y = (corner.dy - center.dy) / radiusY;
        expect(x * x + y * y, lessThanOrEqualTo(1.01),
            reason: '$locale caption must stay inside the curved stroke');
      }
      expect(caption.bottom, lessThan(tester.getTopLeft(primary).dy));
      expect(tester.takeException(), isNull);
    });
  }
}
