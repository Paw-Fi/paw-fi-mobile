import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/pockets/presentation/widgets/uncategorized_spending_sheet.dart';

class UncategorizedBanner extends StatelessWidget {
  const UncategorizedBanner({
    super.key,
    required this.colorScheme,
    required this.currency,
    required this.uncategorized,
    required this.uncategorizedExpenses,
  });

  final ColorScheme colorScheme;
  final String currency;
  final List<UncategorizedCategory> uncategorized;
  final Map<String, List<Map<String, dynamic>>> uncategorizedExpenses;

  @override
  Widget build(BuildContext context) {
    final total = uncategorized.fold<double>(0.0, (sum, e) => sum + e.amount);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
        onTap: () => showUncategorizedSheet(
              context,
              colorScheme,
              currency,
              uncategorized,
              uncategorizedExpenses: uncategorizedExpenses,
            ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(
                    0xFF2C1C10) // Very dark orange/brown for dark mode
                : const Color(0xFFFFF8F0), // Very light orange for light mode
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
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
                            text: formatCurrency(total, currency),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.orange.shade200
                                  : Colors.orange.shade800,
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
