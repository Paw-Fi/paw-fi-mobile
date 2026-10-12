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
import '../../domain/entities/household.dart';
import '../providers/household_invite_composer_provider.dart';

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
      builder: (_) => HouseholdInviteComposer(
          householdId: householdId, isReusable: isReusable),
    );

class HouseholdInviteComposer extends ConsumerWidget {
  const HouseholdInviteComposer(
      {super.key, required this.householdId, required this.isReusable});
  final String householdId;
  final bool isReusable;

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
          20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (isReusable) ...[
          Text(context.l10n.groupInviteLinkDescription,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.mutedForeground)),
          const SizedBox(height: 16),
        ] else ...[
          TextFormField(
            key: ValueKey('invite-email-$userId'),
            initialValue: state.draft.invitedEmail,
            enabled: state.canEdit,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: context.l10n.emailOptional),
            onChanged: controller.setEmail,
          ),
          const SizedBox(height: 16),
        ],
        Row(children: [
          Expanded(
              child: Text(context.l10n.invitedUserRole,
                  style: Theme.of(context).textTheme.titleSmall)),
          Tooltip(
            key: const ValueKey('invite-role-help'),
            triggerMode: TooltipTriggerMode.tap,
            message: context.l10n.invitationRoleHelp,
            child: SizedBox.square(
                dimension: 48,
                child: Icon(Icons.info_outline,
                    color: scheme.mutedForeground,
                    semanticLabel: context.l10n.invitedUserRole)),
          ),
        ]),
        _InviteDropdown<HouseholdRole>(
          selectorKey: const ValueKey('invite-role-selector'),
          enabled: state.canEdit,
          value: state.draft.invitedRole,
          options: const [HouseholdRole.admin, HouseholdRole.member],
          label: (role) => role == HouseholdRole.admin
              ? context.l10n.admin
              : context.l10n.member,
          onChanged: controller.setRole,
        ),
        const SizedBox(height: 16),
        Text(context.l10n.linkExpiration,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _InviteDropdown<int>(
          selectorKey: const ValueKey('invite-expiry-selector'),
          enabled: state.canEdit,
          value: state.draft.expiresInDays,
          options: householdInviteExpiryDays,
          label: (days) => _expiryLabel(context, days),
          onChanged: controller.setExpiry,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: ValueKey('invite-message-$userId'),
          initialValue: state.draft.personalMessage,
          enabled: state.canEdit,
          minLines: 1,
          maxLines: 3,
          decoration:
              InputDecoration(labelText: context.l10n.personalMessageOptional),
          onChanged: controller.setMessage,
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
                      onPressed: state.canEdit && userId.isNotEmpty
                          ? controller.create
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
                          onPressed: () async {
                            if (ref.read(currentUserIdProvider) != userId) {
                              return;
                            }
                            try {
                              await Clipboard.setData(
                                  ClipboardData(text: link));
                              if (context.mounted &&
                                  ref.read(currentUserIdProvider) == userId) {
                                AppToast.success(context,
                                    context.l10n.inviteLinkCopiedToClipboard);
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
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
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
            child: Container(
              key: selectorKey,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: scheme.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.controlBorder)),
              child: Row(children: [
                Expanded(
                    child: Text(label(value),
                        style: TextStyle(color: scheme.foreground))),
                Icon(Icons.unfold_more_rounded,
                    color: scheme.mutedForeground, size: 20),
              ]),
            ),
          ),
        ));
  }
}
