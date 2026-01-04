import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/domain/entities/pocket_envelope.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/pockets/presentation/widgets/uncategorized_spending_sheet.dart';

class UncategorizedBanner extends StatelessWidget {
  const UncategorizedBanner({
    super.key,
    required this.colorScheme,
    required this.currency,
    required this.uncategorized,
    required this.uncategorizedExpenses,
    required this.availablePockets,
    required this.onAssignCategory,
  });

  final ColorScheme colorScheme;
  final String currency;
  final List<UncategorizedCategory> uncategorized;
  final Map<String, List<Map<String, dynamic>>> uncategorizedExpenses;
  final List<PocketEnvelope> availablePockets;
  final Function(String, String) onAssignCategory;

  @override
  Widget build(BuildContext context) {
    final total = uncategorized.fold<double>(0.0, (sum, e) => sum + e.amount);
    final normalized = double.parse(formatAmount(total));
    final symbol = resolveCurrencySymbol(currency);
    final localized = formatLocalizedNumber(context, normalized);
    final totalDisplay = '$symbol$localized';
    return GestureDetector(
        onTap: () => showUncategorizedSheet(
              context,
              colorScheme,
              currency,
              uncategorized,
              availablePockets,
              onAssignCategory,
              uncategorizedExpenses: uncategorizedExpenses,
            ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.pocketUncategorizedSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.pocketUncategorizedBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.pocketUncategorizedIconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.pocketUncategorizedAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                          fontFamily: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.fontFamily,
                        ),
                        children: [
                          TextSpan(
                            text: totalDisplay,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.pocketUncategorizedAmount,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: context.l10n.unallocatedSpendLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.unallocatedBannerDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
            ],
          ),
        ));
  }
}
