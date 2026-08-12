import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/constants/deep_links.dart';
import 'package:moneko/features/import_review/presentation/providers/import_review_provider.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';
import 'package:moneko/features/import_review/presentation/widgets/import_review_completed_view.dart';
import 'package:moneko/features/import_review/presentation/widgets/import_review_source_card.dart';
import 'package:moneko/features/import_review/presentation/widgets/import_review_transaction_card.dart';

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
          error: (_, __) => _MessageView(
            icon: Icons.error_outline_rounded,
            title: 'Link Unavailable',
            message: 'This review link is unavailable or has expired.',
            color: scheme.error,
          ),
          data: (value) => switch (value.status) {
            'pending' => const _PendingReview(),
            'completed' => ImportReviewCompletedView(
                review: value,
                onClose: () => _closeImportReview(context),
              ),
            _ => _MessageView(
                icon: value.status == 'declined'
                    ? Icons.cancel_outlined
                    : Icons.info_outline_rounded,
                title: _resultTitle(value.status),
                message: _resultText(value.status),
                color: scheme.foreground,
              ),
          },
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
              automaticallyImplyLeading: false,
              title: Text(
                'Review Import',
                style: TextStyle(
                  color: scheme.foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontSize: 34,
                ),
              ),
              backgroundColor: scheme.appBackground,
              surfaceTintColor: scheme.surface.withValues(alpha: 0.0),
              floating: true,
              pinned: true,
              expandedHeight: 120,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'We found some items that need your attention. Please select the correct values to proceed.',
                      style: TextStyle(
                        color: scheme.mutedForeground,
                        fontSize: 17,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (review.source.hasDetails) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ImportReviewSourceCard(source: review.source),
                    ),
                  ],
                  const SizedBox(height: 40),
                  for (var i = 0; i < review.items.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: scheme.surfaceBorder,
                        ),
                      ),
                    _ReviewItemSection(
                      item: review.items[i], 
                      index: i,
                      total: review.items.length,
                    ),
                  ],
                  if (review.submissionError != null) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.errorSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.errorBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: scheme.errorAccent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                review.submissionError!,
                                style: TextStyle(
                                  color: scheme.foreground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
  final int index;
  final int total;

  const _ReviewItemSection({required this.item, required this.index, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDeclined = ref.watch(_declineProvider(item.id));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceBorder,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ITEM ${index + 1} OF $total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: scheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.summary,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: scheme.foreground,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          if (item.transaction.hasDetails) ...[
            const SizedBox(height: 24),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isDeclined ? 0.4 : 1.0,
              child: ImportReviewTransactionCard(transaction: item.transaction),
            ),
          ],
          const SizedBox(height: 32),
          for (var i = 0; i < item.issues.length; i++) ...[
            if (i > 0) const SizedBox(height: 32),
            _IssueSection(issue: item.issues[i], itemId: item.id),
          ],
          const SizedBox(height: 32),
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
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: isDeclined
                    ? scheme.destructive.withValues(alpha: 0.1)
                    : scheme.appBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDeclined
                      ? scheme.destructive.withValues(alpha: 0.2)
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
                          : scheme.mutedForeground,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDeclined ? 'Skipping transaction' : 'Skip this transaction',
                          style: TextStyle(
                            color: isDeclined
                                ? scheme.destructive
                                : scheme.foreground,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDeclined ? 'This will not be imported' : 'Exclude this from the import',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForField(issue.field),
                  size: 16,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _titleForField(issue.field).toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  letterSpacing: 1.2,
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
                  width: 2,
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
                    if (isDeclined) {
                      ref.read(_declineProvider(itemId).notifier).state = false;
                    }
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
          Positioned(
            left: -2,
            top: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              decoration: BoxDecoration(
                color: isSelected
                    ? scheme.primary
                    : scheme.surface.withValues(alpha: 0.0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? scheme.foreground : scheme.mutedForeground,
                          letterSpacing: isSelected ? -0.3 : 0,
                        ),
                        child: Text(choice.label),
                      ),
                      if (choice.evidence.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isSelected
                                ? scheme.mutedForeground
                                : scheme.mutedForeground.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                          child: Text(choice.evidence),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? scheme.primary : scheme.appBackground,
                    border: Border.all(
                      color: isSelected ? scheme.primary : scheme.surfaceBorder,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: scheme.appBackground,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _closeImportReview(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  context.go('/');
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
              backgroundColor: scheme.foreground,
              foregroundColor: scheme.appBackground,
              disabledBackgroundColor: scheme.muted,
              disabledForegroundColor: scheme.mutedForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: isSubmitting
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.appBackground,
                    ),
                  )
                : Text(
                    complete ? 'Submit Review' : 'Complete all items to submit',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
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
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar.large(
          automaticallyImplyLeading: false,
          title: Text(
            'Review Import',
            style: TextStyle(
              color: scheme.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontSize: 34,
            ),
          ),
          backgroundColor: scheme.appBackground,
          expandedHeight: 120,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _ShimmerBox(height: 24, width: double.infinity),
              const SizedBox(height: 8),
              const _ShimmerBox(height: 24, width: 200),
              const SizedBox(height: 48),
              
              const _ShimmerBox(height: 28, width: 140),
              const SizedBox(height: 24),
              const _ShimmerBox(height: 100, width: double.infinity, borderRadius: 20),
              const SizedBox(height: 40),
              
              Row(
                children: [
                  const _ShimmerBox(height: 32, width: 32, borderRadius: 16),
                  const SizedBox(width: 16),
                  const _ShimmerBox(height: 16, width: 120),
                ],
              ),
              const SizedBox(height: 24),
              const _ShimmerBox(height: 80, width: double.infinity, borderRadius: 16),
              const SizedBox(height: 12),
              const _ShimmerBox(height: 80, width: double.infinity, borderRadius: 16),
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
  final double borderRadius;
  const _ShimmerBox({
    required this.height, 
    required this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceBorder,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
  });
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayColor = color ?? scheme.mutedForeground;
    
    return Scaffold(
      backgroundColor: scheme.appBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: displayColor),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.foreground,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: scheme.mutedForeground,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => _closeImportReview(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.foreground,
                    foregroundColor: scheme.appBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
