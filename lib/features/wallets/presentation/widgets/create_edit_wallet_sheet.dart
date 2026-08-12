import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/config/storage_config.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/money_parser.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/widgets/wallet_icon_resolver.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_display_names.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/shared/widgets/adaptive_color_picker.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/moneko_selector_button.dart';
import 'package:moneko/shared/widgets/rounded_logo_picker.dart';

class CreateEditWalletResult {
  final String name;
  final String icon;
  final String color;
  final String? logoUrl;
  final String currency;
  final int openingBalanceCents;
  final int? goalAmountCents;
  final bool isDefault;
  final bool excludeFromAnalytics;

  const CreateEditWalletResult({
    required this.name,
    required this.icon,
    required this.color,
    required this.logoUrl,
    required this.currency,
    required this.openingBalanceCents,
    required this.goalAmountCents,
    required this.isDefault,
    required this.excludeFromAnalytics,
  });
}

Future<CreateEditWalletResult?> showCreateEditWalletSheet(
  BuildContext context, {
  WalletEntity? initial,
}) {
  final confirmController = MonekoSheetConfirmController();
  final sheet = MonekoBottomSheet.show<CreateEditWalletResult>(
    context: context,
    title: initial != null ? context.l10n.editWallet : context.l10n.addWallet,
    isScrollControlled: true,
    onClose: () => Navigator.pop(context),
    confirmController: confirmController,
    builder: (context) => _CreateEditWalletSheet(
      initial: initial,
      confirmController: confirmController,
    ),
  );
  sheet.whenComplete(confirmController.dispose);
  return sheet;
}

class _CreateEditWalletSheet extends HookConsumerWidget {
  const _CreateEditWalletSheet({
    required this.initial,
    required this.confirmController,
  });

  final WalletEntity? initial;
  final MonekoSheetConfirmController confirmController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final homeCurrency = ref.watch(selectedHomeCurrencyCodeProvider);
    final isEditing = initial != null;
    final nameController = useTextEditingController(text: initial?.name ?? '');
    final goalController = useTextEditingController(
      text: initial?.goalAmountCents == null
          ? ''
          : formatAmount(centsToAmount(initial!.goalAmountCents!)),
    );
    final openingController = useTextEditingController(
      text: isEditing
          ? formatAmount(centsToAmount(initial!.openingBalanceCents))
          : '',
    );
    useListenable(openingController);
    useListenable(goalController);
    final selectedLogoUrl = useState<String?>(initial?.logoUrl);
    final selectedIcon = useState<String>(
      initial?.logoUrl != null && initial?.logoUrl?.isNotEmpty == true
          ? 'wallet'
          : (initial?.icon ?? 'wallet'),
    );
    final selectedColor = useState<String?>(initial?.color);
    final initialCurrency = initial?.currency.trim().toUpperCase();
    final selectedCurrency = useState<String>(
      isSupportedCurrencyCode(initialCurrency)
          ? initialCurrency!
          : isSupportedCurrencyCode(homeCurrency)
              ? homeCurrency.trim().toUpperCase()
              : 'USD',
    );
    final currencySymbol = resolveCurrencySymbol(selectedCurrency.value);
    final isDefault = useState<bool>(initial?.isDefault ?? false);
    final excludeFromAnalytics =
        useState<bool>(initial?.excludeFromAnalytics ?? false);
    final isPrimaryWalletLocked = isEditing && (initial?.isDefault ?? false);
    final canChangeCurrency = !isEditing;

