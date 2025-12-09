import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/state/expense_save_providers.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/widgets.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

/// Shared helpers and widgets for the unified transaction FAB / AI expense capture.

final ImagePicker _imagePicker = ImagePicker();

Future<void> handleAiCameraCapture(BuildContext context, WidgetRef ref) async {
  debugPrint('🎥 Starting camera capture...');

  try {
    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    debugPrint('🎥 Photo captured: ${photo != null}');

    if (photo != null) {
      await _processExpense(context, ref, imagePath: photo.path);
    } else {
      debugPrint('🎥 User cancelled or permission denied');
    }
  } catch (e) {
    AppToast.error(
      context,
      '${context.l10n.failedToCapturePhoto}: ${e.toString()}',
    );
  }
}

Future<void> handleAiFreeFormText(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();

  showTextInputDrawer(
    context,
    controller,
    (text) async {
      await _processExpense(context, ref, text: text);
    },
  );
}

Future<void> handleAiFileUpload(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['csv', 'pdf', 'xlsx', 'xls'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final path = file.path;

    if (path == null) {
      AppToast.error(context, context.l10n.failedToAnalyze);
      return;
    }

    final bytes = await File(path).readAsBytes();
    final base64Data = base64Encode(bytes);

    final extension = path.split('.').last.toLowerCase();
    String contentType = 'application/octet-stream';
    if (extension == 'csv') {
      contentType = 'text/csv';
    } else if (extension == 'pdf') {
      contentType = 'application/pdf';
    } else if (extension == 'xlsx') {
      contentType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    } else if (extension == 'xls') {
      contentType = 'application/vnd.ms-excel';
    }

    final attachments = <Map<String, dynamic>>[
      {
        'filename': file.name,
        'contentType': contentType,
        'data': base64Data,
      },
    ];

    await _processExpense(
      context,
      ref,
      attachments: attachments,
    );
  } catch (e) {
    AppToast.error(
      context,
      '${context.l10n.failedToAnalyze}: ${e.toString()}',
    );
  }
}

Future<void> handleAiFileOrGallery(
  BuildContext context,
  WidgetRef ref,
) async {
  await AdaptiveAlertDialog.show(
    context: context,
    title: context.l10n.appTitle,
    message: 'Choose source for analysis',
    actions: [
      AlertAction(
        title: 'Files',
        style: AlertActionStyle.primary,
        onPressed: () async {
          await handleAiFileUpload(context, ref);
        },
      ),
      AlertAction(
        title: 'Gallery',
        style: AlertActionStyle.primary,
        onPressed: () async {
          try {
            final XFile? image = await _imagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );

            if (image != null) {
              await _processExpense(context, ref, imagePath: image.path);
            }
          } catch (e) {
            AppToast.error(
              context,
              '${context.l10n.failedToCapturePhoto}: ${e.toString()}',
            );
          }
        },
      ),
      AlertAction(
        title: context.l10n.cancel,
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
    ],
  );
}

