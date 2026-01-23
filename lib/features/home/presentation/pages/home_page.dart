import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// import 'package:moneko/core/theme/theme.dart'; // Unnecessary (covered by core.dart)

import 'package:moneko/core/core.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';

import 'package:moneko/features/home/presentation/enums/date_range_filter.dart';
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
import 'package:moneko/features/home/presentation/state/ai_quick_log.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/pages/transactions_page.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/home/presentation/widgets/mom_trend_bar.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_target.dart';
import 'package:moneko/features/home/presentation/state/home_spotlight_providers.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/features/households/presentation/widgets/financial_calendar_widget.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_config.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_widgets.dart';
import 'package:moneko/features/insights/presentation/widgets/category_guide_dialog.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:go_router/go_router.dart';

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

  late final SpotlightTourController _fabTourController;
  String? _lastHomeDebugSignature;

  @override
  void initState() {
    super.initState();

    _fabTourController = ref.read(homeSpotlightControllerProvider);

    // Initialize filters on first mount
    // NOTE: Analytics data is loaded by app_initialization_provider - no need to trigger here
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize currency filter on first load (one-time)
      // Check provider state instead of local flag to prevent race conditions
      final currentCurrency = ref.read(homeFilterProvider).selectedCurrency;
      if (currentCurrency == null) {
        await _initializeCurrencyFilter();
      }
      // Initialize date range filter from local storage
      await _initializeDateRangeFilter();
    });
  }

  void _maybeLogHomeDebugSnapshot({
    required AnalyticsData analyticsData,
    required HouseholdScope householdScope,
    required Set<String> portfolioHouseholdIds,
    required String? selectedCurrency,
    required List<ExpenseEntry> personalExpensesAll,
  }) {
    final selected = ref.read(selectedHouseholdProvider);
    final selectedHouseholdId =
        selected.householdId ?? selected.household?.id ?? 'null';
    final selectedHouseholdName = selected.household?.name ?? 'null';

    final all = analyticsData.allExpenses;
    int portfolioCount = 0;
    int nonPortfolioHouseholdCount = 0;
    int nullHouseholdCount = 0;
    for (final e in all) {
      final hid = e.householdId;
      if (hid == null) {
        nullHouseholdCount += 1;
      } else if (portfolioHouseholdIds.contains(hid)) {
        portfolioCount += 1;
      } else {
        nonPortfolioHouseholdCount += 1;
      }
    }

    final signature = [
      'vm=${householdScope.viewMode}',
      'selected=$selectedHouseholdId',
      'portfolios=${portfolioHouseholdIds.length}',
      'cur=${selectedCurrency ?? "null"}',
      'allExpenses=${all.length}',
      'personalExpensesAll=${personalExpensesAll.length}',
      'budgets=${analyticsData.allBudgets.length}',
      'loading=${analyticsData.isLoading}',
      'err=${analyticsData.error ?? "null"}',
    ].join('|');

    if (_lastHomeDebugSignature == signature) return;
    _lastHomeDebugSignature = signature;

    debugPrint('🧭 [HomePageDebug] ===== Snapshot =====');
    debugPrint('🧭 [HomePageDebug] viewMode=${householdScope.viewMode}');
    debugPrint(
        '🧭 [HomePageDebug] selectedHouseholdId=$selectedHouseholdId name=$selectedHouseholdName');
    debugPrint(
        '🧭 [HomePageDebug] isPortfolioSelected=${householdScope.isPortfolioSelected}');
    debugPrint(
        '🧭 [HomePageDebug] isHouseholdView=${householdScope.isHouseholdView}');
    debugPrint(
        '🧭 [HomePageDebug] portfolioHouseholdIds(${portfolioHouseholdIds.length})=$portfolioHouseholdIds');
    debugPrint(
        '🧭 [HomePageDebug] selectedCurrency=${selectedCurrency ?? "null"}');
    debugPrint(
        '🧭 [HomePageDebug] analytics: isLoading=${analyticsData.isLoading} hasLoadedOnce=${analyticsData.hasLoadedOnce} error=${analyticsData.error ?? "null"}');
    debugPrint(
        '🧭 [HomePageDebug] analytics counts: allExpenses=${all.length} allBudgets=${analyticsData.allBudgets.length}');
    debugPrint(
        '🧭 [HomePageDebug] expense breakdown: householdId=null=$nullHouseholdCount portfolio=$portfolioCount nonPortfolioHousehold=$nonPortfolioHouseholdCount');
    debugPrint(
        '🧭 [HomePageDebug] derived personalExpensesAll=${personalExpensesAll.length}');

    final sample = all.take(3).toList(growable: false);
    for (var i = 0; i < sample.length; i++) {
      final e = sample[i];
      debugPrint(
          '🧭 [HomePageDebug] sample[$i] id=${e.id} date=${e.date.toIso8601String()} cents=${e.amountCents} cur=${e.currency} type=${e.type} hid=${e.householdId} cat=${e.category}');
    }
    debugPrint('🧭 [HomePageDebug] ====================');
  }

  Future<void> _initializeCurrencyFilter() async {
    // Early exit if already initialized (idempotency check)
    if (ref.read(homeFilterProvider).selectedCurrency != null) {
      return;
    }

    // Read current analytics data once (not listening to changes)
    final analyticsData = ref.read(analyticsProvider);
    final service = ref.read(currencyPreferenceServiceProvider);

    String selectedCurrency = 'USD'; // Default to USD

    // 1. Try local storage first
    try {
      final storedCurrency = await service.getSelectedCurrency();
      if (storedCurrency != null && storedCurrency.isNotEmpty) {
        selectedCurrency = storedCurrency;
      }
    } catch (e) {
      debugPrint('Error loading currency from storage: $e');
    }

    // 2. If no stored currency, use preferred currency if available
    if (selectedCurrency == 'USD' &&
        analyticsData.contact?.preferredCurrency != null) {
      selectedCurrency =
          analyticsData.contact!.preferredCurrency!.toUpperCase();
    }

    // Always set the currency (never null, always defaults to USD)
    if (mounted) {
      ref
          .read(homeFilterProvider.notifier)
          .setSelectedCurrency(selectedCurrency);
    }
  }

  Future<void> _initializeDateRangeFilter() async {
    try {
      final service = ref.read(dateRangePreferenceServiceProvider);
      final stored = await service.getSelectedDateRange();
      if (stored != null && stored.isNotEmpty) {
        final matched = DateRangeFilter.values.firstWhere(
          (e) => e.name == stored,
          orElse: () => DateRangeFilter.last30Days,
        );
        if (!mounted) return;
        final current = ref.read(homeFilterProvider).dateRangeFilter;
        if (current != matched) {
          ref.read(homeFilterProvider.notifier).setFilter(matched);
        }
      }
    } catch (e) {
      debugPrint('Error loading date range filter from storage: $e');
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
    debugPrint('🎥 Starting camera capture...');

    try {
      // On iOS, image_picker handles permissions internally
      // Just try to open the camera directly
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      debugPrint('🎥 Photo captured: ${photo != null}');

      if (photo != null && mounted) {
        await _processExpense(imagePath: photo.path);
      } else if (photo == null) {
        debugPrint('🎥 User cancelled or permission denied');
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
    final contact = ref.read(analyticsProvider).contact;
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
      final locale = Localizations.localeOf(context);
      final languageTag =
          locale.countryCode != null && locale.countryCode!.isNotEmpty
              ? '${locale.languageCode}-${locale.countryCode!.toUpperCase()}'
              : locale.languageCode;

      Map<String, dynamic> body = {
        'userId': user.uid,
        'date': DateTime.now().toIso8601String().split('T')[0],
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
      final response = await supabase.functions.invoke(
        'analyze-expense',
        body: body,
      );

      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      debugPrint('=== ANALYSIS RESPONSE ===');
      debugPrint('response.data: ${response.data}');
      debugPrint('========================');

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
            final analyticsContactId = ref.read(analyticsProvider).contact?.id;

            // Parse ALL items and optimistic-log them immediately.
            final parsed = items.map((rawItem) {
              final item = rawItem is Map
                  ? Map<String, dynamic>.from(rawItem)
                  : <String, dynamic>{};
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
                date: DateTime.parse(item['date'] as String),
                description: item['description'] as String?,
                localImagePath: imagePath,
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
            }).toList();

            AppToast.success(
              context,
              _formatAiLoggedToastMessage(parsed),
            );

            unawaited(
              _persistAiTransactions(
                userId: user.uid,
                householdId: householdId,
                isPortfolio: isPortfolio,
                transactions: parsed,
                localImagePath: imagePath,
              ),
            );
          } else {
            AppToast.info(context, context.l10n.noExpenseInformationExtracted);
          }
        } else {
          AppToast.info(context, context.l10n.failedToAnalyzeNoData);
        }
      } else {
        final error = response.data?['error'] ?? context.l10n.failedToAnalyze;
        AppToast.error(context, '${context.l10n.failedToAnalyze}: $error');
      }
    } catch (e) {
      debugPrint('=== ERROR IN ANALYSIS: $e ===');
      if (!mounted) return;

      // Close processing modal
      Navigator.of(context, rootNavigator: true).pop();

      String errorMessage;
      // Check if exception has a 'details' property with an 'error' field
      if (e.runtimeType.toString().contains('Exception') &&
          e.toString().contains('status: 400') &&
          e.toString().contains('details:')) {
        // Parse the error from the exception string representation
        final detailsMatch =
            RegExp(r'details: \{([^}]+)\}').firstMatch(e.toString());
        if (detailsMatch != null) {
          final detailsStr = detailsMatch.group(1) ?? '';
          final errorMatch = RegExp(r'error: ([^,]+)').firstMatch(detailsStr);
          if (errorMatch != null) {
            errorMessage = errorMatch.group(1)?.replaceAll("'", '').trim() ??
                context.l10n.failedToAnalyze;
          } else {
            errorMessage = context.l10n.failedToAnalyze;
          }
        } else {
          errorMessage = context.l10n.failedToAnalyze;
        }
      } else {
        errorMessage = e.toString();
      }

      AppToast.error(context, '${context.l10n.failedToAnalyze}: $errorMessage');
    }
  }

  String? _resolveHouseholdIdForAi() {
    final viewMode = ref.read(viewModeProvider);
    if (viewMode.mode != ViewMode.household) return null;
    final scope = ref.read(householdScopeProvider);
    return scope.selectedHouseholdId;
  }

  Future<void> _persistAiTransactions({
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
        replaceOptimisticTransaction(
          ref: ref,
          optimisticId: optimisticId,
          savedEntry: savedEntry,
          householdId: fromBucket,
        );
        return;
      }

      removeOptimisticTransaction(
        ref: ref,
        optimisticId: optimisticId,
        householdId: fromBucket,
      );
      addOptimisticTransaction(
        ref: ref,
        entry: savedEntry,
        householdId: toBucket,
      );
    }

    String? receiptUrl;
    if (localImagePath != null && localImagePath.isNotEmpty) {
      receiptUrl = await ref
          .read(expenseSaveNotifierProvider.notifier)
          .uploadReceiptImage(File(localImagePath), userId);
    }

    for (final item in transactions) {
      try {
        if (item.transaction.isIncome) {
          final response = await supabase.functions.invoke(
            'save-income',
            body: {
              'userId': userId,
              'amount': item.transaction.amount,
              'category': item.transaction.category,
              'currency': item.transaction.currency,
              'date': item.transaction.date.toIso8601String(),
              'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
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
        final splitType = customSplits?['splitType']?.toString().trim();
        final safeCustomSplits =
            (splitType == null || splitType == 'equal') ? null : customSplits;

        final response = await supabase.functions.invoke(
          'save-expense',
          body: {
            'userId': userId,
            'amount': item.transaction.amount,
            'category': item.transaction.category,
            'currency': item.transaction.currency,
            'date': item.transaction.date.toIso8601String(),
            'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
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
        removeOptimisticTransaction(
          ref: ref,
          optimisticId: item.optimisticId,
          householdId: householdId,
        );
        debugPrint('❌ Failed to persist AI transaction: $error');
        if (mounted) {
          AppToast.error(context, context.l10n.failedToSave(error.toString()));
        }
      }
    }

    if (didPersistAny) {
      await ref.read(expenseSaveNotifierProvider.notifier).invalidateAfterBatch(
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
    final analyticsData = ref.watch(analyticsProvider);
    final filterState = ref.watch(homeFilterProvider);
    final user = ref.watch(authProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final householdScope = ref.watch(householdScopeProvider);
    final portfolioHouseholdIds = householdScope.portfolioHouseholdIds;

    // Global currency remains shared; date ranges move to per-card filters
    final selectedCurrency = filterState.selectedCurrency?.toUpperCase();

    // Base transactions filtered by currency and ACTIVE account selection.
    // Active account is chosen via HomeHeaderSliver:
    // - Personal account: household_id == null
    // - Portfolio account: household_id == selected portfolio household id
    // Household-group mode uses a separate UI path (HouseholdHomeContent).
    final personalExpensesAll = analyticsData.allExpenses.where((e) {
      final hid = e.householdId;
      final activeOk = switch (householdScope.activeAccountType) {
        ActiveAccountType.personal => hid == null || hid.isEmpty,
        ActiveAccountType.portfolio =>
          householdScope.activeAccountHouseholdId != null &&
              hid == householdScope.activeAccountHouseholdId,
        ActiveAccountType.household =>
          householdScope.selectedHouseholdId != null &&
              hid == householdScope.selectedHouseholdId,
      };
      if (!activeOk) return false;

      // Filter by selected currency (if set)
      if (selectedCurrency != null && selectedCurrency.isNotEmpty) {
        final expenseCurrency = (e.currency ?? '').toUpperCase();
        if (expenseCurrency.isNotEmpty && expenseCurrency != selectedCurrency) {
          return false;
        }
      }
      return true;
    }).toList();

    _maybeLogHomeDebugSnapshot(
      analyticsData: analyticsData,
      householdScope: householdScope,
      portfolioHouseholdIds: portfolioHouseholdIds,
      selectedCurrency: selectedCurrency,
      personalExpensesAll: personalExpensesAll,
    );

    // Net cashflow card: its own per-card filter (still uses allExpenses for previous-period math)
    final netFilterState =
        ref.watch(cardDateFilterProvider(HomeCardFilterId.netCashflow));
    final netRange = getDateRangeFromFilter(
      netFilterState.dateRangeFilter,
      netFilterState.customStartDate,
      netFilterState.customEndDate,
    );
    final netFrom = netRange['from']!;
    final netTo = netRange['to']!;

    // Budgets filtered for the net cashflow / spending breakdown cards (by date + currency)
    final netBudgets = analyticsData.allBudgets.where((budget) {
      final d = DateTime(budget.date.year, budget.date.month, budget.date.day);
      final dateOk = !d.isBefore(netFrom) && !d.isAfter(netTo);
      final currencyOk = selectedCurrency == null ||
          (budget.currency?.toUpperCase() == selectedCurrency);
      return dateOk && currencyOk;
    }).toList();

    final isInitialAnalyticsLoading =
        analyticsData.isLoading && !(analyticsData.hasLoadedOnce ?? false);

    final shouldShowFab = _shouldShowFAB(householdScope, householdsAsync);

    if (shouldShowFab && !user.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startFabTourIfNeeded();
      });
    }

    final scrollView = CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        if (householdScope.isHouseholdView) ...[
          const HouseholdHomeContent(),
          const SliverToBoxAdapter(child: EditDashboardButton()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ] else ...[
          // Personal mode - show customizable dashboard
          Consumer(
            builder: (context, ref, _) {
              final repoAsync = ref.watch(dashboardRepositoryFutureProvider);

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
                  final dashboardAsync =
                      ref.watch(personalDashboardProvider(user.uid));

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
                                    child: buildSpendingCard(
                                      context,
                                      colorScheme,
                                      personalExpensesAll,
                                      analyticsData.contact,
                                      config.dateRange,
                                      selectedCurrency:
                                          filterState.selectedCurrency,
                                      customStartDate: config.customStartDate,
                                      customEndDate: config.customEndDate,
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
                                        child: buildNetCashflowCard(
                                          context,
                                          colorScheme,
                                          netBudgets,
                                          personalExpensesAll,
                                          analyticsData.contact,
                                          config.dateRange,
                                          selectedCurrency:
                                              filterState.selectedCurrency,
                                          customStartDate:
                                              config.customStartDate,
                                          customEndDate: config.customEndDate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          DashboardWidgetType.financialCalendar: (context,
                                  config) =>
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    // NOTE: Recurring transactions are loaded by app_initialization_provider
                                    // Just watch the data here - no need to trigger load
                                    final recurringHouseholdId =
                                        householdScope.activeAccountHouseholdId;
                                    final recurringAsync = ref.watch(
                                      recurringTransactionsProvider(
                                        recurringHouseholdId,
                                      ),
                                    );
                                    return FinancialCalendarWidget(
                                      transactions: personalExpensesAll,
                                      recurringTransactions:
                                          recurringAsync.data.valueOrNull ?? [],
                                      currency: selectedCurrency ??
                                          analyticsData
                                              .contact?.preferredCurrency ??
                                          'USD',
                                      isExpanded: config.viewMode ==
                                          DashboardWidgetViewMode.full,
                                    );
                                  },
                                ),
                              ),
                          DashboardWidgetType.recentTransactions:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: buildRecentTransactionsCard(
                                      context,
                                      colorScheme,
                                      personalExpensesAll,
                                      analyticsData.contact,
                                      selectedCurrency:
                                          filterState.selectedCurrency,
                                      onViewAll: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const TransactionsPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          DashboardWidgetType.spendingBreakdownChart:
                              (context, config) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: buildSpendingBreakdownChart(
                                      context,
                                      colorScheme,
                                      personalExpensesAll,
                                      analyticsData.allBudgets,
                                      analyticsData.contact,
                                      config.dateRange,
                                      selectedCurrency:
                                          filterState.selectedCurrency,
                                      customStartDate: config.customStartDate,
                                      customEndDate: config.customEndDate,
                                    ),
                                  ),
                          DashboardWidgetType.whereTheMoneyWent:
                              (context, config) {
                            final range = getDateRangeFromFilter(
                              config.dateRange,
                              config.customStartDate,
                              config.customEndDate,
                            );
                            final from = range['from']!;
                            final to = range['to']!;

                            final dateFilteredExpenses =
                                personalExpensesAll.where((e) {
                              final d = DateTime(
                                  e.date.year, e.date.month, e.date.day);
                              return !d.isBefore(from) && !d.isAfter(to);
                            }).toList();

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: WhereTheMoneyWentWidget(
                                expenses: dateFilteredExpenses,
                                currency: filterState.selectedCurrency,
                                onHelpTap: () =>
                                    showCategoryGuide(context, colorScheme),
                                dateRange: config.dateRange,
                              ),
                            );
                          },
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          // Edit Button
          const SliverToBoxAdapter(child: EditDashboardButton()),
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

    return AdaptiveScaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              final user = ref.read(authProvider);
              if (user.uid.isEmpty) return;

              // Refresh based on current view mode
              if (householdScope.isHouseholdView) {
                // In household mode: invalidate ALL household-related providers
                debugPrint('🔄 Pull-to-refresh: Refreshing household data');
                ref.read(cacheInvalidatorProvider).invalidateAll();
                ref.invalidate(userHouseholdsProvider(user.uid));
                ref.invalidate(householdExpensesProvider);
                ref.invalidate(cachedHouseholdExpensesProvider);
                ref.invalidate(householdSplitsProvider);
                ref.invalidate(cachedHouseholdSplitsProvider);
                ref.invalidate(householdBudgetsProvider);
                ref.invalidate(householdMembersProvider);
                debugPrint(
                    '✅ Invalidated: households, expenses, splits, cached splits/expenses, budgets, members');
              } else {
                // In personal mode: refresh analytics with current date filters
                // TODO: Once global date filter is fully removed, refresh should
                // simply reload all-time analytics without a date window.
                await ref.read(analyticsProvider.notifier).loadData(user.uid);
              }

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
    );
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
