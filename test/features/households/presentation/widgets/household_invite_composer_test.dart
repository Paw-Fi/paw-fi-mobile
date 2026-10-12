import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_invite_composer_provider.dart';
import 'package:moneko/features/households/presentation/widgets/household_invite_composer.dart';

void main() {
  testWidgets('role help and member/never selectors drive the confirmed link',
      (tester) async {
    final response = Completer<String>();
    HouseholdInviteDraft? saved;
    var calls = 0;
    String? copied;
    var failCopy = false;
    String? shared;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(shareChannel,
        (call) async {
      shared = (call.arguments as Map)['text'] as String;
      return 'success';
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null));
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (failCopy) throw PlatformException(code: 'clipboard-unavailable');
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user'),
          householdInviteComposerProvider
              .overrideWith((ref, key) => HouseholdInviteComposerNotifier(
                    createInvite: (draft) {
                      calls++;
                      saved = draft;
                      return response.future;
                    },
                    isActorActive: () => true,
                  )),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child:
              HouseholdInviteComposer(householdId: 'space', isReusable: true),
        )))));
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('7 Days'), findsOneWidget);
    expect(find.text('Copy Link'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('invite-role-help')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Admins can'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invite-role-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Member').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-expiry-selector')));
    await tester.pumpAndSettle();
    for (final label in [
      '1 Day',
      '3 Days',
      '7 Days',
      '14 Days',
      '30 Days',
      'Never expires'
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Never expires').last);
    await tester.pumpAndSettle();
    final create = find.text('Create group link');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Copy Link'), findsNothing);
    expect(calls, 1);
    expect(saved?.invitedRole, HouseholdRole.member);
    expect(saved?.expiresInDays, 0);
    response.complete('https://moneko.io/invites/shared');
    await tester.pumpAndSettle();
    final copy = find.text('Copy Link');
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, 'https://moneko.io/invites/shared');
    expect(find.text('Share link'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share link'));
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect(shared, 'https://moneko.io/invites/shared');
    failCopy = true;
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    expect(find.text('https://moneko.io/invites/shared'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });

  testWidgets('personal invitation preserves message and retry state',
      (tester) async {
    var calls = 0;
    HouseholdInviteDraft? saved;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('user'),
          householdInviteComposerProvider
              .overrideWith((ref, key) => HouseholdInviteComposerNotifier(
                    createInvite: (draft) async {
                      saved = draft;
                      calls++;
                      throw TimeoutException('offline');
                    },
                    isActorActive: () => true,
                  )),
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child:
              HouseholdInviteComposer(householdId: 'space', isReusable: false),
        )))));
    await tester.enterText(
        find.byKey(const ValueKey('invite-email-user')), 'friend@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('invite-message-user')), '一緒に参加しましょう');
    final create = find.text('Create Invitation');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(saved?.invitedEmail, 'friend@example.com');
    expect(saved?.personalMessage, '一緒に参加しましょう');
    expect(find.text('Copy Link'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), null);
  });

  for (final brightness in Brightness.values) {
    testWidgets('composer supports $brightness and large text', (tester) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('user'),
          ],
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                child: HouseholdInviteComposer(
                    householdId: 'space', isReusable: true),
              )),
            ),
          )));
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'real bottom sheet keeps controls reachable with keyboard and large text',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserIdProvider.overrideWithValue('user')],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => showHouseholdInviteComposer(context,
                      householdId: 'space'),
                  child: const Text('Open'),
                ))),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create group link'));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
