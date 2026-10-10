import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/privacy/data/ai_processing_consent_repository.dart';

final aiConsentUserIdProvider = Provider<String>(
  (ref) => ref.watch(authProvider.select((user) => user.uid)),
);

final aiConsentSavingDelayProvider = Provider<Future<void> Function()>(
  (ref) => () => Future<void>.delayed(const Duration(seconds: 2)),
);

/// The cache belongs to the current auth lifetime and restores this device's
/// per-account preference after restart. Consent is not synchronized remotely.
final aiProcessingConsentProvider = StateNotifierProvider<
    AiProcessingConsentNotifier, AiProcessingConsentState>((ref) {
  final userId = ref.watch(aiConsentUserIdProvider);
  final notifier = AiProcessingConsentNotifier(
    userId,
    ref.watch(aiProcessingConsentRepositoryProvider),
    () => ref.read(aiConsentUserIdProvider) == userId,
    ref.watch(aiConsentSavingDelayProvider),
  );
  ref.listen(authProvider.select((user) => user.uid), (_, next) {
    if (next != userId) notifier._accountEnded = true;
  });
  unawaited(notifier.refresh());
  return notifier;
});

class AiProcessingConsentState {
  const AiProcessingConsentState({
    this.consent,
    this.isLoading = false,
    this.isSaving = false,
    this.isCommitting = false,
    this.error,
  });

  final AiProcessingConsent? consent;
  final bool isLoading;
  final bool isSaving;
  final bool isCommitting;
  final Object? error;

  bool get mayProcess =>
      !isLoading &&
      !isSaving &&
      !isCommitting &&
      error == null &&
      consent?.isCurrent == true;
}

class AiProcessingConsentNotifier
    extends StateNotifier<AiProcessingConsentState> {
  AiProcessingConsentNotifier(
      this.userId, this.repository, this._isCurrentActor, this._savingDelay)
      : super(const AiProcessingConsentState(isLoading: true));

  final String userId;
  final AiProcessingConsentRepository repository;
  final bool Function() _isCurrentActor;
  final Future<void> Function() _savingDelay;
  Future<bool>? _read;
  Future<bool>? disclosureRequest;
  int _revision = 0;
  bool _accountEnded = false;
  AiProcessingConsentState? _pendingGrantPrevious;

  bool get isCurrentActor =>
      mounted && !_accountEnded && userId.isNotEmpty && _isCurrentActor();

  Future<bool> refresh() {
    if (!isCurrentActor || state.isSaving) return Future.value(false);
    return _read ??= _refresh().whenComplete(() => _read = null);
  }

  Future<bool> _refresh() async {
    final revision = ++_revision;
    state = AiProcessingConsentState(consent: state.consent, isLoading: true);
    try {
      final response = await repository.getConsent(userId);
      if (!isCurrentActor || revision != _revision) return false;
      final consent = AiProcessingConsent.fromResponse(response, userId);
      state = AiProcessingConsentState(consent: consent);
      return state.mayProcess;
    } catch (error) {
      if (isCurrentActor && revision == _revision) {
        state = AiProcessingConsentState(consent: state.consent, error: error);
      }
      return false;
    }
  }

  void cancelPendingGrant() {
    final previous = _pendingGrantPrevious;
    if (!mounted || previous == null || state.isCommitting) return;
    ++_revision;
    _pendingGrantPrevious = null;
    if (isCurrentActor) state = previous;
  }

  /// Grants remain cancellable during mock progress, not during the local write.
  Future<bool> setGranted(bool granted) async {
    if (!isCurrentActor || state.isSaving || state.isLoading) return false;
    final revision = ++_revision;
    final previous = state.consent;
    _pendingGrantPrevious = granted ? state : null;
    state = AiProcessingConsentState(consent: previous, isSaving: true);
    try {
      await _savingDelay();
      if (!isCurrentActor || revision != _revision) return false;
      state = AiProcessingConsentState(
        consent: previous,
        isSaving: true,
        isCommitting: true,
      );
      final response = await repository.setConsent(userId, granted);
      if (!isCurrentActor || revision != _revision) return false;
      final consent = AiProcessingConsent.fromResponse(response, userId);
      if (consent.granted != granted || (granted && !consent.isCurrent)) {
        throw const FormatException('Consent choice was not confirmed');
      }
      state = AiProcessingConsentState(consent: consent);
      return true;
    } catch (error) {
      if (isCurrentActor && revision == _revision) {
        state = AiProcessingConsentState(consent: previous, error: error);
      }
      return false;
    } finally {
      if (revision == _revision) _pendingGrantPrevious = null;
    }
  }
}
