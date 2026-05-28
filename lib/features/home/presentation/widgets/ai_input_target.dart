import 'package:moneko/core/core.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';

const String aiInputTargetSpaceTypePreferenceKey = 'ai_input_target.space_type';
const String aiInputTargetSpaceHouseholdPreferenceKey =
    'ai_input_target.space_household_id';
const String aiInputTargetWalletPreferencePrefix = 'ai_input_target.wallet';

String aiInputTargetAccountTypeToStorage(ActiveWalletType type) => type.name;

ActiveWalletType? aiInputTargetAccountTypeFromStorage(String? value) {
  for (final type in ActiveWalletType.values) {
    if (type.name == value) return type;
  }
  return null;
}

String aiInputTargetWalletPreferenceKey({
  required ActiveWalletType accountType,
  required String? householdId,
  required String currency,
}) {
  final scope = accountType == ActiveWalletType.personal
      ? 'personal'
      : '${accountType.name}:${householdId ?? ''}';
  return '$aiInputTargetWalletPreferencePrefix.$scope.${currency.trim().toUpperCase()}';
}

class AiInputTarget {
  const AiInputTarget({
    required this.accountType,
    required this.householdId,
    required this.isPortfolio,
    required this.accountId,
    required this.accountCurrency,
    this.spaceLabel,
  });

  final ActiveWalletType accountType;
  final String? householdId;
  final bool isPortfolio;
  final String? accountId;
  final String? accountCurrency;
  final String? spaceLabel;
}
