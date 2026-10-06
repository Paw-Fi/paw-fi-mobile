import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/theme/moneko_text_scaling.dart';
import 'package:moneko/features/subscription/data/models/app_store_reviews.dart';

class AppStoreReviewCard extends StatelessWidget {
  const AppStoreReviewCard({
    super.key,
    required this.review,
    this.margin,
    this.plusIntro = false,
  });

  final bool plusIntro;
  final AppStoreReview review;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final title = Text(review.title,
        style: TextStyle(
          fontSize: plusIntro ? 14 : 16,
          fontWeight: FontWeight.w700,
          color: plusIntro
              ? colorScheme.plusIntroForeground
              : colorScheme.onSurface,
        ));
    final date = plusIntro
        ? Text(
            DateFormat.MMMd(Localizations.localeOf(context).toString())
                .format(DateTime.parse(review.createdDate.substring(0, 10))),
            style: TextStyle(
                fontSize: 12,
                color: colorScheme.plusIntroForeground.withValues(alpha: 0.8)),
          )
        : null;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: plusIntro
            ? colorScheme.plusIntroSurface.withValues(alpha: 0.45)
            : colorScheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plusIntro
              ? colorScheme.plusIntroForeground.withValues(alpha: 0)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MonekoTextScale.isAtLeast(context, 1.5))
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              title,
              if (date != null) ...[const SizedBox(height: 4), date],
            ])
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: title),
              if (date != null) ...[
                const SizedBox(width: 12),
                Flexible(child: date)
              ],
            ]),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(
                  review.rating,
                  (index) => Icon(
                    Icons.star_rounded,
                    color: colorScheme.warning,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                  child: Text(
                review.reviewerNickname,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  color: plusIntro
                      ? colorScheme.plusIntroForeground.withValues(alpha: 0.8)
                      : colorScheme.mutedForeground,
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: (plusIntro
                      ? colorScheme.plusIntroForeground
                      : colorScheme.onSurface)
                  .withValues(alpha: plusIntro ? 0.9 : 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
