import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/widgets/custom_text_field.dart';
import 'package:moneko/core/utils/currency_rate_provider.dart';
import 'package:moneko/core/utils/intl_locale.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/features/wallets/presentation/state/wallet_transfer_draft.dart';
import 'package:moneko/shared/widgets/calculator_keypad.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/shared/widgets/moneko_disclosure_row.dart';
import 'package:moneko/shared/widgets/moneko_input.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/core/utils/money_parser.dart';

String? parseTransferRateInput(String value, String locale) {
  final symbols = NumberFormat.decimalPattern(locale).symbols;
  final zeroes = {
    0x30,
    0x660,
    0x6f0,
    0x966,
    0xe50,
    0xff10,
    symbols.ZERO_DIGIT.runes.first
  };
  final digits = String.fromCharCodes(value.trim().runes.map((rune) {
    for (final zero in zeroes) {
      if (rune >= zero && rune <= zero + 9) return 0x30 + rune - zero;
    }
    return rune;
  }));
  final canonicalSeparators = digits
      .replaceAll('\u066b', symbols.DECIMAL_SEP)
      .replaceAll('\u066c', symbols.GROUP_SEP);
  final parts = canonicalSeparators.split(symbols.DECIMAL_SEP);
  final groups = parts.first.split(symbols.GROUP_SEP);
  if (groups.length > 1 &&
      (groups.first.isEmpty ||
          groups.first.length > 3 ||
          groups.skip(1).any((group) => group.length != 3))) {
    return null;
  }
  if (parts.skip(1).any((part) => part.contains(symbols.GROUP_SEP))) {
    return null;
  }
  final normalized = canonicalSeparators
      .replaceAll(symbols.GROUP_SEP, '')
      .replaceAll(symbols.DECIMAL_SEP, '.')
      .replaceAll('\u066c', '')
      .replaceAll('\u066b', '.');
  if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized) ||
      normalized.length > 60 ||
      !RegExp('[1-9]').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

String transferAmountLabel(BuildContext context, int? cents, String currency) =>
    cents == null
        ? context.l10n.notSet
        : '$currency ${formatLocalizedNumber(context, cents / 100)}';

class WalletTransferConversionFields extends HookConsumerWidget {
  const WalletTransferConversionFields(
      {super.key, required this.seed, required this.disabled});

