import 'dart:async';
import 'package:flutter/material.dart';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/number_format_utils.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Helper to safely convert dynamic value to double
double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

String _scenarioMutationId(String operation, String userId, String entityId) {
  return 'mobile:scenario_${operation}_${userId}_$entityId'
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
}

String _formatScenarioAmount(
  BuildContext context,
  double amount,
  String currencySymbol,
) {
  final normalized = double.parse(formatAmount(amount));
  return '$currencySymbol${formatLocalizedNumber(context, normalized)}';
}

Future<String> _enqueueScenarioSave(
  BuildContext context, {
  required String userId,
  required String? householdId,
  required String question,
  required String answer,
  required String? targetDate,
  required String? currency,
  required String mode,
}) async {
  final localId = 'local-scenario-${DateTime.now().microsecondsSinceEpoch}';
  final mutationId = _scenarioMutationId('save', userId, localId);
  final database = await ProviderScope.containerOf(context, listen: false)
      .read(localDatabaseProvider.future);
  await database.enqueueMutation(
    clientMutationId: mutationId,
    entityType: 'scenario_history',
    entityId: localId,
    operation: 'save_scenario_history',
    payload: {
      'userId': userId,
      'householdId': householdId,
      'question': question,
      'answer': answer,
      'targetDate': targetDate,
      'currency': currency,
      'mode': mode,
    },
  );
  return mutationId;
}

Future<String> _enqueueScenarioDelete(
  BuildContext context, {
  required String userId,
  required String scenarioId,
}) async {
  final mutationId = _scenarioMutationId('delete', userId, scenarioId);
  final database = await ProviderScope.containerOf(context, listen: false)
      .read(localDatabaseProvider.future);
  await database.enqueueMutation(
    clientMutationId: mutationId,
    entityType: 'scenario_history',
    entityId: scenarioId,
    operation: 'delete_scenario_history',
    payload: {
      'userId': userId,
      'scenarioId': scenarioId,
    },
  );
  return mutationId;
}

Future<void> _markScenarioMutationSynced(
  BuildContext context,
  String clientMutationId,
) async {
  final database = await ProviderScope.containerOf(context, listen: false)
      .read(localDatabaseProvider.future);
  await database.markMutationSynced(clientMutationId);
}

