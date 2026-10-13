import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/auth/auth.dart';
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../utils/invite_link_utils.dart';

class HouseholdInviteLinks extends ConsumerStatefulWidget {
  const HouseholdInviteLinks({
    super.key,
    required this.userId,
    required this.householdId,
    required this.onCreate,
    this.confirmedLink,
  });

  final String householdId;
  final String userId;
  final VoidCallback? onCreate;
  final String? confirmedLink;

  @override
  ConsumerState<HouseholdInviteLinks> createState() =>
      _HouseholdInviteLinksState();
}

class _HouseholdInviteLinksState extends ConsumerState<HouseholdInviteLinks> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(currentUserIdProvider) != widget.userId) return;
      final provider = householdInvitesProvider(widget.householdId);
      if (ref.read(provider).hasValue && !ref.read(provider).isLoading) {
        unawaited(ref.read(provider.notifier).load());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final householdId = widget.householdId;
    final confirmedLink = widget.confirmedLink;
    final invites = ref.watch(householdInvitesProvider(householdId));
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(context.l10n.savedInviteLinks.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: scheme.mutedForeground)),
              TextButton.icon(
                onPressed: widget.onCreate,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.l10n.createNewInviteLink,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 2,
            child: invites.isLoading && invites.hasValue
                ? LinearProgressIndicator(
                    color: scheme.primary,
                    backgroundColor: scheme.sheetElementBackground)
                : null,
          ),
          const SizedBox(height: 10),
          invites.when(
            skipLoadingOnReload: true,
            data: (rows) {
              final now = DateTime.now();
              final available = rows
                  .where((invite) =>
                      invite.status == InviteStatus.pending &&
                      (invite.expiresAt == null ||
                          invite.expiresAt!.isAfter(now)))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              // A confirmed create remains copyable if its list refresh failed.
              final missingConfirmedLink = confirmedLink != null &&
                  !rows.any((invite) =>
                      buildInviteLink(invite.token) == confirmedLink);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (missingConfirmedLink)
                    _InviteLinkCard(url: confirmedLink, userId: widget.userId),
                  if (available.isEmpty && !missingConfirmedLink)
                    _emptyState(context),
                  for (final invite in available)
                    _InviteLinkCard(
                        key: ValueKey(invite.id),
                        userId: widget.userId,
                        url: buildInviteLink(invite.token),
                        invite: invite),
                ],
              );
            },
            loading: () => _skeleton(context),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (confirmedLink != null)
                  _InviteLinkCard(url: confirmedLink, userId: widget.userId),
                Text(ErrorHandler.getUserFriendlyMessage(error),
                    style: TextStyle(color: scheme.destructive)),
                TextButton.icon(
                  onPressed: () => ref
                      .read(householdInvitesProvider(householdId).notifier)
                      .load(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        Icon(Icons.link_rounded, size: 32, color: scheme.mutedForeground),
        const SizedBox(height: 12),
        Text(context.l10n.noAvailableInviteLinks,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.mutedForeground,
                fontSize: 12,
                fontWeight: FontWeight.w400)),
      ]),
    );
  }

  Widget _skeleton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Skeletonizer(
      effect: ShimmerEffect(
          baseColor: scheme.skeletonBase,
          highlightColor: scheme.skeletonHighlight),
      child: Column(children: [
        for (var index = 0; index < 2; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: scheme.card,
                boxShadow: scheme.groupedCardShadows,
                borderRadius: BorderRadius.circular(10)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Bone.text(words: 3)),
                  SizedBox(width: 16),
                  Bone.square(size: 40)
                ]),
                SizedBox(height: 12),
                Bone.text(words: 4),
                SizedBox(height: 12),
                Bone.text(words: 5),
              ],
            ),
          ),
      ]),
    );
  }
}

class _InviteLinkCard extends ConsumerWidget {
  const _InviteLinkCard(
      {super.key, required this.url, required this.userId, this.invite});
  final String url;
  final String userId;
  final HouseholdInvite? invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final row = invite;
    final isActorActive = ref.watch(currentUserIdProvider) == userId;
    final role = row?.invitedRole == HouseholdRole.member
        ? context.l10n.member
        : context.l10n.admin;
    final localizations = MaterialLocalizations.of(context);
    String dateLabel(DateTime date) {
      final local = date.toLocal();
      return '${localizations.formatMediumDate(local)} '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: BorderRadius.circular(10),
        boxShadow: scheme.groupedCardShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(
                    row == null || row.isReusable
                        ? context.l10n.groupInviteLink
                        : context.l10n.invitationLink,
                    style: theme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w400))),
            const SizedBox(width: 12),
            IconButton(
              tooltip: context.l10n.copyLink,
              style: IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  foregroundColor: scheme.primary),
              onPressed: !isActorActive
                  ? null
                  : () async {
                      if (ref.read(currentUserIdProvider) != userId) return;
                      if (row?.expiresAt != null &&
                          !row!.expiresAt!.isAfter(DateTime.now())) {
                        AppToast.error(context, context.l10n.expired);
                        return;
                      }
                      try {
                        await Clipboard.setData(ClipboardData(text: url));
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
              icon: const Icon(Icons.copy_rounded, size: 20),
            ),
          ]),
          const SizedBox(height: 8),
          Text(url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: theme.bodySmall?.copyWith(
                  color: scheme.mutedForeground,
                  fontSize: 12,
                  fontWeight: FontWeight.w400)),
          if (row != null) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${context.l10n.invitedUserRole}: $role',
                    style: theme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w400)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
                row.expiresAt == null
                    ? context.l10n.inviteNeverExpires
                    : '${context.l10n.expires}: ${dateLabel(row.expiresAt!)}',
                style: theme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
            const SizedBox(height: 6),
            Text('${context.l10n.created}: ${dateLabel(row.createdAt)}',
                style: theme.bodySmall?.copyWith(
                    color: scheme.mutedForeground,
                    fontSize: 12,
                    fontWeight: FontWeight.w400)),
            if (row.invitedEmail?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(row.invitedEmail!,
                  style: theme.bodySmall?.copyWith(
                      color: scheme.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w400)),
            ],
            if (row.personalMessage?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: scheme.sheetBorder),
              const SizedBox(height: 12),
              Text(row.personalMessage!,
                  style: theme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      height: 1.5,
                      fontSize: 14,
                      fontWeight: FontWeight.w400)),
            ],
          ],
        ],
      ),
    );
  }
}
