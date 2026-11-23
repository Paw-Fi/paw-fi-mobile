import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/profile/presentation/providers/financial_reset_provider.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class FinancialResetGate extends ConsumerWidget {
  const FinancialResetGate(
      {super.key, required this.userId, required this.child});
  final String userId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) return child;
    final provider = resetRecoveryProvider(userId);
    final state = ref.watch(provider);
    final phase = state.asData?.value;
    if (!state.isLoading && !state.hasError && phase == ResetRecovery.ready) {
      return child;
    }
    final l10n = context.l10n;
    final message = state.hasError
        ? l10n.resetCheckRetry
        : switch (phase) {
            ResetRecovery.otherAccount => l10n.resetOtherAccount,
            ResetRecovery.pending => l10n.resetWaiting,
            ResetRecovery.cleaning => l10n.resetResumeCleanup,
            ResetRecovery.failed => l10n.failedToResetFinancialData,
            ResetRecovery.completed => l10n.yourDataHasBeenClearedPleaseRestart,
            _ => l10n.loading,
          };
    return Material(
        child: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (phase == ResetRecovery.pending ||
                          phase == ResetRecovery.cleaning) ...[
                        const CircularProgressIndicator.adaptive(),
                        const SizedBox(height: 16),
                      ],
                      Semantics(
                          liveRegion: true,
                          child: Text(message, textAlign: TextAlign.center)),
                      const SizedBox(height: 16),
                      if (state.hasError)
                        PrimaryAdaptiveButton(
                            child: Text(l10n.retry),
                            onPressed: () => ref.invalidate(provider))
                      else if (phase == ResetRecovery.completed)
                        PrimaryAdaptiveButton(
                            child: Text(l10n.restartNow),
                            onPressed: () async {
                              bool current() =>
                                  context.mounted &&
                                  ref.read(resetActorGuardProvider)(userId);
                              if (!current()) return;
                              await SystemNavigator.pop().timeout(
                                  const Duration(seconds: 3),
                                  onTimeout: () {});
                              await Future<void>.delayed(
                                  const Duration(milliseconds: 120));
                              if (current()) exit(0);
                            })
                      else if (phase == ResetRecovery.failed)
                        PrimaryAdaptiveButton(
                            child: Text(l10n.done),
                            onPressed: () async {
                              final db = await ref
                                  .read(financialResetProvider)
                                  .database();
                              if (!context.mounted ||
                                  !ref.read(resetActorGuardProvider)(userId)) {
                                return;
                              }
                              if (db.resetJob(userId)?['status'] == 'failed') {
                                db.removeResetJob(userId);
                              }
                              ref.invalidate(provider);
                            })
                      else if (phase == ResetRecovery.otherAccount)
                        PrimaryAdaptiveButton(
                            child: Text(l10n.signOut),
                            onPressed: () =>
                                ref.read(authProvider.notifier).signOut()),
                    ])))));
  }
}