    Future<void> handleSave() async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        AppToast.error(context, context.l10n.pleaseEnterWalletName);
        return;
      }

      final openingCents =
          (tryParseMoneyToCents(openingController.text) ?? 0).toInt();
      final goalRaw = goalController.text.trim();
      final goalCents =
          goalRaw.isEmpty ? null : (tryParseMoneyToCents(goalRaw) ?? 0).toInt();

      Navigator.of(context).pop(
        CreateEditWalletResult(
          name: name,
          icon: selectedIcon.value,
          color: selectedColor.value ?? '#6B7280',
          logoUrl: selectedLogoUrl.value,
          currency: selectedCurrency.value,
          openingBalanceCents: openingCents,
          goalAmountCents: goalCents,
          isDefault: isDefault.value,
          excludeFromAnalytics: excludeFromAnalytics.value,
        ),
      );
    }

    confirmController.attach(handleSave);
    useEffect(() => confirmController.detach, [confirmController]);

    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.walletName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: nameController,
                placeholder: context.l10n.walletNameExample,
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.currency,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              if (canChangeCurrency)
                AdaptivePopupMenuButton.widget<String>(
                  items: getAvailableCurrencyOptions().keys.map((code) {
                    return AdaptivePopupMenuItem<String>(
                      label: '$code · ${resolveCurrencyDisplayName(code)}',
                      value: code,
                    );
                  }).toList(growable: false),
                  onSelected: (_, item) {
                    final value = item.value;
                    if (value == null || value.isEmpty) return;
                    selectedCurrency.value = value;
                  },
                  child: IgnorePointer(
                    child: MonekoSelectorButton(
                      label:
                          '${selectedCurrency.value} · ${resolveCurrencyDisplayName(selectedCurrency.value)}',
                      onPressed: () {},
                    ),
                  ),
                )
              else
                AbsorbPointer(
                  child: Opacity(
                    opacity: 0.72,
                    child: MonekoSelectorButton(
                      label:
                          '${selectedCurrency.value} · ${resolveCurrencyDisplayName(selectedCurrency.value)}',
                      onPressed: () {},
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                context.l10n.walletColor,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              ColorSelectionSwatchRow(
                selectedHex: selectedColor.value,
                onChanged: (color) => selectedColor.value = color,
                presetColors: AppTheme.pocketPresetColors,
                sweepColors: AppTheme.pocketColorSweep,
                fallbackColor: AppTheme.pocketDefaultBlue,
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.walletIcon,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _walletIcons.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final selectedColorValue = parseWalletColor(
                      selectedColor.value,
                      colorScheme.primary,
                    );
                    if (index == 0) {
                      return RoundedLogoPicker(
                        logoUrl: selectedLogoUrl.value,
                        storagePathPrefix: StorageConfig.walletLogosPath,
                        onChanged: (value) {
                          selectedLogoUrl.value = value;
                          if (value != null) {
                            selectedIcon.value = 'wallet';
                          }
                        },
                        fallbackIcon: resolveWalletIcon(selectedIcon.value),
                        accentColor: selectedColorValue,
                      );
                    }

                    final iconName = _walletIcons[index - 1];
                    final isSelected = selectedLogoUrl.value == null &&
                        selectedIcon.value == iconName;
                    return GestureDetector(
                      onTap: () {
                        selectedIcon.value = iconName;
                        selectedLogoUrl.value = null;
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? selectedColorValue.withValues(alpha: 0.1)
                              : colorScheme.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? selectedColorValue
                                : colorScheme.border,
                          ),
                        ),
                        child: Icon(
                          resolveWalletIcon(iconName),
                          color: isSelected
                              ? selectedColorValue
                              : colorScheme.mutedForeground,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.initialBalance,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () async {
                    final header = Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.initialBalance,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    );

                    final value = await showCalculatorKeypadSheet(
                      context: context,
                      initialValue: openingController.text,
                      prefix: currencySymbol,
                      header: header,
                    );
                    if (value != null) {
                      openingController.text = value;
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.border),
                    ),
                    child: Text(
                      openingController.text.isNotEmpty
                          ? openingController.text
                          : context.l10n.tapToSet,
                      style: TextStyle(
                        fontSize: 16,
                        color: openingController.text.isNotEmpty
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.goalAmount,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () async {
                    final header = Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.goalAmount,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    );

                    final value = await showCalculatorKeypadSheet(
                      context: context,
                      initialValue: goalController.text,
                      prefix: currencySymbol,
                      header: header,
                    );
                    if (value != null) {
                      goalController.text = value;
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.border),
                    ),
                    child: Text(
                      goalController.text.isNotEmpty
                          ? goalController.text
                          : context.l10n.tapToSet,
                      style: TextStyle(
                        fontSize: 16,
                        color: goalController.text.isNotEmpty
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: isDefault.value,
                title: Text(context.l10n.primaryWallet),
                subtitle: Text(
                  context.l10n.primaryWalletDescription,
                ),
                onChanged: isPrimaryWalletLocked
                    ? null
                    : (value) => isDefault.value = value,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: excludeFromAnalytics.value,
                title: Row(
                  children: [
                    Flexible(
                      child: Text(context.l10n.excludeFromWalletAnalytics),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: context.l10n.excludeFromWalletAnalyticsDetails,
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: const Duration(seconds: 8),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: colorScheme.mutedForeground,
                        semanticLabel:
                            context.l10n.excludeFromWalletAnalyticsDetails,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  context.l10n.excludeFromWalletAnalyticsDescription,
                ),
                onChanged: (value) => excludeFromAnalytics.value = value,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _walletIcons = [
  // Cash and spending wallets
  'wallet',
  'checking',
  'joint',
  'cash',
  'cash_envelope',
  'card',
  'paypal',

  // Savings and goals
  'savings',
  'reserve',
  'education',
  'medical',
  'allowance',
  'pet',
  'investment',
  'brokerage',
  'gold',
  'retirement',

  // Debt and liabilities
  'debt',
  'loan',
  'mortgage',
  'tax',

  // Other common wallet buckets
  'emergency',
  'budget',
  'bank',
  'business',
  'insurance',
  'crypto',
  'travel',
  'home',
];
