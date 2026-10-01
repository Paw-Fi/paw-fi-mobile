import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_lazy_providers.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_series_group_sliver.dart';
import 'package:moneko/features/recurring/presentation/widgets/recurring_transaction_card.dart';
import 'package:moneko/l10n/app_localizations.dart';

final _date = DateTime(2026, 9, 20);

RecurringSeriesSummary _summary(int index, {bool actionable = true}) =>
    RecurringSeriesSummary(
      transaction: RecurringTransaction(
        id: 'series-$index',
        userId: 'user-1',
        date: _date,
        category: 'food',
        description: 'Subscription $index',
        amount: 20,
        currency: 'EUR',
        ownerType: 'me',
        privacyScope: 'private',
        type: 'expense',
        attachments: const [],
        createdAt: _date,
        recurrenceRule: RecurrenceRule(frequency: 'monthly', anchorDate: _date),
      ),
      nextOccurrenceDate: _date,
      latestActionableOccurrenceDate: actionable ? _date : null,
    );

Widget _harness(ProviderContainer container, Widget sliver,
        {double scale = 1, ThemeData? theme}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
              body: CustomScrollView(slivers: [
            SliverPadding(padding: const EdgeInsets.all(16), sliver: sliver),
          ])),
        ),
      ),
    );

void main() {
  testWidgets('150 series build and read only rows in the viewport cache',
      (tester) async {
    final queries = <String>[];
    final container = ProviderContainer(overrides: [
      recurringOccurrenceMaterializedProvider.overrideWith((ref, query) async {
        queries.add(query.recurringId);
        return false;
      }),
    ]);
    addTearDown(container.dispose);
    String? tapped;
    String? deleted;
    await tester.pumpWidget(_harness(
        container,
        RecurringSeriesGroupSliver(
          summaries: List.generate(150, _summary),
          showCurrencyFlag: false,
          onTransactionTap: (row) => tapped = row.id,
          onTransactionDelete: (row) => deleted = row.id,
        )));
    await tester.pumpAndSettle();
    expect(
        find.byType(RecurringTransactionCard).evaluate().length, lessThan(20));
    expect(queries.length, lessThan(20));
    expect(queries, isNot(contains('series-149')));
    await tester.tap(find.text('Subscription 0'));
    expect(tapped, 'series-0');
    await tester.scrollUntilVisible(find.text('Subscription 149'), 600,
        scrollable: find.byType(Scrollable), maxScrolls: 50);
    await tester.pumpAndSettle();
    expect(queries, contains('series-149'));
    await tester.tap(find.text('Subscription 149'));
    expect(tapped, 'series-149');
    final last = find.ancestor(
        of: find.text('Subscription 149'), matching: find.byType(Slidable));
    await tester.drag(last, const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    expect(deleted, 'series-149');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown/materialized state never exposes a stale confirm action',
      (tester) async {
    final gate = Completer<bool>();
    final container = ProviderContainer(overrides: [
      recurringOccurrenceMaterializedProvider
          .overrideWith((ref, query) => gate.future),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_harness(
        container,
        RecurringSeriesGroupSliver(
          summaries: [_summary(0)],
          showCurrencyFlag: false,
        )));
    expect(
        tester
            .widget<RecurringTransactionCard>(
                find.byType(RecurringTransactionCard))
            .latestActionableOccurrenceDate,
        isNull);
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RecurringTransactionCard>(
                find.byType(RecurringTransactionCard))
            .latestActionableOccurrenceDate,
        isNull);
  });

  testWidgets(
      'an occurrence read updates its row without rebuilding other rows',
      (tester) async {
    final gate = Completer<bool>();
    final container = ProviderContainer(overrides: [
      recurringOccurrenceMaterializedProvider.overrideWith((ref, query) =>
          query.recurringId == 'series-0' ? gate.future : Future.value(false)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_harness(
        container,
        RecurringSeriesGroupSliver(
          summaries: [_summary(0), _summary(1)],
          showCurrencyFlag: false,
        )));
    await tester.pump();
    final other = tester
        .widgetList<RecurringTransactionCard>(
            find.byType(RecurringTransactionCard))
        .last;
    gate.complete(false);
    await tester.pumpAndSettle();
    final cards = tester
        .widgetList<RecurringTransactionCard>(
            find.byType(RecurringTransactionCard))
        .toList();
    expect(cards.first.latestActionableOccurrenceDate, _date);
    expect(identical(cards.last, other), isTrue);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'group retains original row geometry with large text dark=$dark',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final summaries = [
        _summary(0, actionable: false),
        _summary(1, actionable: false)
      ];
      final theme = dark ? ThemeData.dark() : ThemeData.light();
      await tester.pumpWidget(_harness(container,
          SliverToBoxAdapter(child: Builder(builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.homeCardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.homeCardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                  color: colors.homeCardShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -4)
            ],
          ),
          child: Column(children: [
            RecurringTransactionCard(
                transaction: summaries.first.transaction,
                nextOccurrenceDate: _date,
                grouped: true),
            const SizedBox(height: 8),
            RecurringTransactionCard(
                transaction: summaries.last.transaction,
                nextOccurrenceDate: _date,
                grouped: true),
          ]),
        );
      })), scale: 2, theme: theme));
      await tester.pumpAndSettle();
      final original = find
          .byType(RecurringTransactionCard)
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList();
      await tester.pumpWidget(_harness(
          container,
          RecurringSeriesGroupSliver(
            summaries: summaries,
            showCurrencyFlag: false,
          ),
          scale: 2,
          theme: theme));
      await tester.pumpAndSettle();
      final current = find
          .byType(RecurringTransactionCard)
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList();
      expect(current, original);
      expect(tester.takeException(), isNull);
    });
  }
}
