import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/import_review/domain/import_review_models.dart';

class ImportReviewSourceCard extends StatelessWidget {
  const ImportReviewSourceCard({super.key, required this.source});

  final ImportReviewSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final receivedAt = source.receivedAt;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.appBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.surfaceBorder.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.importReviewSourceTitle.toUpperCase(),
            style: TextStyle(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          if (source.subjectLine != null) ...[
            const SizedBox(height: 12),
            Text(
              source.subjectLine!,
              style: TextStyle(
                color: scheme.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
          ],
          if (source.senderEmail != null) ...[
            const SizedBox(height: 6),
            Text(
              source.senderEmail!,
              style: TextStyle(
                color: scheme.mutedForeground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          
          if (receivedAt != null || source.files.isNotEmpty) ...[
            const SizedBox(height: 32),
            if (receivedAt != null) ...[
              Text(
                'Received ${_formatDate(receivedAt)}',
                style: TextStyle(
                  color: scheme.mutedForeground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (receivedAt != null && source.files.isNotEmpty)
              const SizedBox(height: 16),
            if (source.files.isNotEmpty) ...[
              for (var i = 0; i < source.files.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: scheme.surfaceBorder),
                  const SizedBox(height: 12),
                ],
                _FileRow(file: source.files[i]),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final ImportReviewSourceFile file;

  const _FileRow({required this.file});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFailed = file.status == 'failed';
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isFailed ? scheme.error : scheme.foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFailed ? 'Could not read file' : '${file.transactionCount} transactions found',
                style: TextStyle(
                  color: isFailed ? scheme.error.withValues(alpha: 0.8) : scheme.mutedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
