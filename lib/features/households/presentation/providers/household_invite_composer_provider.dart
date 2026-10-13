import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import '../../domain/entities/household.dart';
import '../utils/invite_link_utils.dart';
import 'household_providers.dart';

const householdInviteExpiryDays = [1, 3, 7, 14, 30, 0];

typedef HouseholdInviteComposerKey = ({
  String userId,
  String householdId,
  bool isReusable,
});

class HouseholdInviteDraft {
  const HouseholdInviteDraft({
    this.invitedRole = HouseholdRole.admin,
    this.expiresInDays = 7,
    this.invitedEmail = '',
    this.personalMessage = '',
  });

  final HouseholdRole invitedRole;
  final int expiresInDays;
  final String invitedEmail;
  final String personalMessage;

  HouseholdInviteDraft copyWith({
    HouseholdRole? invitedRole,
    int? expiresInDays,
    String? invitedEmail,
    String? personalMessage,
  }) =>
      HouseholdInviteDraft(
        invitedRole: invitedRole ?? this.invitedRole,
        expiresInDays: expiresInDays ?? this.expiresInDays,
        invitedEmail: invitedEmail ?? this.invitedEmail,
        personalMessage: personalMessage ?? this.personalMessage,
      );
}

class HouseholdInviteComposerState {
  const HouseholdInviteComposerState({
    this.draft = const HouseholdInviteDraft(),
    this.result = const AsyncData(null),
  });
  final HouseholdInviteDraft draft;
  final AsyncValue<String?> result;
  bool get canEdit => !result.isLoading && result.valueOrNull == null;
}

class HouseholdInviteComposerNotifier
    extends StateNotifier<HouseholdInviteComposerState> {
  HouseholdInviteComposerNotifier({
    required Future<String> Function(HouseholdInviteDraft) createInvite,
    required bool Function() isActorActive,
  })  : _createInvite = createInvite,
        _isActorActive = isActorActive,
        super(const HouseholdInviteComposerState());

  final Future<String> Function(HouseholdInviteDraft) _createInvite;
  final bool Function() _isActorActive;

  void _update(HouseholdInviteDraft draft) {
    if (!state.canEdit) return;
    state = HouseholdInviteComposerState(draft: draft);
  }

  void setRole(HouseholdRole role) {
    if (role != HouseholdRole.admin && role != HouseholdRole.member) return;
    _update(state.draft.copyWith(invitedRole: role));
  }

  void setExpiry(int days) {
    if (!householdInviteExpiryDays.contains(days)) return;
    _update(state.draft.copyWith(expiresInDays: days));
  }

  void setEmail(String email) =>
      _update(state.draft.copyWith(invitedEmail: email));
  void setMessage(String message) =>
      _update(state.draft.copyWith(personalMessage: message));

  void startNewInvite() {
    if (state.result.isLoading || !_isActorActive()) return;
    state = HouseholdInviteComposerState(draft: state.draft);
  }

  Future<void> create() async {
    if (!state.canEdit || !_isActorActive()) return;
    final draft = state.draft;
    state = HouseholdInviteComposerState(
        draft: draft, result: const AsyncLoading());
    final result = await AsyncValue.guard(() => _createInvite(draft));
    if (!mounted || !_isActorActive()) return;
    state = HouseholdInviteComposerState(draft: draft, result: result);
  }
}

final householdInviteLibraryFormProvider = StateProvider.autoDispose
    .family<bool, HouseholdInviteComposerKey>((ref, key) => false);

final householdInviteComposerProvider = StateNotifierProvider.autoDispose
    .family<HouseholdInviteComposerNotifier, HouseholdInviteComposerState,
        HouseholdInviteComposerKey>((ref, key) {
  ref.watch(currentUserIdProvider);
  return HouseholdInviteComposerNotifier(
    isActorActive: () =>
        key.userId.isNotEmpty && ref.read(currentUserIdProvider) == key.userId,
    createInvite: (draft) async {
      final user = ref.read(authProvider);
      final token = await ref
          .read(householdInvitesProvider(key.householdId).notifier)
          .createInvite(
            invitedEmail: key.isReusable || draft.invitedEmail.trim().isEmpty
                ? null
                : draft.invitedEmail.trim(),
            personalMessage: draft.personalMessage.trim().isEmpty
                ? null
                : draft.personalMessage.trim(),
            inviterName: user.displayName ?? user.email,
            expiresInDays: draft.expiresInDays,
            isReusable: key.isReusable,
            invitedRole: draft.invitedRole,
          );
      return buildInviteLink(token);
    },
  );
});
