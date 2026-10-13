import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/moneko_selector_button.dart';
import 'package:moneko/shared/widgets/moneko_text_form_field.dart';
import '../../domain/entities/household.dart';
import '../providers/household_invite_composer_provider.dart';
import 'household_invite_links.dart';

Future<void> showHouseholdInviteComposer(
  BuildContext context, {
  required String householdId,
  bool isReusable = true,
}) =>
    MonekoBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      title: isReusable
          ? context.l10n.shareGroupLink
          : context.l10n.createInvitation,
      onCloseWithContext: (sheetContext) => Navigator.of(sheetContext).pop(),
      builder: (_) => _HouseholdInviteSheetContent(
          householdId: householdId, isReusable: isReusable),
    );

class _HouseholdInviteSheetContent extends ConsumerWidget {
  const _HouseholdInviteSheetContent({
    required this.householdId,
    required this.isReusable,
  });

  final String householdId;
  final bool isReusable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final key =
        (userId: userId, householdId: householdId, isReusable: isReusable);
    final state = ref.watch(householdInviteComposerProvider(key));
    final formProvider = householdInviteLibraryFormProvider(key);
    final showForm = !isReusable || ref.watch(formProvider);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    void showLinks() {
      if (ref.read(currentUserIdProvider) != userId) return;
      FocusScope.of(context).unfocus();
      ref.read(formProvider.notifier).state = false;
    }

    return AnimatedSize(
      duration: duration,
      alignment: Alignment.topCenter,
      curve: Curves.easeInOutCubic,
      child: AnimatedSwitcher(
        duration: duration,
        child: showForm
            ? Column(
                key: ValueKey('invite-editor-$userId'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isReusable)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: state.result.isLoading ? null : showLinks,
                          icon: const BackButtonIcon(),
                          label: Text(context.l10n.savedInviteLinks,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  Flexible(
                    child: HouseholdInviteComposer(
                      householdId: householdId,
                      isReusable: isReusable,
                      onCreated: isReusable ? showLinks : null,
                    ),
                  ),
                ],
              )
            : HouseholdInviteLinks(
                key: ValueKey('invite-library-$userId'),
                userId: userId,
                householdId: householdId,
                confirmedLink: state.result.valueOrNull,
                onCreate: userId.isEmpty
                    ? null
                    : () {
                        if (ref.read(currentUserIdProvider) != userId) return;
                        ref
                            .read(householdInviteComposerProvider(key).notifier)
                            .startNewInvite();
                        ref.read(formProvider.notifier).state = true;
                      },
              ),
      ),
    );
  }
}

