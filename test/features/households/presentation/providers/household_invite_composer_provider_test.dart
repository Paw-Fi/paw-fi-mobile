import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_invite_composer_provider.dart';

void main() {
  test('default draft is admin with seven-day expiry', () {
    const draft = HouseholdInviteDraft();
    expect(draft.invitedRole, HouseholdRole.admin);
    expect(draft.expiresInDays, 7);
  });

  test('pending blocks duplicate writes and freezes captured choices',
      () async {
    final response = Completer<String>();
    final drafts = <HouseholdInviteDraft>[];
    final notifier = HouseholdInviteComposerNotifier(
      createInvite: (draft) {
        drafts.add(draft);
        return response.future;
      },
      isActorActive: () => true,
    );
    late HouseholdInviteComposerState state;
    notifier.addListener((value) => state = value);
    notifier.setRole(HouseholdRole.member);
    notifier.setExpiry(0);
    final first = notifier.create();
    await notifier.create();
    notifier.setRole(HouseholdRole.admin);
    expect(state.result.isLoading, true);
    expect(state.result.valueOrNull, null);
    expect(drafts.length, 1);
    expect(drafts.single.invitedRole, HouseholdRole.member);
    expect(drafts.single.expiresInDays, 0);
    response.complete('https://moneko.io/invites/shared-token');
    await first;
    expect(state.result.valueOrNull, 'https://moneko.io/invites/shared-token');
    notifier.dispose();
  });

  for (final error in [TimeoutException('offline'), StateError('denied')]) {
    test('failure retains form choices and permits a deliberate retry: $error',
        () async {
      var calls = 0;
      final notifier = HouseholdInviteComposerNotifier(
        createInvite: (draft) async {
          if (calls++ == 0) throw error;
          return 'https://moneko.io/invites/retry';
        },
        isActorActive: () => true,
      );
      late HouseholdInviteComposerState state;
      notifier.addListener((value) => state = value);
      notifier.setRole(HouseholdRole.member);
      notifier.setMessage('一起分担费用');
      await notifier.create();
      expect(state.result.hasError, true);
      expect(state.result.valueOrNull, null);
      expect(state.draft.invitedRole, HouseholdRole.member);
      expect(state.draft.personalMessage, '一起分担费用');
      await notifier.create();
      expect(state.result.valueOrNull, 'https://moneko.io/invites/retry');
      notifier.dispose();
    });
  }

  test('actor switch and disposal discard late confirmation', () async {
    for (final dispose in [false, true]) {
      var active = true;
      final response = Completer<String>();
      final notifier = HouseholdInviteComposerNotifier(
        createInvite: (_) => response.future,
        isActorActive: () => active,
      );
      final states = <HouseholdInviteComposerState>[];
      notifier.addListener(states.add);
      final pending = notifier.create();
      if (dispose) {
        notifier.dispose();
      } else {
        active = false;
      }
      final count = states.length;
      response.complete('secret-link');
      await pending;
      expect(states.length, count);
      if (!dispose) notifier.dispose();
    }
  });

  test('invalid roles, expiry and absent actor cannot dispatch', () async {
    var calls = 0;
    final notifier = HouseholdInviteComposerNotifier(
      createInvite: (_) async {
        calls++;
        return 'link';
      },
      isActorActive: () => false,
    );
    notifier.setRole(HouseholdRole.owner);
    notifier.setExpiry(-1);
    await notifier.create();
    expect(calls, 0);
    notifier.dispose();
  });
}
