import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/home/presentation/widgets/transactions_browser.dart';

class HouseholdExpensesPage extends ConsumerWidget {
  final Household household;
  const HouseholdExpensesPage({super.key, required this.household});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = HouseholdExpensesParams(householdId: household.id, limit: 1000);
    final expensesAsync = ref.watch(householdExpensesProvider(params));
    final selectedCurrency = ref.watch(homeFilterProvider).selectedCurrency; // may be null

    return expensesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        body: Center(child: Text('${context.l10n.failedToLoadHouseholdTransactions}: $e')),
      ),
      data: (transactions) {
        return TransactionsBrowser(
          transactions: transactions,
          selectedCurrency: selectedCurrency,
          onRefresh: () async {
            ref.invalidate(householdExpensesProvider(params));
          },
          title: context.l10n.transactions,
          onBack: () => Navigator.of(context).maybePop(),
          showTypeChips: true,
        );
      },
    );
  }
}