class HouseholdInviteComposer extends ConsumerWidget {
  const HouseholdInviteComposer(
      {super.key,
      required this.householdId,
      required this.isReusable,
      this.onCreated});
  final String householdId;
  final bool isReusable;
  final VoidCallback? onCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final key =
        (userId: userId, householdId: householdId, isReusable: isReusable);
    final state = ref.watch(householdInviteComposerProvider(key));
    final controller = ref.read(householdInviteComposerProvider(key).notifier);
    final scheme = Theme.of(context).colorScheme;
    final link = state.result.valueOrNull;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (isReusable) ...[
          Text(context.l10n.groupInviteLinkDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.mutedForeground,
                  fontSize: 12,
                  fontWeight: FontWeight.w400)),
          const SizedBox(height: 8),
        ] else ...[
          _InviteField(
            title: context.l10n.emailOptional,
            child: MonekoTextFormField(
              compact: true,
              key: ValueKey('invite-email-$userId'),
              initialValue: state.draft.invitedEmail,
              enabled: state.canEdit,
              keyboardType: TextInputType.emailAddress,
              placeholder: context.l10n.friendEmailExample,
              onChanged: controller.setEmail,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _InviteField(
          title: context.l10n.invitedUserRole,
          help: Tooltip(
            key: const ValueKey('invite-role-help'),
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(days: 365),
            message: context.l10n.invitationRoleHelp,
            child: SizedBox.square(
                dimension: 48,
                child: Icon(Icons.info_outline,
                    size: 20,
                    color: scheme.mutedForeground,
                    semanticLabel: context.l10n.invitedUserRole)),
          ),
          child: _InviteDropdown<HouseholdRole>(
            selectorKey: const ValueKey('invite-role-selector'),
            enabled: state.canEdit,
            value: state.draft.invitedRole,
            options: const [HouseholdRole.admin, HouseholdRole.member],
            label: (role) => role == HouseholdRole.admin
                ? context.l10n.admin
                : context.l10n.member,
            onChanged: controller.setRole,
          ),
        ),
        const SizedBox(height: 8),
        _InviteField(
          title: context.l10n.linkExpiration,
          child: _InviteDropdown<int>(
            selectorKey: const ValueKey('invite-expiry-selector'),
            enabled: state.canEdit,
            value: state.draft.expiresInDays,
            options: householdInviteExpiryDays,
            label: (days) => _expiryLabel(context, days),
            onChanged: controller.setExpiry,
          ),
        ),
        const SizedBox(height: 8),
        _InviteField(
          title: context.l10n.personalMessageOptional,
          child: MonekoTextFormField(
            compact: true,
            key: ValueKey('invite-message-$userId'),
            initialValue: state.draft.personalMessage,
            enabled: state.canEdit,
            minLines: 1,
            maxLines: 3,
            onChanged: controller.setMessage,
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: link == null
                ? Column(key: const ValueKey('invite-form-actions'), children: [
                    if (state.result.hasError) ...[
                      Text(
                          ErrorHandler.getUserFriendlyMessage(
                              state.result.error!),
                          style: TextStyle(color: scheme.destructive)),
                      const SizedBox(height: 12),
                    ],
                    PrimaryAdaptiveButton(
                      compact: true,
                      onPressed: state.canEdit && userId.isNotEmpty
                          ? () async {
                              await controller.create();
                              if (context.mounted &&
                                  ref.read(currentUserIdProvider) == userId &&
                                  ref
                                          .read(householdInviteComposerProvider(
                                              key))
                                          .result
                                          .valueOrNull !=
                                      null) {
                                onCreated?.call();
                              }
                            }
                          : null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: state.result.isLoading
                            ? SizedBox.square(
                                key: const ValueKey('invite-creating'),
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: scheme.primaryForeground))
                            : Text(isReusable
                                ? context.l10n.createGroupLink
                                : context.l10n.createInvitation),
                      ),
                    ),
                  ])
                : Column(
                    key: const ValueKey('invite-link-actions'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        SelectableText(link,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 16),
                        PrimaryAdaptiveButton(
                          compact: true,
                          onPressed: () async {
                            if (ref.read(currentUserIdProvider) != userId) {
                              return;
                            }
                            try {
                              await Clipboard.setData(
                                  ClipboardData(text: link));
                              if (context.mounted &&
                                  ref.read(currentUserIdProvider) == userId) {
                                AppToast.success(
                                    context, context.l10n.inviteLinkCopiedToClipboard);
                              }
                            } catch (error) {
                              if (context.mounted &&
                                  ref.read(currentUserIdProvider) == userId) {
                                AppToast.error(context,
                                    ErrorHandler.getUserFriendlyMessage(error));
                              }
                            }
                          },
                          child: Text(context.l10n.copyLink),
                        ),
                        const SizedBox(height: 12),
                        PrimaryAdaptiveButton.outlined(
                          compact: true,
                          onPressed: () async {
                            if (ref.read(currentUserIdProvider) != userId) {
                              return;
                            }
                            final box =
                                context.findRenderObject() as RenderBox?;
                            try {
                              await Share.share(link,
                                  sharePositionOrigin: box == null
                                      ? null
                                      : box.localToGlobal(Offset.zero) &
                                          box.size);
                            } catch (error) {
                              if (context.mounted &&
                                  ref.read(currentUserIdProvider) == userId) {
                                AppToast.error(context,
                                    ErrorHandler.getUserFriendlyMessage(error));
                              }
                            }
                          },
                          child: Text(context.l10n.shareInviteLink),
                        ),
                      ]),
          ),
        ),
      ]),
    );
  }
}

String _expiryLabel(BuildContext context, int days) => switch (days) {
      0 => context.l10n.inviteNeverExpires,
      1 => context.l10n.oneDay,
      3 => context.l10n.threeDays,
      7 => context.l10n.sevenDays,
      14 => context.l10n.fourteenDays,
      30 => context.l10n.thirtyDays,
      _ => context.l10n.expiresInDays(days),
    };

class _InviteDropdown<T> extends StatelessWidget {
  const _InviteDropdown(
      {required this.selectorKey,
      required this.enabled,
      required this.value,
      required this.options,
      required this.label,
      required this.onChanged});
  final Key selectorKey;
  final bool enabled;
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
        key: selectorKey,
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: AdaptivePopupMenuButton.widget<T>(
            items: [
              for (final option in options)
                AdaptivePopupMenuItem(label: label(option), value: option)
            ],
            onSelected: (_, item) {
              if (enabled && item.value != null) onChanged(item.value as T);
            },
            child: AbsorbPointer(
              child: MonekoSelectorButton.space(
                compact: true,
                label: label(value),
                onPressed: () {},
              ),
            ),
          ),
        ));
  }
}

class _InviteField extends StatelessWidget {
  const _InviteField({required this.title, required this.child, this.help});

  final String title;
  final Widget child;
  final Widget? help;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(children: [
            Flexible(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurface))),
            if (help != null) help!,
          ]),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
