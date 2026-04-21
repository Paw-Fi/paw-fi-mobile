import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:moneko/core/theme/theme.dart'; // Unnecessary (covered by core.dart)

import 'package:moneko/core/core.dart';
import 'package:moneko/core/utils/text_sanitizer.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';

import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:image_picker/image_picker.dart';

import 'package:moneko/features/households/presentation/widgets/household_home_content.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/cached_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/home/presentation/models/expense_entry.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/models/user_contact.dart';
import 'package:moneko/features/home/presentation/models/daily_budget_entry.dart';
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/features/home/presentation/state/home_page_command_provider.dart';
import 'package:moneko/features/home/presentation/state/user_categories_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/pages/thai_language_prompt_logic.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/core/app/locale_provider.dart';
import 'package:moneko/core/app/app_initialization_provider_v2.dart';
import 'package:moneko/features/home/presentation/widgets/mom_trend_bar.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/services/preferred_language_sync_service.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_target.dart';
import 'package:moneko/features/home/presentation/state/home_spotlight_providers.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/home/presentation/widgets/connect_social_banner.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/widgets/dashboard_lazy_widgets.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:go_router/go_router.dart';
import 'package:moneko/core/utils/image_picker_guard.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';
import 'package:moneko/core/preview/preview_data.dart';
import 'package:moneko/shared/widgets/moneko_alert_dialog.dart';

import 'package:moneko/shared/widgets/status_bar_overlay_region.dart';

