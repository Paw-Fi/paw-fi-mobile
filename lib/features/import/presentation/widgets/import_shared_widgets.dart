import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';

/// Truncates a label for display in menus/pills.
String truncateMenuLabel(String label, {int maxLength = 20}) {
  final trimmed = label.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength - 1)}…';
}

/// Extracts the local-part of an email address (before the '@').
String emailLocalPart(String email) {
  final trimmed = email.trim();
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return trimmed;
  return trimmed.substring(0, atIndex);
}

/// Returns a short user label: display name if available, or email (optionally
/// shortened to local-part only).
String userLabel(AppUser user, {required bool shortenEmail}) {
  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;

  return shortenEmail ? emailLocalPart(user.email) : user.email.trim();
}

/// Human-readable label for a known import source app.
String importSourceLabel(ImportSourceApp source) {
  switch (source) {
    case ImportSourceApp.ynab:
      return 'YNAB';
    case ImportSourceApp.monarch:
      return 'Monarch';
    case ImportSourceApp.everyDollar:
      return 'EveryDollar';
    case ImportSourceApp.cashew:
      return 'Cashew';
    case ImportSourceApp.mint:
      return 'Mint';
    case ImportSourceApp.goodbudget:
      return 'Goodbudget';
    case ImportSourceApp.spendee:
      return 'Spendee';
    case ImportSourceApp.other:
      return 'Other';
  }
}

/// Description of what file to upload for a given source app.
String importSourceFileRequest(ImportSourceApp source) {
  switch (source) {
    case ImportSourceApp.ynab:
      return 'Upload YNAB export (CSV/TSV). Note: targets may not transfer.';
    case ImportSourceApp.monarch:
      return 'Upload Transactions CSV (all accounts). Optional: Balance history CSV.';
    case ImportSourceApp.everyDollar:
      return 'Upload one or more monthly Transactions CSV exports.';
    case ImportSourceApp.cashew:
      return 'Upload Cashew Data File backup (preferred).';
    case ImportSourceApp.mint:
      return 'Upload one or more Mint Transactions CSV exports (may require multiple exports).';
    case ImportSourceApp.goodbudget:
      return 'Upload Transactions CSV.';
    case ImportSourceApp.spendee:
      return 'Upload CSV/XLS export (All wallets; free users limited to 365 days).';
    case ImportSourceApp.other:
      return 'Upload a CSV, XLS/XLSX, TXT, or PDF export from your tool.';
  }
}

/// A settings-style grouped section card with a title header and divider-
/// separated children tiles.
class GroupedSectionCard extends StatelessWidget {
  const GroupedSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: scheme.mutedForeground,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: _withDividers(context, children),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(BuildContext context, List<Widget> tiles) {
    final scheme = Theme.of(context).colorScheme;
    final out = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      out.add(tiles[i]);
      if (i < tiles.length - 1) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: scheme.border.withValues(alpha: 0.35),
            ),
          ),
        );
      }
    }
    return out;
  }
}

/// A standard list tile used across multiple import wizard steps.
class StandardTile extends StatelessWidget {
  const StandardTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 20,
                    color: scheme.foreground,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: scheme.foreground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A trailing widget that shows a value with a chevron indicator.
class ValueChevron extends StatelessWidget {
  const ValueChevron({
    super.key,
    required this.value,
    this.isPlaceholder = false,
  });

  final String value;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              color: isPlaceholder
                  ? scheme.mutedForeground
                  : scheme.foreground.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.chevron_right,
          size: 20,
          color: scheme.mutedForeground.withValues(alpha: 0.6),
        ),
      ],
    );
  }
}

/// A red error banner for displaying parse/import errors.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.errorBorder.withValues(alpha: 0.8),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        style: TextStyle(color: scheme.errorAccent),
      ),
    );
  }
}

/// A row with two labelled metric values, side by side.
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.mutedForeground,
                  ),
                ),
                Text(
                  leftValue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: scheme.border.withValues(alpha: 0.5),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rightLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.mutedForeground,
                  ),
                ),
                Text(
                  rightValue,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with an icon, title, and description used for step instructions.
class InstructionCard extends StatelessWidget {
  const InstructionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.mutedForeground,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
