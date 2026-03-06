import 'dart:async';
import 'dart:convert';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/resources/lib/supabase.dart';
import 'package:moneko/core/services/sse_service.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/util/constants.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/households/presentation/pages/create_space_page.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/features/pockets/presentation/widgets/pockets_header_card.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/plain_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

const _kOnboardingCompletedPrefix = 'onboarding_completed:';
const _kNotificationsPromptedPrefix = 'notifications_prompted:';

class OnboardingPostAuthFlowPage extends HookConsumerWidget {
  const OnboardingPostAuthFlowPage({
    super.key,
    this.fromSettings = false,
  });

  final bool fromSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();
    final currentPage = useState(0);
    final colorScheme = Theme.of(context).colorScheme;
    final notificationFlowStarted = useState(false);
    final notificationFlowCompleted = useState(false);
    final selectedImportFormat = useState<String>('csv');
    final groupName = useState<String>('');
    final isPrimaryBusy = useState(false);
    const totalSteps = 5;

    void goToPage(int targetPage) {
      if (!context.mounted) return;
      void go() {
        unawaited(
          pageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
        );
      }

      if (pageController.hasClients) {
        go();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted || !pageController.hasClients) return;
          go();
        });
      }
    }

    Future<void> showFinishPage() async {
      if (!context.mounted) return;
      await _completeOnboarding(context, ref);
    }

    void next() {
      if (!context.mounted) return;
      if (currentPage.value < totalSteps - 1) {
        goToPage(currentPage.value + 1);
      } else {
        unawaited(showFinishPage());
      }
    }

    void skip() => next();

    Future<void> handleNotificationsFlow() async {
      if (!context.mounted) return;
      if (notificationFlowStarted.value || notificationFlowCompleted.value) {
        if (notificationFlowCompleted.value) {
          next();
        }
        return;
      }

      notificationFlowStarted.value = true;
      final uid = ref.read(authProvider).uid;
      final prefs = ref.read(sharedPreferencesProvider);
      final deviceRegistration = ref.read(deviceRegistrationServiceProvider);
      try {
        final promptedKey = '$_kNotificationsPromptedPrefix$uid';
        final prompted = prefs.getBool(promptedKey) ?? false;
        if (!prompted) {
          await prefs.setBool(promptedKey, true);
        }

        if (!context.mounted) return;

        try {
          await deviceRegistration.initialize();
        } catch (_) {}

        if (!context.mounted) return;

        notificationFlowCompleted.value = true;
        next();
      } finally {
        if (context.mounted) {
          notificationFlowStarted.value = false;
        }
      }
    }

    Future<void> primary() async {
      if (isPrimaryBusy.value) return;
      isPrimaryBusy.value = true;
      try {
        if (currentPage.value == 0) {
          final filter = ref.read(homeFilterProvider);
          final selectedCurrency =
              (filter.selectedCurrency ?? 'USD').toUpperCase();

          ref
              .read(homeFilterProvider.notifier)
              .setSelectedCurrency(selectedCurrency);
          ref
              .read(analyticsProvider.notifier)
              .updatePreferredCurrency(selectedCurrency);

          next();

          unawaited(() async {
            try {
              await ref
                  .read(currencyPreferenceServiceProvider)
                  .setSelectedCurrency(selectedCurrency);
            } catch (_) {}

            final userId = supabase.auth.currentSession?.user.id;
            if (userId == null || userId.isEmpty) return;

            try {
              await supabase.functions.invoke(
                'update-preferred-currency',
                body: {
                  'currency': selectedCurrency,
                  'userId': userId,
                },
              );
            } catch (_) {}
          }());
          return;
        }

        if (currentPage.value == 1) {
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final scopeParams = PocketsScopeParams(
            scope: PocketsScopeType.personal,
            periodMonth: monthStart,
          );
          await ref.read(pocketsProvider(scopeParams).notifier).saveChanges();
          next();
          return;
        }

        if (currentPage.value == 2) {
          await handleNotificationsFlow();
          return;
        }

        if (currentPage.value == 3) {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => CreateSpacePage(
                key: UniqueKey(),
                initialName: groupName.value,
                fromOnboarding: true,
              ),
              fullscreenDialog: true,
            ),
          );
          if (result == true) {
            next();
          }
          return;
        }

        if (currentPage.value == 4) {
          final format = selectedImportFormat.value;

          final result = await FilePicker.platform.pickFiles(
            allowMultiple: false,
            type: FileType.custom,
            allowedExtensions: [format],
            withData: true,
          );

          if (result == null || result.files.isEmpty) {
            return;
          }

          final file = result.files.single;
          final bytes = file.bytes;
          if (bytes == null) {
            if (context.mounted) AppToast.error(context, 'Failed to read file');
            return;
          }

          if (bytes.length > 20 * 1024 * 1024) {
            if (context.mounted) AppToast.error(context, 'File is too large (max 20MB).');
            return;
          }

          if (!context.mounted) return;
          final navigator = Navigator.of(context, rootNavigator: true);

          showBlockingProcessingDialog(
            context: context,
            message: 'Extracting transactions using AI',
          );

          try {
            final authUser = ref.read(authProvider);
            final session = supabase.auth.currentSession;
            if (session == null) throw Exception('No auth session');

            final ext = file.extension?.toLowerCase() ?? format;
            String contentType = 'text/csv';
            if (ext == 'pdf') {
              contentType = 'application/pdf';
            } else if (ext == 'xlsx') {
              contentType =
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            }

            final base64Data = base64Encode(bytes);
            final filterState = ref.read(homeFilterProvider);
            final defaultCurrency = filterState.selectedCurrency ?? 'USD';

            final body = {
              'userId': authUser.uid,
              'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
              'typeHint': 'mixed',
              'currency': defaultCurrency.toUpperCase(),
              'attachments': [
                {
                  'filename': file.name,
                  'contentType': contentType,
                  'data': base64Data,
                }
              ]
            };

            Map<String, dynamic>? responseData;
            final supabaseUrl = Constants.supabaseUrl;
            
            final sseUrl = Uri.parse('$supabaseUrl/functions/v1/analyze-expense?stream=true');
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
                final err = (event.data is Map<String, dynamic>)
                    ? (event.data['error']?.toString() ?? 'Failed to analyze file')
                    : event.data.toString();
                throw Exception(err);
              }
            }

            if (responseData == null || responseData['success'] != true) {
              throw Exception(responseData?['error'] ?? 'Failed to analyze file');
            }

            final resultData = responseData['data'];
            final items = resultData is Map ? resultData['items'] : null;
            if (items is! List || items.isEmpty) {
              throw Exception('No transactions found in the file');
            }

            int success = 0;
            
            for (final item in items) {
               if (item is! Map) continue;
               
               final amountRaw = item['amount'];
               final amount = amountRaw is num ? amountRaw.toDouble() : double.tryParse(amountRaw?.toString() ?? '') ?? 0.0;
               if (amount <= 0) continue;

               final type = item['type']?.toString() ?? 'expense';
               final endpoint = type == 'income' ? 'save-income' : 'save-expense';
               
               final dateStr = item['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
               DateTime? parsedDate = DateTime.tryParse(dateStr);
               parsedDate ??= DateTime.now();
               
               final safeTimestamp = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 12);
               
               final saveBody = {
                 'userId': authUser.uid,
                 'amount': amount,
                 'category': item['category']?.toString() ?? 'uncategorized',
                 'currency': item['currency']?.toString() ?? defaultCurrency.toUpperCase(),
                 'date': DateFormat('yyyy-MM-dd').format(parsedDate),
                 'clientCreatedAt': safeTimestamp.toUtc().toIso8601String(),
                 'type': type,
                 if (item['description'] != null) 'description': item['description'].toString(),
               };
               
               try {
                 final response = await supabase.functions.invoke(endpoint, body: saveBody);
                 if (response.data != null && response.data['success'] == true) {
                   success++;
                 }
               } catch (_) {}
            }

            navigator.pop(); // dismiss dialog

            if (success > 0) {
              await ref.read(analyticsProvider.notifier).loadData(authUser.uid);
              next();
            } else {
              if (context.mounted) {
                 AppToast.error(context, 'Failed to import transactions');
              }
            }
          } catch (e) {
            navigator.pop(); // dismiss dialog
            if (context.mounted) {
              AppToast.error(context, e.toString().replaceAll('Exception: ', ''));
            }
          }

          return;
        }

        next();
      } finally {
        if (context.mounted) {
          isPrimaryBusy.value = false;
        }
      }
    }

    useEffect(() {
      if (currentPage.value == 2) {
        unawaited(handleNotificationsFlow());
      }
      return null;
    }, [currentPage.value]);

    return AdaptiveScaffold(
      appBar: null,
      body: SafeArea(
        child: Material(
          color: colorScheme.appBackground,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => currentPage.value = i,
                  children: [
                    currentPage.value == 0
                        ? const _CurrencyStep()
                        : const SizedBox.shrink(),
                    currentPage.value == 1
                        ? const _BudgetStep()
                        : const SizedBox.shrink(),
                    currentPage.value == 2
                        ? const _NotificationsStep()
                        : const SizedBox.shrink(),
                    currentPage.value == 3
                        ? _HouseholdStep(
                            name: groupName.value,
                            onNameChanged: (v) => groupName.value = v,
                          )
                        : const SizedBox.shrink(),
                    currentPage.value == 4
                        ? _DataImportSourceStep(
                            selectedFormat: selectedImportFormat.value,
                            onFormatSelected: (format) {
                              selectedImportFormat.value = format;
                            },
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalSteps, (i) {
                        final active = currentPage.value == i;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: active ? 18 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? colorScheme.primary
                                : colorScheme.mutedForeground
                                    .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: PrimaryAdaptiveButton(
                        onPressed: isPrimaryBusy.value ? null : () => unawaited(primary()),
                        child: isPrimaryBusy.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(currentPage.value == totalSteps - 1
                                ? 'Import Expenses'
                                : context.l10n.continueAction),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlainAdaptiveButton(
                      onPressed: skip,
                      child: Text(
                        currentPage.value == totalSteps - 1
                            ? 'I\'ll do this later'
                            : context.l10n.skipNow,
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markOnboardingCompleted(WidgetRef ref) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final uid = ref.read(authProvider).uid;
    await prefs.setBool('$_kOnboardingCompletedPrefix$uid', true);
  }

  Future<void> _completeOnboarding(BuildContext context, WidgetRef ref) async {
    await _markOnboardingCompleted(ref);
    if (!context.mounted) return;
    if (fromSettings) {
      Navigator.of(context).pop();
    } else {
      const isWeb = kIsWeb;
      final hasSubscription = ref.read(hasActiveSubscriptionProvider);
      final isSubscriptionLoaded = ref.read(isSubscriptionLoadedProvider);
      if (!isWeb && isSubscriptionLoaded && !hasSubscription) {
        context.go('/paywall');
      } else {
        context.go('/dashboard');
      }
    }
  }
}

class _CurrencyStep extends HookConsumerWidget {
  const _CurrencyStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected =
        ref.watch(homeFilterProvider).selectedCurrency?.toUpperCase() ?? 'USD';
    final flagPath = getCurrencyFlagPath(selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.selectCurrencyForDailySpending,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding1.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.currency,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.mutedForeground),
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      await showCurrencySelectorModal(
                        context,
                        ref,
                        showAllByDefault: true,
                      );
                      final user = ref.read(authProvider);
                      if (user.uid.isNotEmpty) {
                        ref.read(analyticsProvider.notifier).refresh(user.uid);

                        final currentView = ref.read(viewModeProvider);
                        final selectedHousehold =
                            ref.read(selectedHouseholdProvider);
                        final householdId =
                            currentView.mode == ViewMode.household
                                ? selectedHousehold.householdId
                                : null;
                        ref
                            .read(recurringTransactionsProvider(householdId)
                                .notifier)
                            .refresh(user.uid);
                        ref.invalidate(pocketsProvider);
                      }
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colorScheme.selectedStateBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colorScheme.controlBorder,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.spotlightShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (flagPath != null) ...[
                            ClipOval(
                              child: Image.asset(
                                flagPath,
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            selected,
                            style: TextStyle(
                              color: colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: colorScheme.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetStep extends HookConsumerWidget {
  const _BudgetStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final scopeParams = PocketsScopeParams(
      scope: PocketsScopeType.personal,
      periodMonth: monthStart,
    );
    final state = ref.watch(pocketsProvider(scopeParams));
    final notifier = ref.read(pocketsProvider(scopeParams).notifier);

    final currency =
        (ref.watch(homeFilterProvider).selectedCurrency ?? 'USD').toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.createSpendingLimitForCategory,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding2.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          PocketsHeaderCard(
            totalBudget: state.totalBudget,
            totalAllocated: state.saved
                .fold<double>(0.0, (s, p) => s + (p.budgetAmountCents / 100.0)),
            totalSpent: state.totalSpent,
            periodMonth: state.periodMonth,
            previousBudget: state.previousBudget,
            onReusePrevious: state.previousBudget > 0
                ? () => notifier.reusePreviousBudget(state.previousBudget)
                : null,
            colorScheme: colorScheme,
            onTotalChanged: notifier.updateTotalBudget,
            onSave: () async => notifier.saveChanges(),
            currency: currency,
            onDateSelected: (_) {},
          ),
        ],
      ),
    );
  }
}

class _NotificationsStep extends StatelessWidget {
  const _NotificationsStep();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.getNotifiedBeforeSpendingLimit,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SvgPicture.asset(
              'lib/assets/images/onboarding/onboarding3.svg',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.border.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.newMessage,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.closeToSpendingLimit,
                        style: TextStyle(color: colorScheme.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdStep extends HookWidget {
  const _HouseholdStep({required this.name, required this.onNameChanged});

  final String name;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = useTextEditingController(text: name);

    useEffect(() {
      void listener() => onNameChanged(controller.text);
      controller.addListener(listener);
      return () => controller.removeListener(listener);
    }, [controller]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.inviteOthersToShareBudget,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SvgPicture.asset(
                'lib/assets/images/onboarding/onboarding4.svg',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: colorScheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.border.withValues(alpha: 0.06),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.createSpace,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.mutedForeground),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      color: colorScheme.foreground,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.householdNameHint,
                      hintStyle: TextStyle(
                        color:
                            colorScheme.mutedForeground.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: colorScheme.cardSurface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: colorScheme.border.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: colorScheme.border.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DataImportSourceStep extends StatelessWidget {
  const _DataImportSourceStep({
    required this.selectedFormat,
    required this.onFormatSelected,
  });

  final String selectedFormat;
  final ValueChanged<String> onFormatSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bring your expenses from\nanother app',
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colorScheme.foreground,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 48),
          SvgPicture.asset(
            'lib/assets/images/onboarding/onboarding5.svg',
            height: 220,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: colorScheme.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'Upload File',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: colorScheme.surface.withValues(alpha: 0.0),
                  child: InkWell(
                    onTap: () {
                      MonekoActionSheet.show<String>(
                        context: context,
                        title: 'Select File Format',
                        actions: [
                          MonekoActionSheetAction(
                            label: 'CSV File',
                            value: 'csv',
                          ),
                          MonekoActionSheetAction(
                            label: 'PDF File',
                            value: 'pdf',
                          ),
                          MonekoActionSheetAction(
                            label: 'Excel File (XLSX)',
                            value: 'xlsx',
                          ),
                        ],
                      ).then((format) {
                        if (format != null) {
                          onFormatSelected(format);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.appBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.insert_drive_file_rounded,
                            size: 18,
                            color: colorScheme.foreground,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedFormat.toUpperCase(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.foreground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: colorScheme.foreground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

