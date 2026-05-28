import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';

List<WalletEntity> filterAiInputTargetWallets(
  Iterable<WalletEntity> wallets,
  HomeFilterState filterState,
) {
  return wallets
      .where(
        (wallet) =>
            !wallet.isArchived && filterState.allowsCurrency(wallet.currency),
      )
      .toList(growable: false);
}