// ============================================================================
// HOME PAGE
// ============================================================================

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  bool _hasCompletedThaiLanguagePromptCheck = false;
  bool _isCheckingThaiLanguagePrompt = false;

  late final SpotlightTourController _fabTourController;
  late final HomeDebugTrace _homeTrace;
  String? _lastHomeDebugSignature;
  String? _lastHomePerfSignature;
  String? _lastPersonalRepoSignature;
  String? _lastPersonalDashboardSignature;
  bool _didLogFirstUsefulPaint = false;

  static const bool _enableDebugLogs =
      bool.fromEnvironment('MONEKO_DEBUG_LOGS', defaultValue: false);

  void _debugPrint(String? message, {int? wrapWidth}) {
    if (foundation.kDebugMode && _enableDebugLogs) {
      foundation.debugPrint(message, wrapWidth: wrapWidth);
    }
  }

  @override
  void initState() {
    super.initState();

    _fabTourController = ref.read(homeSpotlightControllerProvider);
    _homeTrace = HomeDebugTrace(
      label: 'HomePageOpen',
      enabled: ref.read(homeDebugLoggingEnabledProvider),
      logSink: ref.read(homeDebugLogSinkProvider),
    );
    _homeTrace.mark('page-mounted');

    // Initialize filters on first mount
    // NOTE: Analytics data is loaded by app_initialization_provider - no need to trigger here
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final isPreview = ref.read(previewModeProvider).isActive;
      if (isPreview) {
        final preferredCurrency =
            PreviewMockData.contact.preferredCurrency?.toUpperCase();
        if (preferredCurrency != null && preferredCurrency.isNotEmpty) {
          ref
              .read(homeFilterProvider.notifier)
              .bootstrapSelectedCurrency(preferredCurrency);
        }
      }
      // Initialize date range filter from local storage
    });
  }

  void _maybeLogHomeDebugSnapshot({
    required HouseholdScope householdScope,
    required Set<String> portfolioHouseholdIds,
    required String? selectedCurrency,
  }) {
    if (!_enableDebugLogs) return;
    final selected = ref.read(selectedHouseholdProvider);
    final selectedHouseholdId =
        selected.householdId ?? selected.household?.id ?? 'null';
    final selectedHouseholdName = selected.household?.name ?? 'null';

    final signature = [
      'vm=${householdScope.viewMode}',
      'selected=$selectedHouseholdId',
      'portfolios=${portfolioHouseholdIds.length}',
      'cur=${selectedCurrency ?? "null"}',
      'portfolioIds=${portfolioHouseholdIds.length}',
    ].join('|');

    if (_lastHomeDebugSignature == signature) return;
    _lastHomeDebugSignature = signature;

    _debugPrint('🧭 [HomePageDebug] ===== Snapshot =====');
    _debugPrint('🧭 [HomePageDebug] viewMode=${householdScope.viewMode}');
    _debugPrint(
        '🧭 [HomePageDebug] selectedHouseholdId=$selectedHouseholdId name=$selectedHouseholdName');
    _debugPrint(
        '🧭 [HomePageDebug] isPortfolioSelected=${householdScope.isPortfolioSelected}');
    _debugPrint(
        '🧭 [HomePageDebug] isHouseholdView=${householdScope.isHouseholdView}');
    _debugPrint(
        '🧭 [HomePageDebug] portfolioHouseholdIds(${portfolioHouseholdIds.length})=$portfolioHouseholdIds');
    _debugPrint(
        '🧭 [HomePageDebug] selectedCurrency=${selectedCurrency ?? "null"}');
    _debugPrint('🧭 [HomePageDebug] ====================');
  }

  void _scheduleThaiLanguagePromptCheck(UserContact? contact) {
    if (_hasCompletedThaiLanguagePromptCheck || _isCheckingThaiLanguagePrompt) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _hasCompletedThaiLanguagePromptCheck ||
          _isCheckingThaiLanguagePrompt) {
        return;
      }

      unawaited(_maybeShowThaiLanguagePrompt(contact));
    });
  }

  Future<void> _maybeShowThaiLanguagePrompt(UserContact? contact) async {
    if (_hasCompletedThaiLanguagePromptCheck || _isCheckingThaiLanguagePrompt) {
      return;
    }

    if (ref.read(previewModeProvider).isActive) {
      _hasCompletedThaiLanguagePromptCheck = true;
      return;
    }

    _isCheckingThaiLanguagePrompt = true;

    try {
      final currentLocale = Localizations.localeOf(context);
      final route = ModalRoute.of(context);
      final authUserId = ref.read(authProvider).uid;
      final promptScopeId = authUserId.isNotEmpty
          ? authUserId
          : (contact?.userId?.trim().isNotEmpty == true
              ? contact!.userId!.trim()
              : contact?.id ?? 'anonymous');
      final prefs = ref.read(sharedPreferencesProvider);
      final checkedPrefsKey =
          thaiLanguagePromptCheckedPrefsKeyForUser(promptScopeId);
      final decision = evaluateThaiLanguagePrompt(
        hasChecked: prefs.getBool(checkedPrefsKey) ?? false,
        contact: contact,
        currentLocale: currentLocale,
      );

      switch (decision.action) {
        case ThaiLanguagePromptAction.waitForContact:
          return;
        case ThaiLanguagePromptAction.skipForNow:
          _hasCompletedThaiLanguagePromptCheck = true;
          return;
        case ThaiLanguagePromptAction.markCheckedAndSkip:
          await prefs.setBool(checkedPrefsKey, true);
          _hasCompletedThaiLanguagePromptCheck = true;
          return;
        case ThaiLanguagePromptAction.showPrompt:
          break;
      }

      if (!mounted || route == null || !route.isCurrent) {
        return;
      }

      final result = await MonekoAlertDialog.show(
        context: context,
        title: 'สวัสดี!',
        description:
            'ตอนนี้ Moneko รองรับภาษาไทยแล้วนะ อยากเปลี่ยนแอปเป็นภาษาไทยเลยไหม',
        confirmLabel: 'เปลี่ยนเป็นภาษาไทย',
        cancelLabel: 'ไว้ก่อน',
      );

      await prefs.setBool(checkedPrefsKey, true);
      _hasCompletedThaiLanguagePromptCheck = true;

      if (result?.confirmed != true || !mounted) {
        return;
      }

      const thaiLocale = Locale('th');
      await ref.read(localeProvider.notifier).setLocale(thaiLocale);

      final userId = ref.read(authProvider).uid;
      if (userId.isEmpty) {
        return;
      }

      await ref.read(preferredLanguageSyncServiceProvider).syncForUserSafely(
            userId: userId,
            locale: normalizeAppLocale(thaiLocale),
            force: true,
          );
    } finally {
      _isCheckingThaiLanguagePrompt = false;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _resolveLogTargetLabelForAi() {
    final householdId = _resolveHouseholdIdForAi();
    if (householdId == null) return context.l10n.personalScope;

    final selected = ref.read(selectedHouseholdProvider);
    return selected.household?.name ?? context.l10n.forUs;
  }

  String _truncateForToast(String? value, {int maxLen = 28}) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return '';
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen - 1)}…';
  }

  String _formatAiLoggedToastMessage(
    List<
            ({
              ParsedExpense transaction,
              String optimisticId,
              Map<String, dynamic> raw
            })>
        parsed,
  ) {
    if (parsed.isEmpty) return context.l10n.failedToAnalyzeNoData;

    final target = _resolveLogTargetLabelForAi();
    final count = parsed.length;

    final allIncome = parsed.every((e) => e.transaction.isIncome);
    final allExpense = parsed.every((e) => !e.transaction.isIncome);

    if (count == 1) {
      final tx = parsed.first.transaction;
      final savedLabel =
          tx.isIncome ? context.l10n.incomeSaved : context.l10n.expenseSaved;
      final desc = _truncateForToast(tx.description);
      final detail = desc.isEmpty ? '' : ' • $desc';
      return '$savedLabel ${tx.formattedAmount}$detail → $target';
    }

    if (allIncome) {
      return '${context.l10n.incomeSaved} ($count) → $target';
    }
    if (allExpense) {
      return '${context.l10n.expenseSaved} ($count) → $target';
    }
    return '${context.l10n.transactions} ($count) → $target';
  }

  List<Map<String, dynamic>> _buildHouseholdMemberContext(String householdId) {
    final membersAsync = ref.read(householdMembersProvider(householdId));
    final members = membersAsync.valueOrNull;
    if (members == null || members.isEmpty) return const [];

    return members
        .map(
          (m) => {
            'userId': m.userId,
            if (m.userName != null && m.userName!.trim().isNotEmpty)
              'userName': m.userName,
            if (m.userEmail != null && m.userEmail!.trim().isNotEmpty)
              'userEmail': m.userEmail,
          },
        )
        .toList(growable: false);
  }

  // ignore: unused_element
  Future<void> _handleCameraCapture() async {
    _debugPrint('🎥 Starting camera capture...');

    try {
      // On iOS, image_picker handles permissions internally
      // Just try to open the camera directly
      final XFile? photo = await pickImageWithGuard(
        picker: _imagePicker,
        source: ImageSource.camera,
        imageQuality: 85,
      );

      _debugPrint('🎥 Photo captured: ${photo != null}');

      if (photo != null && mounted) {
        await _processExpense(imagePath: photo.path);
      } else if (photo == null) {
        _debugPrint('🎥 User cancelled or permission denied');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
            context, '${context.l10n.failedToCapturePhoto}: ${e.toString()}');
      }
    }
  }

  Future<void> _processExpense({
    String? text,
    String? imagePath,
    Uint8List? audioBytes,
    String? audioContentType,
  }) async {
    final user = ref.read(authProvider);
    final contact = ref.read(dashboardUserContactProvider).valueOrNull;
    final householdId = _resolveHouseholdIdForAi();
    final scope = ref.read(householdScopeProvider);
    final isPortfolio = scope.isPortfolioSelected;

    // Show processing modal
    if (!mounted) return;

    showBlockingProcessingDialog(
      context: context,
      message: imagePath != null
          ? context.l10n.analyzingReceipt
          : context.l10n.analyzingExpense,
    );

    try {
      final timezoneOffsetMinutes =
          resolveUserTimezoneOffsetMinutes(contact?.preferredTimezone);
      final userNow = userNowFromOffsetMinutes(timezoneOffsetMinutes);
      final locale = Localizations.localeOf(context);
      final languageTag =
          locale.countryCode != null && locale.countryCode!.isNotEmpty
              ? '${locale.languageCode}-${locale.countryCode!.toUpperCase()}'
              : locale.languageCode;

      Map<String, dynamic> body = {
        'userId': user.uid,
        'date': formatDateOnlyYmd(userNow),
        'language': languageTag,
      };

      if (householdId != null && householdId.isNotEmpty) {
        body['householdId'] = householdId;
        body['isPortfolio'] = isPortfolio;
        if (!isPortfolio) {
          final memberContext = _buildHouseholdMemberContext(householdId);
          if (memberContext.isNotEmpty) {
            body['householdMembers'] = memberContext;
          }
        }
      }

      // Always use selected currency as default (same as personal expense)
      // Backend will use this as a fallback if no currency is detected in the text/image.
      // If this is also missing, backend defaults to USD.
      final filterState = ref.read(homeFilterProvider);
      final selectedCurrency = filterState.selectedCurrency;
      if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
        body['currency'] = selectedCurrency.toUpperCase();
      } else if (contact?.preferredCurrency != null) {
        body['currency'] = contact!.preferredCurrency!.toUpperCase();
      }

      // Add either text, image, audio, or attachments to the request
      if (text != null) {
        body['text'] = text;
      } else if (imagePath != null) {
        // Read image bytes and convert to base64
        final imageFile = File(imagePath);
        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        // Determine content type from file extension
        String contentType = 'image/jpeg';
        final extension = imagePath.split('.').last.toLowerCase();
        if (extension == 'png') {
          contentType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          contentType = 'image/jpeg';
        } else if (extension == 'heic') {
          contentType = 'image/heic';
        }

        body['image'] = {
          'data': base64Image,
          'contentType': contentType,
        };
      }

      if (audioBytes != null && audioBytes.isNotEmpty) {
        final base64Audio = base64Encode(audioBytes);
        body['audio'] = {
          'data': base64Audio,
          'contentType': audioContentType ?? 'audio/mpeg',
        };
      }

      // Call analyze-expense endpoint to extract structured transactions (then log immediately).
      // Explicitly pass JWT so the Edge Function can enrich household context
      // (householdMembers) under RLS. This is required for reliable split output.
      final session = supabase.auth.currentSession;
      final response = await supabase.functions.invoke(
        'analyze-expense',
        body: body,
        headers: session != null
            ? <String, String>{
                'Authorization': 'Bearer ${session.accessToken}',
              }
            : null,
      );

      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      _debugPrint('Analysis response received');

      if (response.data != null && response.data['success'] == true) {
        final responseData = response.data['data'];

        if (responseData != null && responseData['items'] != null) {
          List items = List.from(responseData['items'] as List);
          // Safety filter: drop total/subtotal rows when multiple items exist
          if (items.length > 1) {
            bool isTotalLike(dynamic it) {
              final desc = (it is Map && it['description'] is String)
                  ? (it['description'] as String)
                  : '';
              return RegExp(r'(sub\s*total|subtotal|grand\s*total|total)',
                      caseSensitive: false)
                  .hasMatch(desc);
            }

            final filtered = items.where((it) => !isTotalLike(it)).toList();
            if (filtered.isNotEmpty) items = filtered;
            // Additional check: if any item equals sum of others, drop it
            double amt(dynamic it) {
              final a = (it is Map && it['amount'] != null)
                  ? (it['amount'] as num).toDouble()
                  : 0.0;
              return a;
            }

            items = items.where((it) {
              final others = items.where((x) => !identical(x, it)).toList();
              final sumOthers = others.fold<double>(0.0, (s, x) => s + amt(x));
              return (amt(it) - sumOthers).abs() > 1e-6;
            }).toList();
          }

          if (items.isNotEmpty) {
            final analyticsContactId =
                ref.read(dashboardUserContactProvider).valueOrNull?.id;

            // Parse ALL items and optimistic-log them immediately.
            final parsed = items
                .map((rawItem) {
                  final item = rawItem is Map
                      ? Map<String, dynamic>.from(rawItem)
                      : <String, dynamic>{};
                  final rawDate = item['date']?.toString();
                  final parsedDateOnly = tryParseDateOnlyYmd(rawDate);
                  DateTime? accountingDate;
                  if (parsedDateOnly != null) {
                    accountingDate = parsedDateOnly;
                  } else {
                    final parsedInstant = DateTime.tryParse(rawDate ?? '');
                    if (parsedInstant != null) {
                      final effective = toEffectiveWallTime(
                        utcOrLocalInstant: parsedInstant,
                        preferredTimezone: contact?.preferredTimezone,
                      );
                      accountingDate = DateTime(
                          effective.year, effective.month, effective.day);
                    }
                  }
                  if (accountingDate == null) {
                    _debugPrint('Skipping AI item with invalid date');
                    return null;
                  }
                  final isIncome =
                      (item['type']?.toString().toLowerCase() == 'income');
                  final transaction = ParsedExpense(
                    isIncome: isIncome,
                    amount: (item['amount'] as num).toDouble(),
                    // Normalize income categories to at least 'income' umbrella if model returns a granular one
                    category: (item['category'] as String?)?.isNotEmpty == true
                        ? (isIncome
                            ? (item['category'] as String)
                            : item['category'] as String)
                        : (isIncome ? 'income' : 'other'),
                    currency: item['currency'] as String,
                    currencySymbol: item['currencySymbol'] as String? ?? '\$',
                    date: accountingDate,
                    description: item['description'] is String
                        ? sanitizeUtf16(item['description'] as String)
                        : null,
                    localImagePath: imagePath,
                    payerUserId: (item['payerUserId'] is String)
                        ? (item['payerUserId'] as String)
                        : null,
                    payerHint: (item['payerHint'] is String)
                        ? (item['payerHint'] as String)
                        : (item['payerName'] is String)
                            ? (item['payerName'] as String)
                            : (item['paidBy'] is String)
                                ? (item['paidBy'] as String)
                                : (item['payerEmail'] is String)
                                    ? (item['payerEmail'] as String)
                                    : null,
                  );

                  final optimisticId = makeOptimisticTransactionId();
                  final entry = buildOptimisticEntry(
                    transaction: transaction,
                    optimisticId: optimisticId,
                    userId: user.uid,
                    contactId: analyticsContactId,
                    householdId: householdId,
                    type: isIncome ? 'income' : 'expense',
                  );

                  addOptimisticTransaction(
                    ref: ref,
                    entry: entry,
                    householdId: householdId,
                  );

                  return (
                    transaction: transaction,
                    optimisticId: optimisticId,
                    raw: item
                  );
                })
                .whereType<
                    ({
                      ParsedExpense transaction,
                      String optimisticId,
                      Map<String, dynamic> raw
                    })>()
                .toList();

            if (parsed.isEmpty) {
              AppToast.info(
                  context, context.l10n.noExpenseInformationExtracted);
              return;
            }

            AppToast.success(
              context,
              _formatAiLoggedToastMessage(parsed),
            );

            final container = ProviderScope.containerOf(context, listen: false);
            unawaited(
              _persistAiTransactions(
                container: container,
                userId: user.uid,
                householdId: householdId,
                isPortfolio: isPortfolio,
                transactions: parsed,
                localImagePath: imagePath,
                preferredTimezone: contact?.preferredTimezone,
              ),
            );
          } else {
            AppToast.info(context, context.l10n.noExpenseInformationExtracted);
          }
        } else {
          AppToast.info(context, context.l10n.failedToAnalyzeNoData);
        }
      } else {
        final message = ErrorHandler.getUserFriendlyMessage(
          response.data,
          context: BackendErrorContext.analyzeExpense,
        );
        AppToast.error(context, message);
      }
    } catch (e) {
      _debugPrint('Error in analysis: $e');
      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      AppToast.error(
        context,
        ErrorHandler.getUserFriendlyMessage(
          e,
          context: BackendErrorContext.analyzeExpense,
        ),
      );
    }
  }

  String? _resolveHouseholdIdForAi() {
    final viewMode = ref.read(viewModeProvider);
    if (viewMode.mode != ViewMode.household) return null;
    final scope = ref.read(householdScopeProvider);
    return scope.selectedHouseholdId;
  }

  Future<void> _persistAiTransactions({
    required ProviderContainer container,
    required String userId,
    required String? householdId,
    required bool isPortfolio,
    required List<
            ({
              ParsedExpense transaction,
              String optimisticId,
              Map<String, dynamic> raw
            })>
        transactions,
    String? localImagePath,
    String? preferredTimezone,
  }) async {
    var didPersistAny = false;

    String? normalizeBucketId(String? value) {
      final trimmed = value?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }

    void upsertSavedEntry({
      required String optimisticId,
      required ExpenseEntry savedEntry,
    }) {
      final fromBucket = normalizeBucketId(householdId);
      final toBucket = normalizeBucketId(savedEntry.householdId);

      if (fromBucket == toBucket) {
        replaceOptimisticTransactionWithContainer(
          container: container,
          optimisticId: optimisticId,
          savedEntry: savedEntry,
          householdId: fromBucket,
        );
        return;
      }

      removeOptimisticTransactionWithContainer(
        container: container,
        optimisticId: optimisticId,
        householdId: fromBucket,
      );
      addOptimisticTransactionWithContainer(
        container: container,
        entry: savedEntry,
        householdId: toBucket,
      );
    }

    String? receiptUrl;
    if (localImagePath != null && localImagePath.isNotEmpty) {
      receiptUrl = await container
          .read(expenseSaveNotifierProvider.notifier)
          .uploadReceiptImage(File(localImagePath), userId);
    }

    final timezoneOffsetMinutes =
        resolveUserTimezoneOffsetMinutes(preferredTimezone);
    final userNow = userNowFromOffsetMinutes(timezoneOffsetMinutes);
    final clientCreatedAtIso = utcInstantForUserLocalDateTime(
      localDateTime: userNow,
      offsetMinutes: timezoneOffsetMinutes,
    ).toIso8601String();

    for (final item in transactions) {
      try {
        final transactionDateYmd = formatDateOnlyYmd(item.transaction.date);

        if (item.transaction.isIncome) {
          final response = await supabase.functions.invoke(
            'save-income',
            body: {
              'userId': userId,
              'amount': item.transaction.amount,
              'category': item.transaction.category,
              'currency': item.transaction.currency,
              'date': transactionDateYmd,
              'clientCreatedAt': clientCreatedAtIso,
              if (item.transaction.description?.isNotEmpty == true)
                'description': item.transaction.description,
              if (householdId != null && householdId.isNotEmpty)
                'householdId': householdId,
              if (householdId != null && householdId.isNotEmpty)
                'isPortfolio': isPortfolio,
            },
          );

          if (response.data == null || response.data['success'] != true) {
            throw Exception(response.data?['error'] ?? 'Failed to save income');
          }

          final saved = Map<String, dynamic>.from(response.data['data'] as Map);
          final savedEntry = ExpenseEntry.fromJson(saved);

          upsertSavedEntry(
            optimisticId: item.optimisticId,
            savedEntry: savedEntry,
          );
          didPersistAny = true;
          continue;
        }

        final rawPayerUserId = item.raw['payerUserId'];
        final payerUserId =
            rawPayerUserId is String && rawPayerUserId.trim().isNotEmpty
                ? rawPayerUserId.trim()
                : null;

        final rawCustomSplits = item.raw['customSplits'];
        final customSplits = rawCustomSplits is Map
            ? Map<String, dynamic>.from(rawCustomSplits)
            : null;
        final splitType =
            customSplits?['splitType']?.toString().trim().toLowerCase();
        String? splitValueKey;
        switch (splitType) {
          case 'amount':
            splitValueKey = 'amount';
            break;
          case 'percentage':
            splitValueKey = 'percentage';
            break;
          case 'shares':
            splitValueKey = 'shares';
            break;
        }
        final memberSplits = customSplits?['memberSplits'];
        final hasExplicitSplitValues = splitValueKey != null &&
            memberSplits is List &&
            memberSplits.any((entry) =>
                entry is Map &&
                entry[splitValueKey!] is num &&
                (entry['userId']?.toString().trim().isNotEmpty ?? false));
        final safeCustomSplits = hasExplicitSplitValues ? customSplits : null;

        final response = await supabase.functions.invoke(
          'save-expense',
          body: {
            'userId': userId,
            'amount': item.transaction.amount,
            'category': item.transaction.category,
            'currency': item.transaction.currency,
            'date': transactionDateYmd,
            'clientCreatedAt': clientCreatedAtIso,
            if (item.transaction.description?.isNotEmpty == true)
              'description': item.transaction.description,
            if (receiptUrl != null) 'receiptImageUrl': receiptUrl,
            if (householdId != null && householdId.isNotEmpty)
              'householdId': householdId,
            if (householdId != null && householdId.isNotEmpty)
              'isPortfolio': isPortfolio,
            if (householdId != null &&
                householdId.isNotEmpty &&
                payerUserId != null)
              'payerUserId': payerUserId,
            if (householdId != null &&
                householdId.isNotEmpty &&
                safeCustomSplits != null)
              'customSplits': safeCustomSplits,
          },
        );

        if (response.data == null || response.data['success'] != true) {
          throw Exception(response.data?['error'] ?? 'Failed to save expense');
        }

        final saved = Map<String, dynamic>.from(response.data['data'] as Map);
        final savedEntry = ExpenseEntry.fromJson(saved);

        upsertSavedEntry(
          optimisticId: item.optimisticId,
          savedEntry: savedEntry,
        );
        didPersistAny = true;
      } catch (error) {
        removeOptimisticTransactionWithContainer(
          container: container,
          optimisticId: item.optimisticId,
          householdId: householdId,
        );
        _debugPrint('❌ Failed to persist AI transaction: $error');
      }
    }

    if (didPersistAny) {
      await container
          .read(expenseSaveNotifierProvider.notifier)
          .invalidateAfterBatch(
            userId: userId,
            householdId: householdId,
          );
    }
  }

  // ignore: unused_element
  void _showTextInputDrawer() {
    showTextInputDrawer(
      context,
      _textController,
      (text) async {
        await _processExpense(text: text);
      },
      onSubmitAudio: (audioBytes, contentType) async {
        await _processExpense(
          audioBytes: audioBytes,
          audioContentType: contentType,
        );
      },
    );
  }

  Future<void> _startFabTourIfNeeded() async {
    final user = ref.read(authProvider);
    if (user.isEmpty) return;

    final location = GoRouterState.of(context).uri.path;
    if (location != '/dashboard') return;

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;

    await _fabTourController.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    ref.watch(userCategoryConfigProvider);
    final initUserContact = ref
        .watch(appInitializationV2Provider.select((state) => state.data?.user));
    final filterState = ref.watch(homeFilterProvider);
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final householdScope = ref.watch(householdScopeProvider);
    final portfolioHouseholdIds = householdScope.portfolioHouseholdIds;
    ref.listen<HomePageCommand?>(homePageCommandProvider, (previous, next) {
      if (next == null) {
        return;
      }
      _showTextInputDrawer();
      ref.read(homePageCommandProvider.notifier).state = null;
    });

    // Global currency remains shared; date ranges move to per-card filters
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();
    final shouldShowFab = _shouldShowFAB(householdScope, householdsAsync);

    final homePerfSignature = [
      'scope=${householdScope.activeAccountType.name}',
      'householdsLoading=${householdsAsync.isLoading}',
      'householdsHasError=${householdsAsync.hasError}',
      'householdsCount=${householdsAsync.valueOrNull?.length ?? 0}',
      'shouldShowFab=$shouldShowFab',
      'selectedCurrency=${selectedCurrency ?? '<none>'}',
      'user=${user.uid.isEmpty ? '<empty>' : user.uid}',
    ].join('|');
    if (_lastHomePerfSignature != homePerfSignature) {
      _lastHomePerfSignature = homePerfSignature;
      _homeTrace.mark('page-state', {
        'scope': householdScope.activeAccountType.name,
        'householdsLoading': householdsAsync.isLoading,
        'householdsHasError': householdsAsync.hasError,
        'householdsCount': householdsAsync.valueOrNull?.length,
        'shouldShowFab': shouldShowFab,
        'selectedCurrency': selectedCurrency,
        'user': user.uid.isEmpty ? '<empty>' : user.uid,
      });
    }

    _maybeLogHomeDebugSnapshot(
      householdScope: householdScope,
      portfolioHouseholdIds: portfolioHouseholdIds,
      selectedCurrency: selectedCurrency,
    );

    const isInitialAnalyticsLoading = false;

    _scheduleThaiLanguagePromptCheck(initUserContact);

    if (!_didLogFirstUsefulPaint &&
        !isInitialAnalyticsLoading &&
        (!householdScope.isHouseholdView || !householdsAsync.isLoading)) {
      _didLogFirstUsefulPaint = true;
      _homeTrace.mark('first-useful-paint', {
        'scope': householdScope.activeAccountType.name,
        'selectedCurrency': selectedCurrency,
      });
    }

    if (shouldShowFab && !user.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startFabTourIfNeeded();
      });
    }

    final scrollView = CustomScrollView(
      slivers: [
        if (householdScope.isHouseholdView) ...[
          const HouseholdHomeContent(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ] else ...[
          // Personal mode - show customizable dashboard
          const SliverToBoxAdapter(child: ConnectSocialBanner()),
          Consumer(
            builder: (context, ref, _) {
              final repoAsync = ref.watch(dashboardRepositoryFutureProvider);
              final repoSignature = [
                'loading=${repoAsync.isLoading}',
                'hasError=${repoAsync.hasError}',
                'hasValue=${repoAsync.hasValue}',
              ].join('|');
              if (_lastPersonalRepoSignature != repoSignature) {
                _lastPersonalRepoSignature = repoSignature;
                _homeTrace.mark('personal-repository-async-state', {
                  'loading': repoAsync.isLoading,
                  'hasError': repoAsync.hasError,
                  'hasValue': repoAsync.hasValue,
                });
              }

              return repoAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, st) => SliverToBoxAdapter(
                  child:
                      Text('${context.l10n.errorInitializingRepository}: $e'),
                ),
                data: (_) {
                  final dashboardContact =
                      ref.watch(dashboardUserContactProvider).valueOrNull;
                  final dashboardBudgets =
                      ref.watch(dashboardPersonalBudgetsProvider).valueOrNull ??
                          const <DailyBudgetEntry>[];
                  final timezoneOffsetMinutes =
                      resolveUserTimezoneOffsetMinutes(
                    dashboardContact?.preferredTimezone,
                  );
                  final userNow =
                      userNowFromOffsetMinutes(timezoneOffsetMinutes);
                  final netFilterState = ref.watch(
                    cardDateFilterProvider(HomeCardFilterId.netCashflow),
                  );
                  final netRange = getDateRangeFromFilter(
                    netFilterState.dateRangeFilter,
                    netFilterState.customStartDate,
                    netFilterState.customEndDate,
                    now: userNow,
                  );
                  final netFrom = netRange['from']!;
                  final netTo = netRange['to']!;
                  final netBudgets = dashboardBudgets.where((budget) {
                    final d = DateTime(
                        budget.date.year, budget.date.month, budget.date.day);
                    final dateOk = !d.isBefore(netFrom) && !d.isAfter(netTo);
                    final currencyOk = selectedCurrency == null ||
                        (budget.currency?.toUpperCase() == selectedCurrency);
                    return dateOk && currencyOk;
                  }).toList();
                  final dashboardAsync =
                      ref.watch(personalDashboardProvider(user.uid));
                  final dashboardSignature = [
                    'loading=${dashboardAsync.isLoading}',
                    'hasError=${dashboardAsync.hasError}',
                    'hasValue=${dashboardAsync.hasValue}',
                    'count=${dashboardAsync.valueOrNull?.length ?? 0}',
                  ].join('|');
                  if (_lastPersonalDashboardSignature != dashboardSignature) {
                    _lastPersonalDashboardSignature = dashboardSignature;
                    _homeTrace.mark('personal-dashboard-async-state', {
                      'loading': dashboardAsync.isLoading,
                      'hasError': dashboardAsync.hasError,
                      'hasValue': dashboardAsync.hasValue,
                      'widgetCount': dashboardAsync.valueOrNull?.length,
                    });
                  }

                  return dashboardAsync.when(
                    loading: () => const SliverToBoxAdapter(
                        child: SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()))),
                    error: (e, st) => SliverToBoxAdapter(
                        child:
                            Text('${context.l10n.errorLoadingDashboard}: $e')),
                    data: (configs) {
                      return DraggableDashboardList(
                        configs: configs,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .reorder(oldIndex, newIndex);
                        },
                        onToggleVisibility: (id) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .toggleVisibility(id);
                        },
                        onUpdateConfig: (id,
                            {dateRange, viewMode, start, end}) {
                          ref
                              .read(
                                  personalDashboardProvider(user.uid).notifier)
                              .updateConfig(id,
                                  dateRange: dateRange,
                                  viewMode: viewMode,
                                  start: start,
                                  end: end);
                        },
                        widgetBuilders: {
                          DashboardWidgetType.spendingSummary:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardSpendingSummaryCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      contact: dashboardContact,
                                      userNow: userNow,
                                    ),
                                  ),
                          DashboardWidgetType.netCashflow: (context, config) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: SizedBox(
                                  height: 180,
                                  child: Row(
                                    children: [
                                      const Expanded(child: MoMTrendBar()),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: LazyDashboardNetCashflowCard(
                                          config: config,
                                          colorScheme: colorScheme,
                                          contact: dashboardContact,
                                          userNow: userNow,
                                          budgets: netBudgets,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          DashboardWidgetType.financialCalendar:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardFinancialCalendarCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      fallbackCurrency: selectedCurrency ??
                                          dashboardContact?.preferredCurrency ??
                                          'USD',
                                    ),
                                  ),
                          DashboardWidgetType.recentTransactions:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardRecentTransactionsCard(
                                      colorScheme: colorScheme,
                                      contact: dashboardContact,
                                    ),
                                  ),
                          DashboardWidgetType.spendingBreakdownChart:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardSpendingBreakdownCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      userNow: userNow,
                                    ),
                                  ),
                          DashboardWidgetType.whereTheMoneyWent:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardWhereTheMoneyWentCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                      userNow: userNow,
                                    ),
                                  ),
                          DashboardWidgetType.walletSummary:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: LazyDashboardWalletSummaryCard(
                                      config: config,
                                      colorScheme: colorScheme,
                                    ),
                                  ),
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          // Edit Button
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ], // end of else block for Personal mode
      ],
    );

    final scrollContent = householdScope.isPersonalView
        ? Skeletonizer(
            enabled: isInitialAnalyticsLoading,
            effect: ShimmerEffect(
              baseColor: colorScheme.skeletonBase,
              highlightColor: colorScheme.skeletonHighlight,
            ),
            child: scrollView,
          )
        : scrollView;

    return StatusBarOverlayRegion(
        child: AdaptiveScaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              final user = ref.read(authProvider);
              if (user.uid.isEmpty) return;

              // Refresh based on current view mode
              if (householdScope.isHouseholdView) {
                // In household mode: invalidate ALL household-related providers
                _debugPrint('🔄 Pull-to-refresh: Refreshing household data');
                ref.read(cacheInvalidatorProvider).invalidateAll();
                ref.invalidate(userHouseholdsProvider(user.uid));
                ref.invalidate(householdExpensesProvider);
                ref.invalidate(cachedHouseholdExpensesProvider);
                ref.invalidate(householdSplitsProvider);
                ref.invalidate(cachedHouseholdSplitsProvider);
                ref.invalidate(householdBudgetsProvider);
                ref.invalidate(householdMembersProvider);
                _debugPrint(
                    '✅ Invalidated: households, expenses, splits, cached splits/expenses, budgets, members');
              } else {
                await ref.read(analyticsProvider.notifier).loadData(user.uid);
              }

              ref.read(dashboardRefreshSignalProvider.notifier).state += 1;

              // Keep other tabs and selectors consistent.
              ref.invalidate(pocketsProvider);
              ref.invalidate(currencyTransactionCountsProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: scrollContent,
          ),
        ],
      ),
      floatingActionButton: _shouldShowFAB(householdScope, householdsAsync)
          ? SpotlightTarget(
              controller: _fabTourController,
              id: 'home_unified_fab',
              title: context.l10n.homeFabTourTitle,
              description: context.l10n.homeFabTourDescription,
              placement: SpotlightPlacement.top,
              padding: 6,
              borderRadius: 34,
              child: const Padding(
                padding: EdgeInsets.all(0),
                child: HomeAiExpandableFab(),
              ),
            )
          : null,
    ));
  }

  /// Determine if FAB should be shown
  /// Hide FAB when in household mode with no households (showing onboarding)
  bool _shouldShowFAB(
    HouseholdScope scope,
    AsyncValue<List<Household>> householdsAsync,
  ) {
    // Always show FAB in personal mode (includes portfolios).
    if (scope.isPersonalView) {
      return true;
    }

    // In household mode, hide FAB if households are empty (showing onboarding).
    return householdsAsync.maybeWhen(
      data: (households) => households.isNotEmpty,
      orElse: () => true, // Show FAB during loading or error states
    );
  }

  // Global date helpers have been removed; per-card filters now own all
  // date-range logic, and analytics loads all-time data.
}