  final WalletTransferDraft seed;
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(walletTransferDraftProvider(seed));
    final controller = ref.read(walletTransferDraftProvider(seed).notifier);
    final needsSuggestion = draft.isCrossCurrency &&
        (draft.rate == null ||
            draft.rateOrigin == TransferRateOrigin.suggested);
    final rates = needsSuggestion ? ref.watch(currencyRateTableProvider) : null;
    final table = rates?.valueOrNull;
    useEffect(() {
      if (table == null) return null;
      var active = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!active || disabled) return;
        final from = table.rates[draft.sourceCurrency];
        final to = table.rates[draft.targetCurrency];
        if (from != null &&
            to != null &&
            from > 0 &&
            to > 0 &&
            (to / from).isFinite) {
          controller.suggestRate((to / from).toString());
        }
      });
      return () => active = false;
    }, [table, draft.sourceCurrency, draft.targetCurrency, disabled]);

    Future<void> editMoney({required bool fee}) async {
      final cents = fee ? draft.feeCents : draft.targetCents;
      final result = await showCalculatorKeypadSheet(
          context: context,
          initialValue: cents == null ? '' : (cents / 100).toStringAsFixed(2),
          prefix: fee ? draft.sourceCurrency : draft.targetCurrency);
      if (result == null || !context.mounted) return;
      final parsed = tryParseMoneyToCents(result);
      if (parsed == null || parsed < 0 || parsed > maxTransferCents) return;
      if (fee) {
        controller.setFee(parsed);
      } else {
        controller.setTarget(parsed);
      }
    }

    final locale = intlSafeLocaleName(Localizations.localeOf(context));
    final numericRate = num.tryParse(draft.rate ?? '');
    final displayedRate = numericRate == null
        ? ''
        : (numericRate > 0 && numericRate < 0.000000000001
                ? NumberFormat.scientificPattern(locale)
                : NumberFormat('0.############', locale))
            .format(numericRate);
    final rateText = draft.rate == null
        ? context.l10n.notSet
        : '1 ${draft.sourceCurrency} = '
            '$displayedRate '
            '${draft.targetCurrency}';
    final status = switch (draft.rateOrigin) {
      TransferRateOrigin.suggested => table?.isStale == true
          ? context.l10n.transferStaleRate
          : table?.fetchedAt == null
              ? context.l10n.transferSuggestedRate
              : context.l10n.transferRateAsOf(DateFormat.yMMMd(
                      intlSafeLocaleName(Localizations.localeOf(context)))
                  .format(table!.fetchedAt!.toLocal())),
      TransferRateOrigin.calculated => context.l10n.transferCalculatedRate,
      TransferRateOrigin.custom => context.l10n.transferCustomRate,
      TransferRateOrigin.saved => context.l10n.transferSavedRate,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: draft.isCrossCurrency
              ? Column(children: [
                  MonekoInput(
                      child: Column(children: [
                    MonekoDisclosureRow(
                        key: const ValueKey('wallet-transfer-received'),
                        label: context.l10n.transferReceivedAmount,
                        value: transferAmountLabel(
                            context, draft.targetCents, draft.targetCurrency),
                        isFirst: true,
                        isValuePlaceholder: draft.targetCents == null,
                        onTap: disabled ? null : () => editMoney(fee: false)),
                    MonekoDisclosureRow(
                        key: const ValueKey('wallet-transfer-rate'),
                        label: context.l10n.transferExchangeRate,
                        value: rateText,
                        multiline: true,
                        isLast: true,
                        isValuePlaceholder: draft.rate == null,
                        onTap: disabled
                            ? null
                            : () async {
                                final rate = await _editRate(context, draft);
                                if (rate != null && context.mounted) {
                                  controller.setRate(rate);
                                }
                              }),
                  ])),
                  const SizedBox(height: 8),
                  SizedBox(
                      height: 40,
                      child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: rates?.isLoading == true &&
                                  table == null &&
                                  draft.rate == null
                              ? Container(
                                  width: 200,
                                  height: 14,
                                  decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.muted,
                                      borderRadius: BorderRadius.circular(4)))
                              : Text(
                                  draft.rate == null
                                      ? context.l10n.transferRateUnavailable
                                      : status,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .mutedForeground)))),
                ])
              : const SizedBox.shrink()),
      MonekoInput(
          child: MonekoDisclosureRow(
              key: const ValueKey('wallet-transfer-fee'),
              label: context.l10n.transferFee,
              value: transferAmountLabel(
                  context, draft.feeCents, draft.sourceCurrency),
              isFirst: true,
              isLast: true,
              onTap: disabled ? null : () => editMoney(fee: true))),
      const SizedBox(height: 8),
      Text(context.l10n.transferFeeExplanation,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.mutedForeground)),
      const SizedBox(height: 12),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(context.l10n.transferTotalDeducted),
            Text(transferAmountLabel(
                context, draft.totalDebitCents, draft.sourceCurrency)),
          ]),
      const SizedBox(height: 24),
    ]);
  }
}

Future<String?> _editRate(BuildContext context, WalletTransferDraft draft) =>
    MonekoBottomSheet.show<String>(
        context: context,
        isScrollControlled: true,
        title: context.l10n.transferExchangeRate,
        builder: (sheetContext) => HookBuilder(builder: (context) {
              final locale =
                  intlSafeLocaleName(Localizations.localeOf(context));
              final decimal =
                  NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
              final input = useTextEditingController(
                  text: (normalizeTransferRate(draft.rate ?? '') ?? '')
                      .replaceAll('.', decimal));
              useListenable(input);
              final parsed = parseTransferRateInput(input.text, locale);
              return SingleChildScrollView(
                  child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('1 ${draft.sourceCurrency} = … ${draft.targetCurrency}'),
                  const SizedBox(height: 16),
                  CustomTextField(
                      key: const ValueKey('transfer-rate-input'),
                      controller: input,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 16),
                  PrimaryAdaptiveButton(
                      onPressed: parsed == null
                          ? null
                          : () {
                              final current =
                                  parseTransferRateInput(input.text, locale);
                              if (current != null) {
                                Navigator.of(sheetContext).pop(current);
                              }
                            },
                      child: Text(context.l10n.done)),
                ]),
              ));
            }));
