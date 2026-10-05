import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/features/home/presentation/state/budget_companion_provider.dart';
import 'package:moneko/features/home/presentation/state/home_period_selection.dart';
import 'package:moneko/features/home/presentation/widgets/budget_companion_card.dart';
import 'package:moneko/l10n/app_localizations.dart';

String? _assetName(Image image) {
  final provider = image.image;
  if (provider is AssetImage) return provider.assetName;
  if (provider is ResizeImage && provider.imageProvider is AssetImage) {
    return (provider.imageProvider as AssetImage).assetName;
  }
  return null;
}

BudgetCompanionData _data(
        {double spent = 1842, double? budget = 3000, bool categories = true}) =>
    BudgetCompanionData(
      summary: AsyncData(BudgetCompanionSummary(spent: spent, budget: budget)),
      categories: AsyncData(categories
          ? budgetCompanionCategories({
              'food': 498,
              'shopping': 384,
              'rent': 292,
              'transport': 185,
              'coffee': 120,
              'travel': 90,
              'entertainment': 68,
            })
          : const []),
    );

Future<void> _pump(
  WidgetTester tester,
  BudgetCompanionData data, {
  double width = 390,
  double scale = 1,
  bool dark = false,
  String currency = 'USD',
  Locale locale = const Locale('en'),
  HomePeriodMode mode = HomePeriodMode.monthly,
  VoidCallback? onBudgetTap,
  VoidCallback? onRetry,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1000),
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Scaffold(
            body: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(16),
          child: BudgetCompanionCard(
              data: data,
              currency: currency,
              mode: mode,
              onBudgetTap: onBudgetTap ?? () {},
              onRetry: onRetry ?? () {}),
        )))),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('semantic message colors remain readable in both themes', () {
    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      final colors = theme.colorScheme;
      for (final pair in [
        (colors.success, colors.budgetSuccessForeground),
        (colors.info, colors.budgetInfoForeground),
        (colors.warning, colors.budgetWarningForeground),
        (colors.destructive, colors.budgetDangerForeground),
      ]) {
        final background = Color.alphaBlend(
            pair.$1.withValues(alpha: .13), colors.homeCardSurface);
        final l1 = pair.$2.computeLuminance();
        final l2 = background.computeLuminance();
        final ratio =
            (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${theme.brightness}: $pair');
      }
    }
  });
  testWidgets('normal summary and categories have no duplicated comparison',
      (tester) async {
    await _pump(tester, _data());
    expect(find.text(r'$1,842'), findsOneWidget);
    expect(find.text(r'spent of $3,000'), findsOneWidget);
    expect(find.text('61%'), findsOneWidget);
    expect(find.text(r'$1,158 left'), findsOneWidget);
    expect(find.text('8% less than last month'), findsNothing);
    expect(find.text('8% from last month'), findsNothing);
    expect(find.text("Nice! You're on track."), findsOneWidget);
    expect(find.text('Spending by category'), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('budget-bar-food'))).height,
        86);
    expect(
        tester
            .getSize(find.byKey(const ValueKey('budget-bar-shopping')))
            .height,
        closeTo(86 * 384 / 498, .01));
    final viewport = tester
        .getRect(find.byKey(const ValueKey('budget-companion-categories')));
    final nextBar =
        tester.getRect(find.byKey(const ValueKey('budget-bar-travel')));
    expect((viewport.right - nextBar.left) / nextBar.width, closeTo(.25, .001));
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
        images
            .any((image) => _assetName(image) == getCategoryImageAsset('food')),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'standard dashboard card surface in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await _pump(tester, _data(), dark: dark);
      final card = tester.widget<AnimatedContainer>(
          find.byKey(const ValueKey('budget-companion-card-surface')));
      final colors =
          (dark ? AppTheme.darkTheme() : AppTheme.lightTheme()).colorScheme;
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.gradient, isNull);
      expect(decoration.color, colors.homeCardSurface);
      expect(decoration.border, Border.all(color: colors.homeCardBorder));
      expect(decoration.borderRadius, BorderRadius.circular(24));
    });
  }

  for (final sample in [
    (280.0, 1.0, const Locale('en')),
    (390.0, 1.0, const Locale('en')),
    (430.0, 2.0, const Locale('en')),
    (768.0, 1.0, const Locale('ur')),
  ]) {
    testWidgets(
        'all categories scroll with a quarter-bar hint at ${sample.$1}px ${sample.$3}',
        (tester) async {
      final original = _data();
      final categories = budgetCompanionCategories({
        for (var index = 0; index < 30; index++)
          'category-$index': (30 - index).toDouble(),
      });
      await _pump(
          tester,
          BudgetCompanionData(
              summary: original.summary, categories: AsyncData(categories)),
          width: sample.$1,
          scale: sample.$2,
          locale: sample.$3);
      final chart = find.byKey(const ValueKey('budget-companion-categories'));
      final list = tester.widget<ListView>(chart);
      expect(
          (list.childrenDelegate as SliverChildBuilderDelegate).childCount, 30);
      final viewport = tester.getRect(chart);
      final count =
          (viewport.width / (60 * sample.$2.clamp(1, 2))).floor().clamp(2, 7);
      final next =
          tester.getRect(find.byKey(ValueKey('budget-bar-category-$count')));
      final visible = next.intersect(viewport).width;
      expect(visible / next.width, closeTo(.25, .001));
      final scrollable =
          find.descendant(of: chart, matching: find.byType(Scrollable));
      final last = find.byKey(const ValueKey('budget-bar-category-29'));
      await tester.scrollUntilVisible(last, 200, scrollable: scrollable);
      await tester.ensureVisible(last);
      await tester.pump(const Duration(milliseconds: 300));
      final lastRect = tester.getRect(last);
      expect(lastRect.left, greaterThanOrEqualTo(viewport.left - .01));
      expect(lastRect.right, lessThanOrEqualTo(viewport.right + .01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'categories that fit remain fully visible without scroll overflow',
      (tester) async {
    final original = _data();
    await _pump(
        tester,
        BudgetCompanionData(
            summary: original.summary,
            categories: AsyncData(
                budgetCompanionCategories({'food': 20, 'shopping': 10}))));
    final chart = find.byKey(const ValueKey('budget-companion-categories'));
    final position = tester
        .state<ScrollableState>(
            find.descendant(of: chart, matching: find.byType(Scrollable)))
        .position;
    expect(position.maxScrollExtent, 0);
    final viewport = tester.getRect(chart);
    for (final id in ['food', 'shopping']) {
      final rect = tester.getRect(find.byKey(ValueKey('budget-bar-$id')));
      expect(rect.left, greaterThanOrEqualTo(viewport.left));
      expect(rect.right, lessThanOrEqualTo(viewport.right));
    }
    expect(tester.takeException(), isNull);
  });

  for (final sample in [
    (28.0, 'celebrating', 'Looking good!'),
    (60.0, 'cheering', "Nice! You're on track."),
    (80.0, 'confused', 'Getting close!'),
    (100.0, 'confused', 'Getting close!'),
    (108.0, 'crying', 'Oops! We went over this month.'),
  ]) {
    testWidgets('mascot, message and progress at ${sample.$1}%',
        (tester) async {
      await _pump(tester, _data(spent: sample.$1, budget: 100));
      expect(find.text('${sample.$1.round()}%'), findsOneWidget);
      expect(find.text(sample.$3), findsOneWidget);
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
          images.any((image) =>
              _assetName(image) ==
              'lib/assets/mascots/moneko-${sample.$2}.png'),
          isTrue);
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byKey(const ValueKey('budget-companion-progress')))
              .value,
          (sample.$1 / 100).clamp(0, 1));
      if (sample.$1 == 108) {
        expect(find.text(r'$8 over budget'), findsOneWidget);
      }
      if (sample.$1 == 100) {
        expect(find.text(r'$0 left'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no budget offers the existing setup action without percentage',
      (tester) async {
    var opened = false;
    await _pump(tester, _data(budget: null), onBudgetTap: () => opened = true);
    expect(find.text('No budget configured'), findsOneWidget);
    expect(find.text("Let's make a plan!"), findsOneWidget);
    expect(
        find.byKey(const ValueKey('budget-companion-percent')), findsNothing);
    await tester.tap(find.text('Set Budget'));
    expect(opened, isTrue);
  });

  testWidgets('zero spending renders a meaningful empty chart', (tester) async {
    await _pump(tester, _data(spent: 0, categories: false));
    expect(find.text(r'$0'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('No Expenses Yet'), findsOneWidget);
    expect(find.text('100% less than last month'), findsNothing);
    expect(find.byKey(const ValueKey('budget-bar-food')), findsNothing);
  });

  testWidgets('RPC-only spending never looks like an authoritative empty total',
      (tester) async {
    await _pump(tester, _data(categories: false));
    expect(find.text(r'$1,842'), findsOneWidget);
    expect(find.text('No category spending available'), findsOneWidget);
    expect(find.text('No previous-period comparison'), findsNothing);
    expect(find.text('0% less than last month'), findsNothing);
  });

  testWidgets('daily mode uses daily labels and no monthly progress',
      (tester) async {
    await _pump(tester, _data(spent: 92, budget: null),
        mode: HomePeriodMode.daily);
    expect(find.text('spent this day'), findsOneWidget);
    expect(find.text('8% less than the previous day'), findsNothing);
    expect(
        find.byKey(const ValueKey('budget-companion-progress')), findsNothing);
  });

  testWidgets('initial loading has geometry but no fake money', (tester) async {
    await _pump(
        tester,
        const BudgetCompanionData(
            summary: AsyncLoading(), categories: AsyncLoading()));
    expect(find.byType(BudgetCompanionSkeleton), findsOneWidget);
    expect(find.text(r'$0'), findsNothing);
    expect(find.text('No budget configured'), findsNothing);
    await _pump(
        tester,
        const BudgetCompanionData(
            summary: AsyncLoading(), categories: AsyncLoading()),
        width: 280,
        scale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cached refresh and category error retain the financial summary',
      (tester) async {
    final cached = _data();
    var retried = false;
    await _pump(
        tester,
        BudgetCompanionData(
          summary: const AsyncLoading<BudgetCompanionSummary>()
              .copyWithPrevious(cached.summary),
          categories: AsyncError(StateError('offline'), StackTrace.current),
          isRefreshing: true,
        ),
        onRetry: () => retried = true);
    expect(find.text(r'$1,842'), findsOneWidget);
    expect(find.byType(BudgetCompanionSkeleton), findsNothing);
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uncached error is contained with retry', (tester) async {
    await _pump(
        tester,
        BudgetCompanionData(
            summary: AsyncError(StateError('offline'), StackTrace.current),
            categories: const AsyncLoading()));
    expect(
        find.byKey(const ValueKey('budget-companion-error')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text(r'$0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final width in [280.0, 320.0, 390.0, 430.0, 768.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            '${dark ? 'dark' : 'light'} ${width}px text scale $scale has no overflow',
            (tester) async {
          await _pump(tester, _data(spent: 1e12, budget: 2e12),
              dark: dark, width: width, scale: scale);
          expect(find.byType(BudgetCompanionCard), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final locale in [
    const Locale('de'),
    const Locale('th'),
    const Locale('ur')
  ]) {
    testWidgets('existing locale formatter and RTL support for $locale',
        (tester) async {
      await _pump(tester, _data(spent: 1234.5, budget: 2000),
          currency: 'EUR', locale: locale, width: 320);
      expect(find.textContaining('€'), findsWidgets);
      if (locale.languageCode == 'de') {
        expect(find.text('€1.234,50'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
