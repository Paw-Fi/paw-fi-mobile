import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart'
    show AiLogSuccess, handleAiCameraCapture, handleAiFreeFormText;
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/services/sse_service.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';

const _kNotificationsPromptedPrefix = 'notifications_prompted:';

class OnboardingLoggedExpensePreview {
  const OnboardingLoggedExpensePreview({
    required this.sourceLabel,
    required this.amount,
    required this.currency,
    required this.description,
    required this.category,
    required this.items,
  });

  final String sourceLabel;
  final double amount;
  final String currency;
  final String description;
  final String category;
  final List<ParsedExpense> items; // Keep track of all items logged
}

typedef OnboardingPostAuthLogExpenseAction
    = Future<OnboardingLoggedExpensePreview?> Function(
        BuildContext context, WidgetRef ref, String sourceLabel);
typedef OnboardingPostAuthImportExpensesAction = Future<int?> Function(
  BuildContext context,
  WidgetRef ref,
  String selectedApp,
);
typedef OnboardingPostAuthNotificationsAction = Future<void> Function(
  WidgetRef ref,
  String uid,
);

final onboardingPostAuthLogExpenseActionProvider =
    Provider<OnboardingPostAuthLogExpenseAction>(
  (ref) => _defaultLogExpenseAction,
);

final onboardingPostAuthImportExpensesActionProvider =
    Provider<OnboardingPostAuthImportExpensesAction>(
  (ref) => _defaultImportExpensesAction,
);

final onboardingPostAuthNotificationsActionProvider =
    Provider<OnboardingPostAuthNotificationsAction>(
  (ref) => _defaultNotificationsAction,
);

Future<void> _defaultNotificationsAction(WidgetRef ref, String uid) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final promptedKey = '$_kNotificationsPromptedPrefix$uid';
  final prompted = prefs.getBool(promptedKey) ?? false;
  if (!prompted) {
    await prefs.setBool(promptedKey, true);
  }

  final deviceRegistration = ref.read(deviceRegistrationServiceProvider);
  try {
    await deviceRegistration.initialize();
  } catch (_) {}
}

Future<OnboardingLoggedExpensePreview?> _defaultLogExpenseAction(
  BuildContext context,
  WidgetRef ref,
  String sourceLabel,
) async {
  AiLogSuccess? success;

  void captureSuccess(AiLogSuccess value) {
    success = value;
  }

  if (sourceLabel == 'Take photo') {
    await handleAiCameraCapture(
      context,
      ref,
      onSuccess: captureSuccess,
    );
  } else {
    await handleAiFreeFormText(
      context,
      ref,
      onSuccess: captureSuccess,
    );
  }

  final firstItem =
      success?.items.isNotEmpty == true ? success!.items.first : null;
  if (firstItem == null) {
    return null;
  }

  return OnboardingLoggedExpensePreview(
    sourceLabel: sourceLabel,
    amount: firstItem.amount,
    currency: firstItem.currency,
    description: firstItem.description?.trim().isNotEmpty == true
        ? firstItem.description!.trim()
        : sourceLabel,
    category: firstItem.category,
    items: success?.items ?? [],
  );
}

Future<int?> _defaultImportExpensesAction(
  BuildContext context,
  WidgetRef ref,
  String selectedApp,
) async {
  if (selectedApp == 'Not using an app') {
    return 1;
  }

  final allowedExtensions = _allowedImportExtensionsForApp(selectedApp);
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    withData: true,
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }

  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) {
    if (context.mounted) AppToast.error(context, context.l10n.failedToReadFile);
    return null;
  }

  if (bytes.length > 15 * 1024 * 1024) {
    if (context.mounted) {
      AppToast.error(context, context.l10n.fileTooLarge);
    }
    return null;
  }

  if (!context.mounted) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  var dialogDismissed = false;

  showBlockingProcessingDialog(
    context: context,
    message: context.l10n.onboardingPostAuthImportingFrom(selectedApp),
  );

  try {
    final authUser = ref.read(authProvider);
    final session = supabase.auth.currentSession;
    if (session == null) throw Exception('No auth session');

    final ext = file.extension?.toLowerCase() ?? 'csv';
    String contentType = 'text/csv';
    if (ext == 'pdf') {
      contentType = 'application/pdf';
    } else if (ext == 'xls') {
      contentType = 'application/vnd.ms-excel';
    } else if (ext == 'xlsx') {
      contentType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    final base64Data = base64Encode(bytes);
    final defaultCurrency =
        (ref.read(homeFilterProvider).selectedCurrency ?? 'USD').toUpperCase();

    final body = {
      'userId': authUser.uid,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'typeHint': 'mixed',
      'currency': defaultCurrency,
      'attachments': [
        {
          'filename': file.name,
          'contentType': contentType,
          'data': base64Data,
        }
      ]
    };

    Map<String, dynamic>? responseData;
    final sseUrl = Uri.parse(
        '${Constants.supabaseUrl}/functions/v1/analyze-expense?stream=true');
    await for (final event in SSEService.streamRequest(
      url: sseUrl,
      body: body,
      headers: <String, String>{
        'Authorization': 'Bearer ${session.accessToken}',
      },
      timeout: const Duration(minutes: 4),
    )) {
      if (event.event == 'complete' && event.data is Map<String, dynamic>) {
        responseData = event.data as Map<String, dynamic>;
      } else if (event.event == 'error') {
        final error = event.data is Map<String, dynamic>
            ? (event.data['error']?.toString() ?? context.l10n.invalidResponse)
            : event.data.toString();
        throw Exception(error);
      }
    }

    if (responseData == null || responseData['success'] != true) {
      throw Exception(responseData?['error'] ?? context.l10n.invalidResponse);
    }

    final resultData = responseData['data'];
    final items = resultData is Map ? resultData['items'] : null;
    if (items is! List || items.isEmpty) {
      throw Exception(context.l10n.noTransactionsFound);
    }

    var success = 0;
    for (final item in items) {
      if (item is! Map) continue;

      final amountRaw = item['amount'];
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
      if (amount <= 0) continue;

      final type = item['type']?.toString() ?? 'expense';
      final endpoint = type == 'income' ? 'save-income' : 'save-expense';
      final dateStr = item['date']?.toString() ??
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      final safeTimestamp =
          DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 12);

      final saveBody = {
        'userId': authUser.uid,
        'amount': amount,
        'category': item['category']?.toString() ?? 'uncategorized',
        'currency': (item['currency']?.toString() ?? defaultCurrency)
            .trim()
            .toUpperCase(),
        'date': DateFormat('yyyy-MM-dd').format(parsedDate),
        'clientCreatedAt': safeTimestamp.toUtc().toIso8601String(),
        'type': type,
        if (item['description'] != null)
          'description': item['description'].toString().trim(),
      };

      try {
        final response =
            await supabase.functions.invoke(endpoint, body: saveBody);
        if (response.data != null && response.data['success'] == true) {
          success += 1;
        }
      } catch (_) {}
    }

    await ref.read(analyticsProvider.notifier).loadData(authUser.uid);
    if (context.mounted) {
      AppToast.success(
        context,
        context.l10n.onboardingPostAuthImportSuccess(success, selectedApp),
      );
    }
    return success > 0 ? success : null;
  } catch (error) {
    if (context.mounted) {
      AppToast.error(
        context,
        error.toString().replaceAll('Exception: ', ''),
      );
    }
    return null;
  } finally {
    if (!dialogDismissed && navigator.canPop()) {
      dialogDismissed = true;
      navigator.pop();
    }
  }
}

List<String> _allowedImportExtensionsForApp(String selectedApp) {
  return supportedImportExtensions;
}
