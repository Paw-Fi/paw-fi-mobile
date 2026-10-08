import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_widgets.dart';

const _settlement = DashboardWidgetConfig(
  id: 'settlement',
  type: DashboardWidgetType.householdSettlement,
  order: 0,
);
const _member = DashboardWidgetConfig(
  id: 'member',
  type: DashboardWidgetType.householdMemberSpending,
  order: 1,
);

Future<void> _pump(
  WidgetTester tester,
  List<DashboardWidgetConfig> configs, {
  bool editMode = false,
  bool fixedSection = true,
  void Function(int, int)? onReorder,
}) =>
    tester.pumpWidget(ProviderScope(
      overrides: [isEditModeProvider.overrideWith((ref) => editMode)],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: CustomScrollView(slivers: [
            DraggableDashboardList(
              configs: configs,
              fixedSection: fixedSection
                  ? const SizedBox(height: 80, child: Text('companion'))
                  : null,
              fixedSectionAfter: DashboardWidgetType.householdSettlement,
              onReorder: onReorder ?? (_, __) {},
              onToggleVisibility: (_) {},
              onUpdateConfig: (_, {dateRange, viewMode, start, end}) {},
              widgetBuilders: {
                for (final config in configs)
                  config.type: (_, config) =>
                      SizedBox(height: 80, child: Text(config.id)),
              },
            ),
          ]),
        ),
      ),
    ));

void main() {
  testWidgets('default order puts settlement before companion', (tester) async {
    await _pump(tester, [_settlement, _member]);
    expect(tester.getTopLeft(find.text('settlement')).dy,
        lessThan(tester.getTopLeft(find.text('companion')).dy));
    expect(tester.getTopLeft(find.text('companion')).dy,
        lessThan(tester.getTopLeft(find.text('member')).dy));
  });

  testWidgets('custom settlement position is retained', (tester) async {
    await _pump(tester, [_member, _settlement]);
    expect(tester.getTopLeft(find.text('member')).dy,
        lessThan(tester.getTopLeft(find.text('settlement')).dy));
    expect(tester.getTopLeft(find.text('settlement')).dy,
        lessThan(tester.getTopLeft(find.text('companion')).dy));
  });

  testWidgets('hidden settlement leaves companion visible at the beginning',
      (tester) async {
    await _pump(tester, [_settlement.copyWith(isVisible: false), _member]);
    expect(find.text('settlement'), findsNothing);
    expect(tester.getTopLeft(find.text('companion')).dy,
        lessThan(tester.getTopLeft(find.text('member')).dy));
  });

  testWidgets('missing anchor leaves companion visible', (tester) async {
    await _pump(tester, [_member]);
    expect(find.text('companion'), findsOneWidget);
    expect(find.text('member'), findsOneWidget);
  });

  testWidgets('fixed section cannot start a drag and offsets saved indices',
      (tester) async {
    final calls = <(int, int)>[];
    await _pump(tester, [_settlement, _member],
        editMode: true, onReorder: (old, next) => calls.add((old, next)));
    expect(
        find.ancestor(
            of: find.text('companion'),
            matching: find.byType(ReorderableDelayedDragStartListener)),
        findsNothing);
    final list = tester
        .widget<SliverReorderableList>(find.byType(SliverReorderableList));
    list.onReorder(0, 3); // Settlement to end, across the fixed section.
    list.onReorder(2, 0); // Member to beginning, across the fixed section.
    list.onReorder(1, 0); // The fixed section never enters saved configs.
    expect(calls, [(0, 2), (1, 0)]);
  });

  testWidgets('lists without a fixed section retain their reorder indices',
      (tester) async {
    final calls = <(int, int)>[];
    await _pump(tester, [_settlement, _member],
        editMode: true,
        fixedSection: false,
        onReorder: (old, next) => calls.add((old, next)));
    final list = tester
        .widget<SliverReorderableList>(find.byType(SliverReorderableList));
    list.onReorder(0, 2);
    expect(calls, [(0, 2)]);
    expect(find.text('companion'), findsNothing);
  });
}
