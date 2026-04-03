import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';

class WalletTransferResult {
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final DateTime date;
  final String? note;

  const WalletTransferResult({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.date,
    this.note,
  });
}

Future<WalletTransferResult?> showWalletTransferSheet(
  BuildContext context, {
  required List<WalletEntity> wallets,
  String? defaultFromWalletId,
}) {
  if (wallets.length < 2) {
    return Future.value(null);
  }

  return showModalBottomSheet<WalletTransferResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: false,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => _WalletTransferSheet(
      wallets: wallets,
      defaultFromWalletId: defaultFromWalletId,
    ),
  );
}

class _WalletTransferSheet extends HookConsumerWidget {
  const _WalletTransferSheet({
    required this.wallets,
    this.defaultFromWalletId,
  });

  final List<WalletEntity> wallets;
  final String? defaultFromWalletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Initialize from wallet - use defaultFromWalletId if provided, otherwise first wallet
    final fromIdState = useState<String>(
      defaultFromWalletId ?? wallets.first.id,
    );

    // Initialize to wallet - first non-from wallet
    final initialToWallet = wallets.firstWhere(
      (w) => w.id != fromIdState.value,
      orElse: () => wallets.length > 1 ? wallets[1] : wallets.first,
    );
    final toIdState = useState<String>(initialToWallet.id);

    final amountText = useState<String>('');
    final noteController = useTextEditingController();
    final isSaving = useState<bool>(false);

    // Get currency symbol for the amount field
    final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final symbol = resolveCurrencySymbol(currencyCode);

    // Parse amount from text
    double getAmountValue() {
      return (tryParseMoneyToCents(amountText.value) ?? 0) / 100.0;
    }

    Future<void> handleEditAmount() async {
      final controller = TextEditingController(text: amountText.value);
      final result = await showModalBottomSheet<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        enableDrag: false,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.sheetBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ModalSheetHandle(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.foreground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: colorScheme.mutedForeground,
                            ),
                            border: InputBorder.none,
                            prefixText: symbol,
                            prefixStyle: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryAdaptiveButton(
                            onPressed: () => Navigator.of(context).pop(controller.text),
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (result != null) {
        amountText.value = result;
      }
    }

    // Get current wallet names for display
    final fromWallet = wallets.firstWhere(
      (w) => w.id == fromIdState.value,
      orElse: () => wallets.first,
    );
    final toWallet = wallets.firstWhere(
      (w) => w.id == toIdState.value,
      orElse: () => wallets.first,
    );

    void handleSwapDirection() {
      final temp = fromIdState.value;
      fromIdState.value = toIdState.value;
      toIdState.value = temp;
    }

    Future<void> handleSave() async {
      // Validation
      if (fromIdState.value == toIdState.value) {
        AppToast.error(context, 'Cannot transfer to the same wallet');
        return;
      }

      final amountCents = (tryParseMoneyToCents(amountText.value) ?? 0).toInt();
      if (amountCents <= 0) {
        AppToast.error(context, 'Please enter a valid amount');
        return;
      }

      isSaving.value = true;

      Navigator.of(context).pop(
        WalletTransferResult(
          fromAccountId: fromIdState.value,
          toAccountId: toIdState.value,
          amountCents: amountCents,
          date: DateTime.now(),
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        ),
      );
    }

    Future<void> handleSelectFromWallet() async {
      final selected = await _showWalletSelectionSheet(
        context,
        ref: ref,
        wallets: wallets,
        currentId: fromIdState.value,
        title: 'From Wallet',
      );
      if (selected != null && selected != fromIdState.value) {
        fromIdState.value = selected;
        // If to wallet is now same as from, auto-switch to a different one
        if (toIdState.value == selected) {
          final otherWallet = wallets.firstWhere(
            (w) => w.id != selected,
            orElse: () => wallets.first,
          );
          toIdState.value = otherWallet.id;
        }
      }
    }

    Future<void> handleSelectToWallet() async {
      final selected = await _showWalletSelectionSheet(
        context,
        ref: ref,
        wallets: wallets,
        currentId: toIdState.value,
        title: 'To Wallet',
      );
      if (selected != null && selected != toIdState.value) {
        toIdState.value = selected;
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalSheetHandle(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: isSaving.value ? null : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.muted.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Transfer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.foreground,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: isSaving.value ? null : handleSave,
                      icon: isSaving.value
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            )
                          : Icon(Icons.check, color: colorScheme.primary),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Hero Section - matches unified_transaction_sheet styling
                      GestureDetector(
                        onTap: isSaving.value ? null : handleEditAmount,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Text(
                                '${symbol}${formatLocalizedNumber(context, double.parse(formatAmount(getAmountValue())))}',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to edit amount',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // From Wallet Section
                      Text(
                        'From',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MonekoInput(
                        child: InkWell(
                          onTap: isSaving.value ? null : () => handleSelectFromWallet(),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: parseAccountColor(fromWallet.color, colorScheme.primary)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    resolveWalletIcon(fromWallet.icon),
                                    color: parseAccountColor(fromWallet.color, colorScheme.primary),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    fromWallet.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.foreground,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${symbol}${formatLocalizedNumber(context, double.parse(formatAmount(fromWallet.currentBalanceCents / 100.0)))}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Swap Direction Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: isSaving.value ? null : handleSwapDirection,
                                icon: Icon(
                                  Icons.swap_vert,
                                  color: colorScheme.primary,
                                  size: 24,
                                ),
                                tooltip: 'Swap direction',
                              ),
                            ),
                          ],
                        ),
                      ),

                      // To Wallet Section
                      Text(
                        'To',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MonekoInput(
                        child: InkWell(
                          onTap: isSaving.value ? null : () => handleSelectToWallet(),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: parseAccountColor(toWallet.color, colorScheme.primary)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    resolveWalletIcon(toWallet.icon),
                                    color: parseAccountColor(toWallet.color, colorScheme.primary),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    toWallet.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.foreground,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${symbol}${formatLocalizedNumber(context, double.parse(formatAmount(toWallet.currentBalanceCents / 100.0)))}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Note Field
                      Text(
                        'Note (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: noteController,
                        placeholder: 'Add a note about this transfer',
                        maxLines: 2,
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryAdaptiveButton(
                          onPressed: isSaving.value ? null : handleSave,
                          child: isSaving.value
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : const Text('Transfer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showWalletSelectionSheet(
    BuildContext context, {
    required WidgetRef ref,
    required List<WalletEntity> wallets,
    required String currentId,
    required String title,
  }) async {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyCode = ref.read(selectedHomeCurrencyCodeProvider);
    final symbol = resolveCurrencySymbol(currencyCode);

    return showModalBottomSheet<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      enableDrag: false,
      useSafeArea: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.sheetBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ModalSheetHandle(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back, color: colorScheme.mutedForeground),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: colorScheme.foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final isSelected = wallet.id == currentId;
                      final walletColor = parseAccountColor(wallet.color, colorScheme.primary);

                      return ListTile(
                        onTap: () => Navigator.of(context).pop(wallet.id),
                        selected: isSelected,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: walletColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            resolveWalletIcon(wallet.icon),
                            color: walletColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          wallet.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.foreground,
                          ),
                        ),
                        subtitle: Text(
                          '${symbol}${formatLocalizedNumber(context, double.parse(formatAmount(wallet.currentBalanceCents / 100.0)))}',
                          style: TextStyle(
                            color: colorScheme.mutedForeground,
                            fontSize: 13,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: colorScheme.primary)
                            : null,
                      );
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        );
      },
    );
  }
}
