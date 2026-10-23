import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Display-only view of a `households-validate-invite` response.
class HouseholdInvitePreviewData {
  const HouseholdInvitePreviewData({
    required this.householdName,
    required this.inviterLabel,
    this.coverImageUrl,
    this.inviterAvatarUrl,
    this.personalMessage,
    this.expiresAt,
    this.invitedRole,
  });

  factory HouseholdInvitePreviewData.fromValidation(
    Map<String, dynamic> response, {
    required String fallbackHouseholdName,
    required String fallbackInviterLabel,
  }) {
    final household = _map(response['household']);
    final inviter = _map(response['inviter']);
    final invite = _map(response['invite']);
    return HouseholdInvitePreviewData(
      householdName: _text(household?['name']) ?? fallbackHouseholdName,
      inviterLabel: _text(inviter?['full_name']) ??
          _text(inviter?['email']) ??
          fallbackInviterLabel,
      coverImageUrl: _text(household?['cover_image_url']),
      inviterAvatarUrl: _text(inviter?['avatar_url']),
      personalMessage: _text(invite?['personal_message']),
      // The backend sends a UTC instant; show it in the user's local time.
      expiresAt:
          DateTime.tryParse(_text(response['expires_at']) ?? '')?.toLocal(),
      invitedRole: _text(invite?['invited_role']),
    );
  }

  final String householdName;
  final String inviterLabel;
  final String? coverImageUrl;
  final String? inviterAvatarUrl;
  final String? personalMessage;
  final DateTime? expiresAt;
  final String? invitedRole;

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// Cover image, Space name, inviter and role — what a user needs to recognise
/// the Space before joining.
class HouseholdInvitePreviewCard extends StatelessWidget {
  const HouseholdInvitePreviewCard({super.key, required this.preview});

  final HouseholdInvitePreviewData preview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final role = _roleLabel(context, preview.invitedRole);

    return Semantics(
      label: context.l10n
          .householdPreview(preview.householdName, preview.inviterLabel),
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.primary.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.12),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            _CoverImage(url: preview.coverImageUrl),
            const SizedBox(height: 24),
            Text(
              preview.householdName,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _InviterPill(
              label: context.l10n.invitedBy(preview.inviterLabel),
              avatarUrl: preview.inviterAvatarUrl,
            ),
            if (role != null) ...[
              const SizedBox(height: 10),
              Text(
                context.l10n.invitationJoinAsRole(role),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _roleLabel(BuildContext context, String? role) =>
      switch (role?.toLowerCase()) {
        'admin' => context.l10n.admin,
        'member' => context.l10n.member,
        _ => null,
      };
}

class HouseholdInviteMessageCard extends StatelessWidget {
  const HouseholdInviteMessageCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.personalMessageFromInviter,
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: colorScheme.mutedForeground, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.messageFromInviter,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"$message"',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.foreground.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HouseholdInviteExpiryCard extends StatelessWidget {
  const HouseholdInviteExpiryCard({super.key, required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final daysUntilExpiry = householdInviteCalendarDaysUntil(expiresAt);
    final isExpiringSoon = daysUntilExpiry <= 2;
    final formatted = formatHouseholdInviteDate(context, expiresAt);

    return Semantics(
      label: isExpiringSoon
          ? context.l10n.invitationExpiresSoon(formatted)
          : context.l10n.invitationValidUntil(formatted),
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isExpiringSoon
              ? colorScheme.warning.withValues(alpha: 0.1)
              : colorScheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpiringSoon
                ? colorScheme.warning.withValues(alpha: 0.3)
                : colorScheme.border.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpiringSoon
                  ? Icons.warning_amber_rounded
                  : Icons.schedule_rounded,
              color: isExpiringSoon
                  ? colorScheme.warning
                  : colorScheme.foreground.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExpiringSoon
                        ? context.l10n.expiresSoon
                        : context.l10n.invitationValidUntilLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatted,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whole local calendar days from [now] to [date] (0 = today, 1 = tomorrow),
/// so 11pm → 1am the next day counts as tomorrow rather than today.
int householdInviteCalendarDaysUntil(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  // UTC midnights avoid 23/25-hour days across daylight-saving changes.
  return DateTime.utc(local.year, local.month, local.day)
      .difference(DateTime.utc(today.year, today.month, today.day))
      .inDays;
}

String formatHouseholdInviteDate(
  BuildContext context,
  DateTime date, {
  DateTime? now,
}) {
  final local = date.toLocal();
  final days = householdInviteCalendarDaysUntil(local, now: now);
  if (days == 0) return context.l10n.today;
  if (days == 1) return context.l10n.tomorrow;
  if (days > 1 && days < 7) return context.l10n.inDays(days);
  final months = [
    context.l10n.january,
    context.l10n.february,
    context.l10n.march,
    context.l10n.april,
    context.l10n.may,
    context.l10n.june,
    context.l10n.july,
    context.l10n.august,
    context.l10n.september,
    context.l10n.october,
    context.l10n.november,
    context.l10n.december,
  ];
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colorScheme.primary.withValues(alpha: 0.2),
      child: Center(
        child: Icon(Icons.home_rounded, size: 48, color: colorScheme.primary),
      ),
    );
    final imageUrl = url;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: imageUrl == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  child: const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _InviterPill extends StatelessWidget {
  const _InviterPill({required this.label, this.avatarUrl});

  final String label;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.foreground.withValues(alpha: 0.7);
    final icon = Icon(Icons.person_outline_rounded, size: 16, color: mutedText);
    final avatar = avatarUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 20,
            child: avatar == null
                ? icon
                : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => icon,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: mutedText,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
