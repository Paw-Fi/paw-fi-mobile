import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/import_review/presentation/providers/import_review_provider.dart';

class ImportReviewPage extends ConsumerWidget {
  const ImportReviewPage(
      {super.key, required this.reviewId, required this.token});

  final String reviewId;
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launch = ImportReviewLaunch(reviewId: reviewId, token: token);
    final review = ref.watch(importReviewProvider(launch));
    return Scaffold(
      appBar: AppBar(title: const Text('Review import')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: review.when(
          loading: () => const _ReviewSkeleton(),
          error: (_, __) =>
              const Center(child: Text('This review link is unavailable.')),
          data: (value) => value.status == 'pending'
              ? _PendingReview(launch: launch)
              : Center(child: Text(_resultText(value.status))),
        ),
      ),
    );
  }
}

final _selectionProvider = StateProvider.autoDispose
    .family<List<String>, String>((ref, key) => const []);

class _PendingReview extends ConsumerWidget {
  const _PendingReview({required this.launch});
  final ImportReviewLaunch launch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final review = ref.watch(importReviewProvider(launch)).requireValue;
    final complete = review.items.every((item) => item.issues.every((issue) =>
        ref.watch(_selectionProvider('${item.id}:${issue.field}')).isNotEmpty));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Choose the values supported by your import.'),
        const SizedBox(height: 16),
        for (final item in review.items) ...[
          Text(item.summary, style: Theme.of(context).textTheme.titleMedium),
          for (final issue in item.issues)
            RadioGroup<String>(
              groupValue: _selectedValue(ref, '${item.id}:${issue.field}'),
              onChanged: (value) => ref
                  .read(
                      _selectionProvider('${item.id}:${issue.field}').notifier)
                  .state = value == null ? const [] : [value],
              child: Column(
                children: issue.choices
                    .map((choice) => RadioListTile<String>(
                          value: choice.id,
                          title: Text(choice.label),
                          subtitle: Text(choice.evidence),
                        ))
                    .toList(growable: false),
              ),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: complete
              ? () => ref.read(importReviewProvider(launch).notifier).submit({
                    for (final item in review.items)
                      item.id: item.issues
                          .expand((issue) => ref.read(
                              _selectionProvider('${item.id}:${issue.field}')))
                          .toList(),
                  })
              : null,
          child: const Text('Confirm and import'),
        ),
      ],
    );
  }
}

String? _selectedValue(WidgetRef ref, String key) {
  final values = ref.watch(_selectionProvider(key));
  return values.isEmpty ? null : values.first;
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 24, child: Card()),
          SizedBox(height: 16),
          SizedBox(height: 96, child: Card()),
          SizedBox(height: 16),
          SizedBox(height: 48, child: Card()),
        ]),
      );
}

String _resultText(String status) => switch (status) {
      'completed' => 'Your reviewed transaction was imported.',
      'declined' => 'This transaction was not imported.',
      'expired' => 'This review link has expired.',
      _ => 'This review is being processed.',
    };
