import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/constants/deep_links.dart';
import 'package:moneko/features/import_review/presentation/providers/import_review_provider.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';

class ImportReviewPage extends StatelessWidget {
  const ImportReviewPage(
      {super.key, required this.reviewId, required this.token});

  final String reviewId;
  final String token;

  @override
  Widget build(BuildContext context) {
    if (!DeepLinks.isValidImportReviewId(reviewId) ||
        !DeepLinks.isValidImportReviewSecret(token)) {
      return const Scaffold(
        body: _MessageView(
          icon: Icons.error_outline_rounded,
          title: 'Link Unavailable',
          message: 'This review link is unavailable or has expired.',
        ),
      );
    }
    final launch = ImportReviewLaunch(reviewId: reviewId, token: token);
    return ProviderScope(
      overrides: [importReviewLaunchProvider.overrideWithValue(launch)],
      child: const _ImportReviewContent(),
    );
  }
}

class _ImportReviewContent extends ConsumerWidget {
  const _ImportReviewContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(importReviewProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.appBackground,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: review.when(
          loading: () => const _ReviewSkeleton(),
          error: (_, __) => const _MessageView(
            icon: Icons.error_outline_rounded,
            title: 'Link Unavailable',
            message: 'This review link is unavailable or has expired.',
          ),
          data: (value) => value.status == 'pending'
              ? const _PendingReview()
              : _MessageView(
                  icon: value.status == 'completed'
                      ? Icons.check_circle_outline_rounded
                      : (value.status == 'declined'
                          ? Icons.cancel_outlined
                          : Icons.info_outline_rounded),
                  title: _resultTitle(value.status),
                  message: _resultText(value.status),
                ),
        ),
      ),
    );
  }
}

final _selectionProvider = StateProvider.autoDispose
    .family<List<String>, String>((ref, key) => const []);
final _declineProvider =
    StateProvider.autoDispose.family<bool, String>((ref, itemId) => false);

String? _selectedValue(WidgetRef ref, String key) {
  final values = ref.watch(_selectionProvider(key));
  return values.isEmpty ? null : values.first;
}

class _PendingReview extends ConsumerWidget {
  const _PendingReview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(importReviewProvider).requireValue;
    final complete = review.items.every((item) =>
        ref.watch(_declineProvider(item.id)) ||
        item.issues.every((issue) => ref
            .watch(_selectionProvider('${item.id}:${issue.field}'))
            .isNotEmpty));
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(
                'Review Import',
                style: TextStyle(
                  color: scheme.foreground,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              backgroundColor: scheme.appBackground,
              surfaceTintColor: scheme.surface.withValues(alpha: 0.0),
              floating: true,
              pinned: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'We found some items that need your attention. Please select the correct values to proceed.',
                      style: TextStyle(
                        color: scheme.mutedForeground,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  for (var i = 0; i < review.items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 48,
                        thickness: 1,
                        color: scheme.surfaceBorder,
                      ),
                    _ReviewItemSection(item: review.items[i]),
                  ],
                  if (review.submissionError != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        review.submissionError!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _BottomActionBar(
            complete: complete,
            isSubmitting: review.isSubmitting,
            onPressed: complete && !review.isSubmitting
                ? () => ref.read(importReviewProvider.notifier).submit({
                      for (final item in review.items)
                        item.id: ref.read(_declineProvider(item.id))
                            ? null
                            : item.issues
                                .expand((issue) => ref.read(_selectionProvider(
                                    '${item.id}:${issue.field}')))
                                .toList(),
                    })
                : null,
          ),
        ),
      ],
    );
  }
}

class _ReviewItemSection extends ConsumerWidget {
  final ImportReviewItem item;

