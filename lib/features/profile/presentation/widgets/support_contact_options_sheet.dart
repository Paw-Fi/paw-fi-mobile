import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';

enum SupportContactOption { reddit, ticket }

class SupportContactOptionsSheet extends StatelessWidget {
  const SupportContactOptionsSheet({super.key});

  static Future<SupportContactOption?> show(BuildContext context) {
    return MonekoBottomSheet.show<SupportContactOption>(
      context: context,
      builder: (_) => const SupportContactOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.support,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.supportContactOptionsDescription,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            _SupportContactOptionTile(
              icon: SvgPicture.asset(
                'lib/assets/social-media/reddit.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              title: context.l10n.askOnReddit,
              description: context.l10n.askOnRedditDescription,
              onTap: () => Navigator.of(context).pop(
                SupportContactOption.reddit,
              ),
            ),
            const SizedBox(height: 12),
            _SupportContactOptionTile(
              icon: Icon(
                Icons.confirmation_number_outlined,
                color: colorScheme.primary,
              ),
              title: context.l10n.submitATicket,
              description: context.l10n.submitATicketDescription,
              onTap: () => Navigator.of(context).pop(
                SupportContactOption.ticket,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportContactOptionTile extends StatelessWidget {
  const _SupportContactOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
