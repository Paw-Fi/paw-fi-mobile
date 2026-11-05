import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/home/presentation/models/parsed_expense.dart';
import 'package:moneko/features/home/presentation/widgets/ai_input_target.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/widgets/home_ai_fab.dart'
    show
        AiLogSuccess,
        handleAiCameraCapture,
        handleAiFreeFormText,
        handleAiDocumentInput;
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/import/domain/import_source_app.dart';

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

final onboardingPostAuthLogExpenseSuccessProvider =
    StateProvider<ValueChanged<OnboardingLoggedExpensePreview>?>((ref) => null);

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
  final deviceRegistration = ref.read(deviceRegistrationServiceProvider);
  final promptedKey = '$_kNotificationsPromptedPrefix$uid';
  final prompted = prefs.getBool(promptedKey) ?? false;
  if (!prompted) {
    await prefs.setBool(promptedKey, true);
  }

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
    final firstItem = value.items.isNotEmpty ? value.items.first : null;
    if (firstItem == null) return;

    ref.read(onboardingPostAuthLogExpenseSuccessProvider)?.call(
          OnboardingLoggedExpensePreview(
            sourceLabel: sourceLabel,
            amount: firstItem.amount,
            currency: firstItem.currency,
            description: firstItem.description?.trim().isNotEmpty == true
                ? firstItem.description!.trim()
                : sourceLabel,
            category: firstItem.category,
            items: value.items,
          ),
        );
  }

  if (sourceLabel == 'Take photo') {
    await handleAiCameraCapture(
      context,
      ref,
      onSuccess: captureSuccess,
      isOnboarding: true,
    );
  } else {
    await handleAiFreeFormText(
      context,
      ref,
      onSuccess: captureSuccess,
      isOnboarding: true,
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
  return handleAiDocumentInput(context, ref,
      bytes: bytes,
      filename: file.name,
      inputTarget: const AiInputTarget(
          accountType: ActiveWalletType.personal,
          householdId: null,
          isPortfolio: false,
          accountId: null,
          accountCurrency: null));
}

List<String> _allowedImportExtensionsForApp(String selectedApp) {
  return supportedImportExtensions;
}
