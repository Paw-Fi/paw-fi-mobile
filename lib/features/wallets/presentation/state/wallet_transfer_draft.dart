import 'package:hooks_riverpod/hooks_riverpod.dart';

// Matches the exact JSON integer boundary used by the transfer HTTP contract.
const maxTransferCents = 9007199254740991;

({BigInt numerator, BigInt denominator})? _rateFraction(String value) {
  final match = RegExp(r'^\+?(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d{1,2}))?$')
      .firstMatch(value.trim());
  if (match == null || value.length > 100) return null;
  final fraction = match[2] ?? '';
  var numerator = BigInt.parse('${match[1]}$fraction');
  if (numerator <= BigInt.zero) return null;
  final scale = fraction.length - int.parse(match[3] ?? '0');
  var denominator = BigInt.one;
  if (scale >= 0) {
    denominator = BigInt.from(10).pow(scale);
  } else {
    numerator *= BigInt.from(10).pow(-scale);
  }
  return (numerator: numerator, denominator: denominator);
}

int? convertTransferCents(int sourceCents, String rate,
    {bool inverse = false}) {
  final fraction = _rateFraction(rate);
  if (fraction == null || sourceCents <= 0) return null;
  final numerator = inverse ? fraction.denominator : fraction.numerator;
  final denominator = inverse ? fraction.numerator : fraction.denominator;
  final product = BigInt.from(sourceCents) * numerator;
  final rounded =
      (product * BigInt.two + denominator) ~/ (denominator * BigInt.two);
  if (rounded <= BigInt.zero || rounded > BigInt.from(maxTransferCents)) {
    return null;
  }
  return rounded.toInt();
}

String? normalizeTransferRate(String rate) {
  final fraction = _rateFraction(rate);
  if (fraction == null) return null;
  final scale = fraction.denominator.toString().length - 1;
  if (scale == 0) return fraction.numerator.toString();
  final digits = fraction.numerator.toString().padLeft(scale + 1, '0');
  final result = '${digits.substring(0, digits.length - scale)}.'
      '${digits.substring(digits.length - scale)}';
  return result.replaceFirst(RegExp(r'\.?0+$'), '');
}

String deriveTransferRate(int sourceCents, int targetCents) {
  if (sourceCents <= 0 || targetCents <= 0) {
    throw ArgumentError('Transfer principals must be positive');
  }
  final scale = BigInt.from(10).pow(24);
  final source = BigInt.from(sourceCents);
  final scaled = (BigInt.from(targetCents) * scale * BigInt.two + source) ~/
      (source * BigInt.two);
  final digits = scaled.toString().padLeft(25, '0');
  final result = '${digits.substring(0, digits.length - 24)}.'
      '${digits.substring(digits.length - 24)}';
  return result.replaceFirst(RegExp(r'\.?0+$'), '');
}

enum TransferRateOrigin { suggested, calculated, custom, saved }

class WalletTransferDraft {
  const WalletTransferDraft({
    required this.sourceCurrency,
    required this.targetCurrency,
    this.sourceCents,
    this.targetCents,
    this.rate,
    this.feeCents = 0,
    this.rateOrigin = TransferRateOrigin.saved,
  });

  final String sourceCurrency;
  final String targetCurrency;
  final int? sourceCents;
  final int? targetCents;
  final String? rate;
  final int feeCents;
  final TransferRateOrigin rateOrigin;

  bool get isCrossCurrency => sourceCurrency != targetCurrency;
  int? get totalDebitCents =>
      sourceCents == null ? null : sourceCents! + feeCents;
  bool get isValid =>
      sourceCents != null &&
      sourceCents! > 0 &&
      targetCents != null &&
      targetCents! > 0 &&
      sourceCents! <= maxTransferCents &&
      targetCents! <= maxTransferCents &&
      feeCents >= 0 &&
      totalDebitCents! <= maxTransferCents &&
      (isCrossCurrency
          ? rate != null &&
              convertTransferCents(sourceCents!, rate!) == targetCents
          : sourceCents == targetCents && rate == '1');
}

final walletTransferDraftProvider = StateNotifierProvider.autoDispose.family<
    WalletTransferDraftController, WalletTransferDraft, WalletTransferDraft>(
  (ref, seed) => WalletTransferDraftController(seed),
);

