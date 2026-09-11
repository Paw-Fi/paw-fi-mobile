import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/pockets/presentation/pages/pockets_ai_budget_suggestions_page.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';


class PocketsAiBudgetSuggestionsSheet extends StatelessWidget {
  const PocketsAiBudgetSuggestionsSheet({
    super.key,
    required this.scopeParams,
    required this.currency,
  });

  final PocketsScopeParams scopeParams;
  final String currency;

  static Future<void> show({
    required BuildContext context,
    required PocketsScopeParams scopeParams,
    required String currency,
  }) =>
      PocketsAiBudgetSuggestionsPage.open(
        context,
        scopeParams: scopeParams,
        currency: currency,
      );

  static Future<void> showIfEntitled({
    required BuildContext context,
    required WidgetRef ref,
    required PocketsScopeParams scopeParams,
    required String currency,
  }) =>
      PocketsAiBudgetSuggestionsPage.openIfEntitled(
        context,
        ref,
        scopeParams: scopeParams,
        currency: currency,
      );

  @override
  Widget build(BuildContext context) {
    return PocketsAiBudgetSuggestionsPage(
      scopeParams: scopeParams,
      currency: currency,
    );
  }
}