/// Shows scenario analysis result bottom sheet
void showScenarioResultSheet(
  BuildContext context,
  String advice,
  Map<String, dynamic> meta, {
  ValueNotifier<String>? liveAdvice,
  ValueNotifier<bool>? isCompleteNotifier,
  String? selectedCurrency,
  String? question,
  String? userId,
  String? mode,
  String? householdId,
  String? scenarioId,
  VoidCallback? onSaved,
  VoidCallback? onDeleted,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  // Use correct currency symbol based on selection
  final String currencySymbol;
  if (selectedCurrency != null) {
    currencySymbol = resolveCurrencySymbol(selectedCurrency);
  } else {
    // Mixed mode - no single symbol
    currencySymbol = '';
  }

  // Safely extract stats map and values
  final Map<String, dynamic>? stats =
      (meta['stats'] as Map?)?.cast<String, dynamic>();
  final curr = _asDouble(stats?['currentRunningBalance']);
  final proj = _asDouble(stats?['projectedNoScenarioByTarget']);
  final avg = _asDouble(stats?['avgNetPerDay']);

  final String effectiveMode = mode ?? (meta['mode'] as String?) ?? 'personal';
  final String? effectiveHouseholdId =
      householdId ?? (meta['householdId'] as String?);
  final String? targetDateStr = meta['targetDate'] as String?;
  String? scenarioHistoryId = scenarioId ?? (meta['id'] as String?);

  // Typewriter animation state: progressively reveal the advice text.
  String visibleAdvice = '';
  bool typewriterStarted = false;

  String getFullAdvice() =>
      (liveAdvice?.value.isNotEmpty == true) ? liveAdvice!.value : advice;

  showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface.withValues(alpha: 0.0),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        // Consider anything opened from history (no meta.stats but with question)
        // as already saved so the icon appears filled. Fresh analyses (with
        // stats present) should start as unsaved even though they have a
        // non-null question.
        final bool openedFromHistory =
            meta['stats'] == null && question != null;
        bool isSaved = openedFromHistory;
        return StatefulBuilder(
          builder: (context, setState) {
            // Lazily start the typewriter effect on first build.
            if (!typewriterStarted) {
              typewriterStarted = true;
              const step = 4; // characters per tick
              const delay = Duration(milliseconds: 16); // ~60fps
              int index = 0;

              Timer.periodic(delay, (timer) {
                if (!context.mounted) {
                  timer.cancel();
                  return;
                }

                final full = getFullAdvice();
                if (full.isEmpty) {
                  return;
                }

                // For non-streaming use (no liveAdvice), we can stop once we
                // have revealed the entire static advice. For streaming, we
                // keep the timer running so newly arrived chunks can continue
                // the animation.
                if (liveAdvice == null && index >= full.length) {
                  timer.cancel();
                  return;
                }

                index = (index + step).clamp(0, full.length);
                setState(() {
                  visibleAdvice = full.substring(0, index);
                });
              });
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: colorScheme.appBackground,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.mutedForeground.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.scenarioAnalysis,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.foreground,
                            ),
                          ),
                        ),
                        if (isCompleteNotifier == null)
                          IconButton(
                            icon: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_outline,
                              color: isSaved
                                  ? colorScheme.primary
                                  : colorScheme.foreground,
                            ),
                            tooltip: context.l10n.save,
                            onPressed: (question == null || userId == null)
                                ? null
                                : () async {
                                    final preview = ProviderScope.containerOf(
                                      context,
                                      listen: false,
                                    ).read(previewModeProvider);
                                    if (preview.isActive) {
                                      Navigator.of(context, rootNavigator: true)
                                          .pop();
                                      AppToast.success(
                                        context,
                                        context.l10n.previewScenarioBookmarked,
                                      );
                                      return;
                                    }

                                    // Toggle behavior: save when not yet saved, otherwise
                                    // ask for confirmation and delete.
                                    if (!isSaved) {
                                      debugPrint('Saving scenario...');
                                      String? queuedMutationId;
                                      try {
                                        queuedMutationId =
                                            await _enqueueScenarioSave(
                                          context,
                                          userId: userId,
                                          householdId: effectiveHouseholdId,
                                          question: question,
                                          answer: getFullAdvice(),
                                          targetDate: targetDateStr,
                                          currency: selectedCurrency,
                                          mode: effectiveMode,
                                        );
                                        final inserted =
                                            await Supabase.instance.client
                                                .from('ai_scenario_history')
                                                .insert({
                                                  'user_id': userId,
                                                  'household_id':
                                                      effectiveHouseholdId,
                                                  'question': question,
                                                  'answer': getFullAdvice(),
                                                  'target_date': targetDateStr,
                                                  'currency': selectedCurrency,
                                                  'mode': effectiveMode,
                                                })
                                                .select()
                                                .single();

                                        scenarioHistoryId =
                                            inserted['id'] as String? ??
                                                scenarioHistoryId;
                                        if (!context.mounted) return;
                                        await _markScenarioMutationSynced(
                                          context,
                                          queuedMutationId,
                                        );

                                        setState(() {
                                          isSaved = true;
                                        });

                                        if (onSaved != null) {
                                          onSaved();
                                        }

                                        if (!context.mounted) return;
                                        AppToast.success(
                                          context,
                                          context.l10n.scenarioSaved,
                                        );
                                      } catch (e) {
                                        if (queuedMutationId != null &&
                                            ErrorHandler.isRetryable(e)) {
                                          setState(() {
                                            isSaved = true;
                                          });
                                          onSaved?.call();
                                          if (!context.mounted) return;
                                          AppToast.info(
                                            context,
                                            context.l10n.offlineSyncMessage,
                                          );
                                          return;
                                        }
                                        if (!context.mounted) return;
                                        AppToast.error(
                                          context,
                                          context.l10n
                                              .analysisFailed(e.toString()),
                                        );
                                      }
                                    } else {
                                      // Confirm deletion before removing a saved scenario.
                                      final preview = ProviderScope.containerOf(
                                              context,
                                              listen: false)
                                          .read(previewModeProvider);
                                      if (preview.isActive) {
                                        Navigator.of(context,
                                                rootNavigator: true)
                                            .pop();
                                        AppToast.info(
                                          context,
                                          context.l10n
                                              .previewScenarioRemovalSkipped,
                                        );
                                        return;
                                      }
                                      await AdaptiveAlertDialog.show(
                                        context: context,
                                        title: context.l10n.delete,
                                        message: context
                                            .l10n.deleteScenarioConfirmation,
                                        actions: [
                                          AlertAction(
                                            title: context.l10n.cancel,
                                            style: AlertActionStyle.cancel,
                                            onPressed: () {},
                                          ),
                                          AlertAction(
                                            title: context.l10n.delete,
                                            style: AlertActionStyle.destructive,
                                            onPressed: () async {
                                              String? queuedMutationId;
                                              try {
                                                if (scenarioHistoryId == null) {
                                                  if (context.mounted) {
                                                    AppToast.error(
                                                      context,
                                                      context.l10n
                                                          .unableToDeleteScenario,
                                                    );
                                                  }
                                                  return;
                                                }

                                                queuedMutationId =
                                                    await _enqueueScenarioDelete(
                                                  context,
                                                  userId: userId,
                                                  scenarioId:
                                                      scenarioHistoryId!,
                                                );

                                                await Supabase.instance.client
                                                    .from('ai_scenario_history')
                                                    .delete()
                                                    .eq('id',
                                                        scenarioHistoryId!);
                                                if (!context.mounted) return;
                                                await _markScenarioMutationSynced(
                                                  context,
                                                  queuedMutationId,
                                                );

                                                setState(() {
                                                  isSaved = false;
                                                });

                                                if (onDeleted != null) {
                                                  onDeleted();
                                                }

                                                if (!context.mounted) return;
                                                AppToast.success(
                                                  context,
                                                  context.l10n.scenarioDeleted,
                                                );

                                                // Close the result sheet after
                                                // successful deletion.
                                                Navigator.of(context).pop();
                                              } catch (e) {
                                                if (queuedMutationId != null &&
                                                    ErrorHandler.isRetryable(
                                                        e)) {
                                                  setState(() {
                                                    isSaved = false;
                                                  });
                                                  onDeleted?.call();
                                                  if (!context.mounted) return;
                                                  AppToast.info(
                                                    context,
                                                    context.l10n
                                                        .offlineSyncMessage,
                                                  );
                                                  Navigator.of(context).pop();
                                                  return;
                                                }
                                                if (!context.mounted) return;
                                                AppToast.error(
                                                  context,
                                                  context.l10n.analysisFailed(
                                                      e.toString()),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      );
                                    }
                                  },
                          )
                        else
                          ValueListenableBuilder<bool>(
                            valueListenable: isCompleteNotifier,
                            builder: (context, isComplete, _) {
                              if (!isComplete) {
                                // Reserve icon space but hide the actual button
                                return const SizedBox(width: 48);
                              }
                              return IconButton(
                                icon: Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  color: isSaved
                                      ? colorScheme.primary
                                      : colorScheme.foreground,
                                ),
                                tooltip: context.l10n.save,
                                onPressed: (question == null || userId == null)
                                    ? null
                                    : () async {
                                        if (!isSaved) {
                                          debugPrint('Saving scenario...');
                                          String? queuedMutationId;
                                          try {
                                            queuedMutationId =
                                                await _enqueueScenarioSave(
                                              context,
                                              userId: userId,
                                              householdId: effectiveHouseholdId,
                                              question: question,
                                              answer: getFullAdvice(),
                                              targetDate: targetDateStr,
                                              currency: selectedCurrency,
                                              mode: effectiveMode,
                                            );
                                            final inserted = await Supabase
                                                .instance.client
                                                .from('ai_scenario_history')
                                                .insert({
                                                  'user_id': userId,
                                                  'household_id':
                                                      effectiveHouseholdId,
                                                  'question': question,
                                                  'answer': getFullAdvice(),
                                                  'target_date': targetDateStr,
                                                  'currency': selectedCurrency,
                                                  'mode': effectiveMode,
                                                })
                                                .select()
                                                .single();

                                            scenarioHistoryId =
                                                inserted['id'] as String? ??
                                                    scenarioHistoryId;
                                            if (!context.mounted) return;
                                            await _markScenarioMutationSynced(
                                              context,
                                              queuedMutationId,
                                            );

                                            setState(() {
                                              isSaved = true;
                                            });

                                            if (onSaved != null) {
                                              onSaved();
                                            }

                                            if (!context.mounted) return;
                                            AppToast.success(
                                              context,
                                              context.l10n.scenarioSaved,
                                            );
                                          } catch (e) {
                                            if (queuedMutationId != null &&
                                                ErrorHandler.isRetryable(e)) {
                                              setState(() {
                                                isSaved = true;
                                              });
                                              onSaved?.call();
                                              if (!context.mounted) return;
                                              AppToast.info(
                                                context,
                                                context.l10n.offlineSyncMessage,
                                              );
                                              return;
                                            }
                                            if (!context.mounted) return;
                                            AppToast.error(
                                              context,
                                              context.l10n
                                                  .analysisFailed(e.toString()),
                                            );
                                          }
                                        } else {
                                          // Confirm deletion before removing a saved scenario.
                                          await AdaptiveAlertDialog.show(
                                            context: context,
                                            title: context.l10n.delete,
                                            message: context.l10n
                                                .deleteScenarioConfirmation,
                                            actions: [
                                              AlertAction(
                                                title: context.l10n.cancel,
                                                style: AlertActionStyle.cancel,
                                                onPressed: () {},
                                              ),
                                              AlertAction(
                                                title: context.l10n.delete,
                                                style: AlertActionStyle
                                                    .destructive,
                                                onPressed: () async {
                                                  String? queuedMutationId;
                                                  try {
                                                    if (scenarioHistoryId ==
                                                        null) {
                                                      if (context.mounted) {
                                                        AppToast.error(
                                                          context,
                                                          context.l10n
                                                              .unableToDeleteScenario,
                                                        );
                                                      }
                                                      return;
                                                    }

                                                    queuedMutationId =
                                                        await _enqueueScenarioDelete(
                                                      context,
                                                      userId: userId,
                                                      scenarioId:
                                                          scenarioHistoryId!,
                                                    );

                                                    await Supabase
                                                        .instance.client
                                                        .from(
                                                            'ai_scenario_history')
                                                        .delete()
                                                        .eq('id',
                                                            scenarioHistoryId!);
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    await _markScenarioMutationSynced(
                                                      context,
                                                      queuedMutationId,
                                                    );

                                                    setState(() {
                                                      isSaved = false;
                                                    });

                                                    if (onDeleted != null) {
                                                      onDeleted();
                                                    }

                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    AppToast.success(
                                                      context,
                                                      context
                                                          .l10n.scenarioDeleted,
                                                    );

                                                    // Close the result sheet after
                                                    // successful deletion.
                                                    Navigator.of(context).pop();
                                                  } catch (e) {
                                                    if (queuedMutationId !=
                                                            null &&
                                                        ErrorHandler
                                                            .isRetryable(e)) {
                                                      setState(() {
                                                        isSaved = false;
                                                      });
                                                      onDeleted?.call();
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      AppToast.info(
                                                        context,
                                                        context.l10n
                                                            .offlineSyncMessage,
                                                      );
                                                      Navigator.of(context)
                                                          .pop();
                                                      return;
                                                    }
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    AppToast.error(
                                                      context,
                                                      context.l10n
                                                          .analysisFailed(
                                                              e.toString()),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          );
                                        }
                                      },
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Target Date Badge
                          if (meta['targetDate'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${context.l10n.target}: ${meta['targetDate']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // AI Advice (parsed from markdown)
                          // Use the progressively revealed text if available,
                          // otherwise fall back to the full advice string.
                          MarkdownBlock(
                            data:
                                visibleAdvice.isEmpty ? advice : visibleAdvice,
                            config: MarkdownConfig(
                              configs: [
                                PConfig(
                                  textStyle: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                H1Config(
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                H2Config(
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                H3Config(
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.foreground,
                                  ),
                                ),
                                CodeConfig(
                                  style: TextStyle(
                                    backgroundColor: colorScheme.muted,
                                    fontFamily: 'monospace',
                                    color: colorScheme.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Stats Section
                          if (meta['stats'] != null) ...[
                            Text(
                              context.l10n.quickStats,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.foreground,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildStatRow(
                                context,
                                colorScheme,
                                context.l10n.currentBalance,
                                _formatScenarioAmount(
                                    context, curr, currencySymbol)),
                            _buildStatRow(
                                context,
                                colorScheme,
                                context.l10n.projectedNoChange,
                                _formatScenarioAmount(
                                    context, proj, currencySymbol)),
                            _buildStatRow(
                                context,
                                colorScheme,
                                context.l10n.avgDailyNet,
                                _formatScenarioAmount(
                                    context, avg, currencySymbol)),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      });
}

Widget _buildStatRow(
    BuildContext context, ColorScheme colorScheme, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
      ],
    ),
  );
}
