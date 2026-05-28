import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/utils/ai_input_wallet_filter.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

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

class AiInputTargetSelection {
  const AiInputTargetSelection({
    required this.accountType,
    required this.householdId,
    required this.walletId,
    required this.hasManuallySelectedWallet,
  });

  final ActiveWalletType accountType;
  final String? householdId;
  final String? walletId;
  final bool hasManuallySelectedWallet;
}

AiInputTargetSelection resolveInitialAiInputTargetSelection(
  WidgetRef ref, {
  AiInputTarget? initialTarget,
}) {
  if (initialTarget != null) {
    return AiInputTargetSelection(
      accountType: initialTarget.accountType,
      householdId: initialTarget.accountType == ActiveWalletType.personal
          ? null
          : initialTarget.householdId,
      walletId: initialTarget.accountId,
      hasManuallySelectedWallet: initialTarget.accountId != null,
    );
  }

  final scope = ref.read(householdScopeProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final savedType = aiInputTargetAccountTypeFromStorage(
    prefs.getString(aiInputTargetSpaceTypePreferenceKey),
  );
  var accountType = savedType ?? scope.activeAccountType;
  var householdId = accountType == ActiveWalletType.personal
      ? null
      : savedType == null
          ? scope.activeAccountHouseholdId
          : prefs.getString(aiInputTargetSpaceHouseholdPreferenceKey);
  if (accountType != ActiveWalletType.personal &&
      (householdId == null || householdId.isEmpty)) {
    accountType = scope.activeAccountType;
    householdId = accountType == ActiveWalletType.personal
        ? null
        : scope.activeAccountHouseholdId;
  }

  return AiInputTargetSelection(
    accountType: accountType,
    householdId: householdId,
    walletId: null,
    hasManuallySelectedWallet: false,
  );
}

String? resolveAiInputTargetSavedWalletId(
  WidgetRef ref, {
  required ActiveWalletType accountType,
  required String? householdId,
}) {
  return ref.read(sharedPreferencesProvider).getString(
        aiInputTargetWalletPreferenceKey(
          accountType: accountType,
          householdId:
              accountType == ActiveWalletType.personal ? null : householdId,
          currency: ref.read(selectedHomeCurrencyCodeProvider),
        ),
      );
}

String? resolveAiInputTargetDefaultWalletId(Iterable<WalletEntity> wallets) {
  for (final wallet in wallets) {
    if (wallet.isDefault) return wallet.id;
  }
  return wallets.isNotEmpty ? wallets.first.id : null;
}

String? resolveAiInputTargetWalletId(
  WidgetRef ref, {
  required ActiveWalletType accountType,
  required String? householdId,
  required Iterable<WalletEntity> wallets,
  required String? selectedWalletId,
}) {
  if (selectedWalletId != null &&
      wallets.any((wallet) => wallet.id == selectedWalletId)) {
    return selectedWalletId;
  }

  final savedWalletId = resolveAiInputTargetSavedWalletId(
    ref,
    accountType: accountType,
    householdId: householdId,
  );
  if (savedWalletId != null &&
      wallets.any((wallet) => wallet.id == savedWalletId)) {
    return savedWalletId;
  }

  return resolveAiInputTargetDefaultWalletId(wallets);
}

WalletEntity? resolveAiInputTargetWallet(
  Iterable<WalletEntity> wallets,
  String? walletId,
) {
  for (final wallet in wallets) {
    if (wallet.id == walletId) return wallet;
  }
  return null;
}

AiInputTarget buildAiInputTargetFromSelection(
  WidgetRef ref, {
  required ActiveWalletType accountType,
  required String? householdId,
  required String? selectedWalletId,
  required List<Household> households,
  required List<WalletEntity> wallets,
  String? spaceLabel,
}) {
  final targetHouseholdId =
      accountType == ActiveWalletType.personal ? null : householdId;
  final walletId = resolveAiInputTargetWalletId(
    ref,
    accountType: accountType,
    householdId: targetHouseholdId,
    wallets: wallets,
    selectedWalletId: selectedWalletId,
  );
  final selectedWallet = resolveAiInputTargetWallet(wallets, walletId);
  final isPortfolio = accountType == ActiveWalletType.portfolio ||
      households.any(
        (household) =>
            household.id == targetHouseholdId && household.isPortfolio,
      );

  return AiInputTarget(
    accountType: accountType,
    householdId: targetHouseholdId,
    isPortfolio: isPortfolio,
    accountId: walletId,
    accountCurrency: selectedWallet?.currency.trim().toUpperCase(),
    spaceLabel: spaceLabel,
  );
}

AiInputTarget resolveDefaultAiInputTarget(WidgetRef ref) {
  final selection = resolveInitialAiInputTargetSelection(ref);
  final targetHouseholdId = selection.accountType == ActiveWalletType.personal
      ? null
      : selection.householdId;
  final wallets = filterAiInputTargetWallets(
    ref.read(walletsByHouseholdIdProvider(targetHouseholdId)).valueOrNull ??
        const <WalletEntity>[],
    ref.read(homeFilterProvider),
  );
  final userId = ref.read(authProvider).uid.trim();
  final households = userId.isEmpty
      ? const <Household>[]
      : ref.read(userHouseholdsProvider(userId)).valueOrNull ??
          const <Household>[];

  return buildAiInputTargetFromSelection(
    ref,
    accountType: selection.accountType,
    householdId: selection.householdId,
    selectedWalletId: selection.walletId,
    households: households,
    wallets: wallets,
  );
}
