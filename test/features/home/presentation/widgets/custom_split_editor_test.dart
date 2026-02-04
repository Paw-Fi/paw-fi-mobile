import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/home/presentation/widgets/custom_split_sheet.dart';
import 'package:moneko/features/households/domain/entities/household.dart';

HouseholdMember _member(String userId, String name) {
  final now = DateTime(2025, 1, 1);
  return HouseholdMember(
    id: 'm_$userId',
    householdId: 'h1',
    userId: userId,
    role: HouseholdRole.member,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    userEmail: '$name@example.com',
    userName: name,
    avatarUrl: null,
  );
}

void main() {
  testWidgets('Switching to percent initializes percentages when missing',
      (tester) async {
    final members = <HouseholdMember>[
      _member('u1', 'Alice'),
      _member('u2', 'Bob'),
      _member('u3', 'Cara'),
    ];

    final initialSplits = members
        .map(
          (m) => MemberSplit(
            member: m,
            amount: 10,
            percentage: null,
            shares: null,
            includedInAmount: true,
            includedInPercentage: true,
          ),
        )
        .toList();

    SplitType? latestType;
    List<MemberSplit>? latestSplits;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSplitEditor(
            members: members,
            totalAmount: 30,
            currencySymbol: '\$',
            initialSplitType: SplitType.amount,
            initialSplits: initialSplits,
            onChanged: (type, splits) {
              latestType = type;
              latestSplits = splits;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Percent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(latestType, SplitType.percentage);
    expect(latestSplits, isNotNull);

    final sum = latestSplits!
        .map((s) => s.percentage ?? 0)
        .fold<double>(0, (a, b) => a + b);
    expect(sum, closeTo(100.0, 0.01));
    expect(latestSplits!.every((s) => (s.percentage ?? 0) >= 0), isTrue);
  });

  testWidgets('Shares: initializes to 1 and uses null for excluded',
      (tester) async {
    final members = <HouseholdMember>[
      _member('u1', 'Alice'),
      _member('u2', 'Bob'),
    ];

    final initialSplits = members
        .map(
          (m) => MemberSplit(
            member: m,
            amount: 5,
            percentage: null,
            shares: null,
            includedInAmount: true,
            includedInPercentage: true,
          ),
        )
        .toList();

    SplitType? latestType;
    List<MemberSplit>? latestSplits;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSplitEditor(
            members: members,
            totalAmount: 10,
            currencySymbol: '\$',
            initialSplitType: SplitType.amount,
            initialSplits: initialSplits,
            onChanged: (type, splits) {
              latestType = type;
              latestSplits = splits;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(latestType, SplitType.shares);
    expect(latestSplits, isNotNull);
    expect(latestSplits!.every((s) => s.shares == 1), isTrue);

    final checkboxes = find.byType(AdaptiveCheckbox);
    expect(checkboxes, findsWidgets);

    await tester.tap(checkboxes.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(latestType, SplitType.shares);
    expect(latestSplits, isNotNull);
    expect(latestSplits!.first.shares, isNull);
  });

  testWidgets('Rescales amount splits when total changes', (tester) async {
    final members = <HouseholdMember>[
      _member('u1', 'Alice'),
      _member('u2', 'Bob'),
    ];

    final initialSplits = <MemberSplit>[
      MemberSplit(
        member: members[0],
        amount: 30,
        percentage: 60,
        shares: 1,
        includedInAmount: true,
        includedInPercentage: true,
      ),
      MemberSplit(
        member: members[1],
        amount: 20,
        percentage: 40,
        shares: 1,
        includedInAmount: true,
        includedInPercentage: true,
      ),
    ];

    SplitType? latestType;
    List<MemberSplit>? latestSplits;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSplitEditor(
            members: members,
            totalAmount: 50,
            currencySymbol: '\$',
            initialSplitType: SplitType.amount,
            initialSplits: initialSplits,
            onChanged: (type, splits) {
              latestType = type;
              latestSplits = splits;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSplitEditor(
            members: members,
            totalAmount: 100,
            currencySymbol: '\$',
            initialSplitType: SplitType.amount,
            initialSplits: initialSplits,
            onChanged: (type, splits) {
              latestType = type;
              latestSplits = splits;
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(latestType, SplitType.amount);
    expect(latestSplits, isNotNull);
    final amounts = latestSplits!.map((s) => s.amount ?? 0).toList();
    expect(amounts[0], closeTo(60, 0.01));
    expect(amounts[1], closeTo(40, 0.01));
  });
}