  const _ReviewItemSection({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDeclined = ref.watch(_declineProvider(item.id));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.summary,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: scheme.foreground,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < item.issues.length; i++) ...[
            if (i > 0) const SizedBox(height: 32),
            _IssueSection(issue: item.issues[i], itemId: item.id),
          ],
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              final newValue = !isDeclined;
              ref.read(_declineProvider(item.id).notifier).state = newValue;
              if (newValue) {
                for (final issue in item.issues) {
                  ref
                      .read(_selectionProvider('${item.id}:${issue.field}')
                          .notifier)
                      .state = const [];
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: isDeclined
                    ? scheme.destructive.withValues(alpha: 0.1)
                    : scheme.surface.withValues(alpha: 0.0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDeclined
                      ? scheme.destructive.withValues(alpha: 0.3)
                      : scheme.surfaceBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      isDeclined
                          ? Icons.block_rounded
                          : Icons.do_not_disturb_alt_rounded,
                      key: ValueKey(isDeclined),
                      color: isDeclined
                          ? scheme.destructive
                          : scheme.mutedForeground.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Skip this transaction',
                          style: TextStyle(
                            color: isDeclined
                                ? scheme.destructive
                                : scheme.foreground,
                            fontWeight:
                                isDeclined ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exclude this from the import',
                          style: TextStyle(
                            color: isDeclined
                                ? scheme.destructive.withValues(alpha: 0.8)
                                : scheme.mutedForeground,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueSection extends ConsumerWidget {
  final ImportReviewIssue issue;
  final String itemId;

  const _IssueSection({required this.issue, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selectionKey = '$itemId:${issue.field}';
    final selectedValue = _selectedValue(ref, selectionKey);
    final isDeclined = ref.watch(_declineProvider(itemId));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDeclined ? 0.4 : 1.0,
      child: IgnorePointer(
        ignoring: isDeclined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForField(issue.field),
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _titleForField(issue.field).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: scheme.surfaceBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: issue.choices.map((choice) {
                  final isSelected = selectedValue == choice.id;
                  return _ChoiceRow(
                    choice: choice,
                    isSelected: isSelected,
                    onTap: () {
                      if (isDeclined) return;
                      ref
                          .read(_selectionProvider(selectionKey).notifier)
                          .state = [choice.id];
                    },
                  );
                }).toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForField(String field) {
    switch (field.toLowerCase()) {
      case 'account':
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'category':
        return Icons.category_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _titleForField(String field) {
    switch (field.toLowerCase()) {
      case 'account':
        return 'Select Account';
      case 'category':
        return 'Select Category';
      default:
        return field;
    }
  }
}

class _ChoiceRow extends StatelessWidget {
  final ImportReviewChoice choice;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.choice,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Indicator line
          Positioned(
            left: -1,
            top: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 3,
              color: isSelected
                  ? scheme.primary
                  : scheme.surface.withValues(alpha: 0.0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color:
                        isSelected ? scheme.foreground : scheme.mutedForeground,
                  ),
                  child: Text(choice.label),
                ),
                if (choice.evidence.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? scheme.mutedForeground
                          : scheme.mutedForeground.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                    child: Text(choice.evidence),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool complete;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  const _BottomActionBar({
    required this.complete,
    required this.isSubmitting,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: scheme.appBackground,
        border: Border(
          top: BorderSide(
            color: scheme.surfaceBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              disabledBackgroundColor: scheme.primary.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              isSubmitting ? 'Importing...' : 'Confirm and import',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: complete
                    ? scheme.buttonText
                    : scheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(
            'Review Import',
            style: TextStyle(
              color: scheme.foreground,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          backgroundColor: scheme.appBackground,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _ShimmerBox(height: 20, width: 200),
              const SizedBox(height: 32),
              const _ShimmerBox(height: 24, width: 150),
              const SizedBox(height: 16),
              const _ShimmerBox(height: 16, width: 100),
              const SizedBox(height: 12),
              const _ShimmerBox(height: 80, width: double.infinity),
              const SizedBox(height: 12),
              const _ShimmerBox(height: 80, width: double.infinity),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double width;
  const _ShimmerBox({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceBorder,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(
            title,
            style: TextStyle(
              color: scheme.foreground,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          backgroundColor: scheme.appBackground,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: scheme.mutedForeground),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme.mutedForeground,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _resultTitle(String status) => switch (status) {
      'completed' => 'Import Complete',
      'declined' => 'Import Declined',
      'expired' => 'Link Expired',
      'failed' => 'Import Failed',
      _ => 'Processing...',
    };

String _resultText(String status) => switch (status) {
      'completed' => 'Your reviewed transaction was imported successfully.',
      'declined' => 'This transaction was not imported.',
      'expired' => 'This review link has expired and is no longer valid.',
      'failed' => 'This transaction could not be imported.',
      _ => 'This review is being processed. Please wait.',
    };
