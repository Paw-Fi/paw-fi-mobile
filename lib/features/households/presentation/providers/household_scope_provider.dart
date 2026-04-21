import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/view_mode_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';

enum ActiveWalletType {
  personal,
  portfolio,
  household,
}

class HouseholdScope {
  final ViewMode viewMode;
  final SelectedHouseholdState selected;
  final Set<String> portfolioHouseholdIds;

  const HouseholdScope({
    required this.viewMode,
    required this.selected,
    required this.portfolioHouseholdIds,
  });

  String? get selectedHouseholdId {
    final raw = selected.householdId ?? selected.household?.id;
    return (raw != null && raw.trim().isNotEmpty) ? raw : null;
  }

  bool get hasSelectedHousehold => selectedHouseholdId != null;

  bool isPortfolioId(String? householdId) {
    if (householdId == null || householdId.isEmpty) return false;
    return portfolioHouseholdIds.contains(householdId);
  }

  bool get isPortfolioSelected => isPortfolioId(selectedHouseholdId);

  ActiveWalletType get activeAccountType {
    if (viewMode == ViewMode.personal) return ActiveWalletType.personal;

    // If the user has no spaces yet (or selection hasn't been initialized),
    // default to personal scope so data doesn't get filtered out.
    if (!hasSelectedHousehold) return ActiveWalletType.personal;

    if (isPortfolioSelected) return ActiveWalletType.portfolio;
    return ActiveWalletType.household;
  }

  bool get isPersonalAccount => activeAccountType == ActiveWalletType.personal;
  bool get isPortfolioAccount =>
      activeAccountType == ActiveWalletType.portfolio;
  bool get isHouseholdAccount =>
      activeAccountType == ActiveWalletType.household;

  String? get activeAccountHouseholdId {
    if (activeAccountType == ActiveWalletType.personal) return null;
    return selectedHouseholdId;
  }

  bool get isHouseholdView =>
      viewMode == ViewMode.household &&
      hasSelectedHousehold &&
      !isPortfolioSelected;

  bool get isPersonalView => !isHouseholdView;
}

final householdScopeProvider = Provider<HouseholdScope>((ref) {
  final viewMode = ref.watch(viewModeProvider).mode;
  final selected = ref.watch(selectedHouseholdProvider);
  final userId = ref.watch(authProvider).uid;
  final households = userId.isEmpty
      ? const <Household>[]
      : ref.watch(userHouseholdsProvider(userId)).valueOrNull ??
          const <Household>[];
  final portfolioIds =
      households.where((h) => h.isPortfolio).map((h) => h.id).toSet();

  return HouseholdScope(
    viewMode: viewMode,
    selected: selected,
    portfolioHouseholdIds: portfolioIds,
  );
});
