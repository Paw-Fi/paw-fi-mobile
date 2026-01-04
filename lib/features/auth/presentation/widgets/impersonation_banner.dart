import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/data/services/impersonation_service.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// Banner that appears when admin is impersonating a user
class ImpersonationBanner extends ConsumerWidget {
  const ImpersonationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impersonation = ref.watch(impersonationProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final warningBase = colorScheme.warning;
    final warningBackground = colorScheme.warningSurface;
    final warningBorder = colorScheme.warningBorder;

    if (!impersonation.isImpersonating) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: warningBackground,
        border: Border(
          bottom: BorderSide(
            color: warningBorder,
            width: 2,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: warningBase,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'IMPERSONATING USER',
                    style: TextStyle(
                      color: warningBase,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    impersonation.impersonatedEmail ?? '',
                    style: TextStyle(
                      color: warningBase.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(impersonationProvider.notifier).stopImpersonation();
              },
              style: TextButton.styleFrom(
                foregroundColor: warningBase,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text(
                'EXIT',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