Future<void> _processExpense(
  BuildContext context,
  WidgetRef ref, {
  String? text,
  String? imagePath,
  List<Map<String, dynamic>>? attachments,
}) async {
  final user = ref.read(authProvider);
  final contact = ref.read(analyticsProvider).contact;

  // Show processing modal
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

    final Map<String, dynamic> body = {
      'userId': user.uid,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'language': languageTag,
    };

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

    // Add either text, image, or file attachments to the request
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

    if (attachments != null && attachments.isNotEmpty) {
      body['attachments'] = attachments;
    }

    // Call analyze-expense endpoint (NEW: doesn't save yet). Backend now classifies income vs expense.
    final response = await supabase.functions.invoke(
      'analyze-expense',
      body: body,
    );

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
          // Parse ALL items from the response
          final parsed = items.map((item) {
            final isIncome =
                (item['type']?.toString().toLowerCase() == 'income');
            return ParsedExpense(
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
          }).toList();

          // Partition by type to handle mixed cases robustly
          final incomes = parsed.where((p) => p.isIncome).toList();
          final expenses = parsed.where((p) => !p.isIncome).toList();

          if (parsed.length == 1) {
            ref.read(pendingExpenseProvider.notifier).state = parsed.first;
            showUnifiedTransactionSheet(
              context,
              newExpense: parsed.first,
              localImagePath: imagePath,
            );
          } else if (incomes.isNotEmpty && expenses.isNotEmpty) {
            // We don't auto-merge mixed types. Ask user to submit separately.
            AppToast.info(context,
                '${context.l10n.failedToAnalyzeNoData} (mixed income and expense detected; please submit separately)');
          } else if (incomes.isNotEmpty) {
            // Multiple income items - combine into a single summarized income
            _showMultiIncomeConfirmation(context, ref, incomes, imagePath);
          } else {
            // Multiple expenses - combine existing behavior
            _showMultiExpenseConfirmation(context, ref, expenses, imagePath);
          }
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

void _showMultiExpenseConfirmation(
  BuildContext context,
  WidgetRef ref,
  List<ParsedExpense> expenses,
  String? imagePath,
) {
  // Calculate total amount
  final totalAmount =
      expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

  // Get most common category or use 'other'
  final categoryCount = <String, int>{};
  for (final expense in expenses) {
    categoryCount[expense.category] =
        (categoryCount[expense.category] ?? 0) + 1;
  }
  final mostCommonCategory =
      categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

  // Use AI-generated descriptions as-is - DO NOT append amounts (AI already includes them)
  final itemDescriptions = expenses
      .map((e) => e.description ?? e.category)
      .where((s) => s.trim().isNotEmpty)
      .join(', ');

  // Create single combined expense
  final combinedExpense = ParsedExpense(
    amount: totalAmount,
    category: mostCommonCategory,
    currency: expenses.first.currency,
    currencySymbol: expenses.first.currencySymbol,
    date: expenses.first.date,
    description: itemDescriptions,
    localImagePath: imagePath,
  );

  // Store in provider and show unified sheet
  ref.read(pendingExpenseProvider.notifier).state = combinedExpense;
  showUnifiedTransactionSheet(
    context,
    newExpense: combinedExpense,
    localImagePath: imagePath,
  );
}

void _showMultiIncomeConfirmation(
  BuildContext context,
  WidgetRef ref,
  List<ParsedExpense> incomes,
  String? imagePath,
) {
  // Sum all income amounts and use AI-generated descriptions as-is
  final totalAmount = incomes.fold<double>(0, (sum, inc) => sum + inc.amount);

  // Use AI-generated descriptions directly - DO NOT add prefixes or modify
  final combinedDescription = incomes
      .map((e) => e.description ?? e.category)
      .where((s) => s.trim().isNotEmpty)
      .join(', ');

  final combined = ParsedExpense(
    isIncome: true,
    amount: totalAmount,
    category: 'income',
    currency: incomes.first.currency,
    currencySymbol: incomes.first.currencySymbol,
    date: incomes.first.date,
    description:
        combinedDescription.isNotEmpty ? combinedDescription : context.l10n.income,
    localImagePath: imagePath,
  );

  ref.read(pendingExpenseProvider.notifier).state = combined;
  showUnifiedTransactionSheet(
    context,
    newExpense: combined,
    localImagePath: imagePath,
  );
}

/// Determines if the unified transaction FAB should be visible for a given
/// view mode and household loading state.
bool shouldShowHomeFab(
  ViewModeState viewMode,
  AsyncValue<List<Household>> householdsAsync,
) {
  // Always show FAB in personal mode
  if (viewMode.mode == ViewMode.personal) {
    return true;
  }

  // In household mode, hide FAB if households are empty (showing onboarding)
  return householdsAsync.maybeWhen(
    data: (households) => households.isNotEmpty,
    orElse: () => true, // Show FAB during loading or error states
  );
}

class HomeAiExpandableFab extends ConsumerWidget {
  const HomeAiExpandableFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fabKey = GlobalKey<ExpandableFabState>();

    return ExpandableFab(
      key: fabKey,
      distance: 120,
      children: [
        ActionButton(
          onPressed: () async {
            fabKey.currentState?.close();
            await handleAiFreeFormText(context, ref);
          },
          icon: const Icon(Icons.text_fields),
          label: context.l10n.freeFormText,
        ),
        ActionButton(
          onPressed: () async {
            fabKey.currentState?.close();
            await handleAiCameraCapture(context, ref);
          },
          icon: const Icon(Icons.camera_alt),
          label: context.l10n.takePhoto,
        ),
        ActionButton(
          onPressed: () async {
            fabKey.currentState?.close();
            await handleAiFileOrGallery(context, ref);
          },
          icon: const Icon(Icons.attach_file),
          label: 'Files',
        ),
      ],
    );
  }
}