class WalletTransferDraftController extends StateNotifier<WalletTransferDraft> {
  WalletTransferDraftController(super.state);

  void _amounts(int? source, int? target,
      {String? rate, TransferRateOrigin? origin, int? fee}) {
    state = WalletTransferDraft(
      sourceCurrency: state.sourceCurrency,
      targetCurrency: state.targetCurrency,
      sourceCents: source,
      targetCents: target,
      rate: rate,
      feeCents: fee ?? state.feeCents,
      rateOrigin: origin ?? state.rateOrigin,
    );
  }

  void setSource(int? cents) {
    if (!state.isCrossCurrency) {
      _amounts(cents, cents, rate: '1');
    } else if ((cents ?? 0) > 0 && (state.targetCents ?? 0) > 0) {
      _amounts(cents, state.targetCents,
          rate: deriveTransferRate(cents!, state.targetCents!),
          origin: TransferRateOrigin.calculated);
    } else {
      _amounts(
          cents,
          cents == null || state.rate == null
              ? state.targetCents
              : convertTransferCents(cents, state.rate!),
          rate: state.rate);
    }
  }

  void setTarget(int? cents) {
    if (!state.isCrossCurrency) {
      _amounts(cents, cents, rate: '1');
    } else if ((cents ?? 0) > 0 && (state.sourceCents ?? 0) > 0) {
      _amounts(state.sourceCents, cents,
          rate: deriveTransferRate(state.sourceCents!, cents!),
          origin: TransferRateOrigin.calculated);
    } else {
      final source = state.rate == null || cents == null
          ? null
          : convertTransferCents(cents, state.rate!, inverse: true);
      _amounts(source, cents,
          rate: source == null || cents == null
              ? state.rate
              : deriveTransferRate(source, cents));
    }
  }

  void setRate(String rate) {
    final valid = _rateFraction(rate) != null;
    _amounts(
        state.sourceCents,
        valid && state.sourceCents != null
            ? convertTransferCents(state.sourceCents!, rate)
            : null,
        rate: valid ? rate : null,
        origin: TransferRateOrigin.custom);
  }

  void suggestRate(String rate) {
    if (state.rate != null ||
        state.rateOrigin == TransferRateOrigin.custom ||
        !state.isCrossCurrency ||
        _rateFraction(rate) == null) {
      return;
    }
    if ((state.sourceCents ?? 0) > 0 && (state.targetCents ?? 0) > 0) return;
    final source = state.sourceCents ??
        (state.targetCents == null
            ? null
            : convertTransferCents(state.targetCents!, rate, inverse: true));
    final target = state.sourceCents == null
        ? state.targetCents
        : convertTransferCents(state.sourceCents!, rate);
    _amounts(source, target,
        rate: source != null &&
                target != null &&
                convertTransferCents(source, rate) != target
            ? deriveTransferRate(source, target)
            : rate,
        origin: TransferRateOrigin.suggested);
  }

  void setFee(int cents) => _amounts(state.sourceCents, state.targetCents,
      rate: state.rate, fee: cents);

  void changeCurrencies(String source, String target) {
    if (source == state.sourceCurrency && target == state.targetCurrency) {
      return;
    }
    final sourceChanged = source != state.sourceCurrency;
    final sourceAmount = sourceChanged ? null : state.sourceCents;
    final targetAmount =
        target == state.targetCurrency ? state.targetCents : null;
    state = WalletTransferDraft(
      sourceCurrency: source,
      targetCurrency: target,
      sourceCents: sourceAmount,
      targetCents: source == target ? sourceAmount : targetAmount,
      rate: source == target ? '1' : null,
      feeCents: sourceChanged ? 0 : state.feeCents,
    );
  }

  void swap() {
    state = WalletTransferDraft(
      sourceCurrency: state.targetCurrency,
      targetCurrency: state.sourceCurrency,
      sourceCents: state.targetCents, targetCents: state.sourceCents,
      rate: (state.sourceCents ?? 0) > 0 && (state.targetCents ?? 0) > 0
          ? deriveTransferRate(state.targetCents!, state.sourceCents!)
          : null,
      // A source-wallet fee cannot be relabelled as a different-currency fee.
      feeCents: 0, rateOrigin: TransferRateOrigin.calculated,
    );
  }
}
