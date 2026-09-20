import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/core/constants/links.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/ai_hold_quick_action_preference.dart';
import 'package:moneko/features/insights/presentation/widgets/tabs/scenario_planning_tab.dart';
import 'package:moneko/features/profile/presentation/pages/android_notification_capture_page.dart';
import 'package:moneko/features/wallets/presentation/pages/bank_connections_page.dart';
import 'package:moneko/features/profile/presentation/pages/email_import_settings_page.dart';
import 'package:moneko/features/profile/presentation/pages/ios_wallet_capture_page.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';
import 'package:moneko/features/home/presentation/pages/overview_dashboard_page.dart';
import 'package:moneko/features/profile/presentation/widgets/category_customization_sheet.dart';
import 'package:moneko/features/profile/data/providers/telegram_binding_provider.dart';
import 'package:moneko/features/profile/data/providers/whatsapp_binding_provider.dart';
import 'package:moneko/features/profile/presentation/widgets/telegram_tutorial_modal.dart';
import 'package:moneko/features/profile/presentation/widgets/whatsapp_tutorial_modal.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/subscription/presentation/pages/plan_selection_page.dart';
import 'package:moneko/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:moneko/features/subscription/presentation/widgets/plus_locked_sheet.dart';
import 'package:moneko/core/subscription/plan_access.dart';
import 'package:moneko/shared/widgets/moneko_action_sheet.dart';
import 'package:moneko/shared/widgets/moneko_bottom_sheet.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/messaging_app_logo.dart';
import 'monthly_report_page.dart';

class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openTool(_BrowseTool tool) async {
    final subscriptionAsync = ref.read(subscriptionNotifierProvider);
    final canUsePlusFeatures = !subscriptionAsync.hasValue ||
        hasPremiumFeatureAccess(subscriptionAsync.valueOrNull);

    if (tool.plusFeature != null && !canUsePlusFeatures) {
      await PlusLockedSheet.show(
        context,
        highlightedFeature: tool.plusFeature!,
      );
      return;
    }

    switch (tool.destination) {
      case _BrowseDestination.report:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const MonthlyReportPage(),
          ),
        );
      case _BrowseDestination.scenario:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const _ScenarioToolPage(),
          ),
        );
      case _BrowseDestination.membership:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PlanSelectionPage(),
          ),
        );
      case _BrowseDestination.accountOverview:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const OverviewDashboardPage(),
          ),
        );
      case _BrowseDestination.bankConnections:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BankConnectionsPage(),
          ),
        );
      case _BrowseDestination.categories:
        await MonekoBottomSheet.show<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).colorScheme.sheetBackground,
          builder: (_) => const CategoryCustomizationSheet(),
        );
      case _BrowseDestination.homeScreenWidgets:
        await _launchUrl(
          Uri.parse('https://moneko.io/help/ios-home-screen-widgets'),
          errorMessage: context.l10n.couldNotOpenWidgetsHelp,
        );
      case _BrowseDestination.siri:
        await showSiriExpenseTutorialSheet(context);
      case _BrowseDestination.importData:
        if (context.mounted) context.push('/import');
      case _BrowseDestination.currencyConverter:
        if (context.mounted) context.push('/currency-rates');
      case _BrowseDestination.emailReceipt:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const EmailImportSettingsPage(),
          ),
        );
      case _BrowseDestination.telegram:
        await _openTelegram();
      case _BrowseDestination.whatsapp:
        await _openWhatsApp();
      case _BrowseDestination.applePay:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const IosWalletCapturePage(),
          ),
        );
      case _BrowseDestination.androidNotifications:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AndroidNotificationCapturePage(),
          ),
        );
      case _BrowseDestination.quickAction:
        await _changeHoldQuickAction();
      case _BrowseDestination.pushNotifications:
        await _handleNotificationToggle();
      case _BrowseDestination.rateApp:
        try {
          final review = InAppReview.instance;
          if (await review.isAvailable()) await review.requestReview();
        } catch (_) {}
      case _BrowseDestination.changelog:
        await _launchUrl(
          Uri.parse(Links.changelog),
          errorMessage: context.l10n.couldNotOpenLink,
        );
      case _BrowseDestination.reportBug:
        await showReportBugFlow(context);
      case _BrowseDestination.featureRequest:
        await showFeatureRequestFlow(context);
    }
  }

  Future<void> _launchUrl(
    Uri url, {
    required String errorMessage,
  }) async {
    try {
      var launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      }
      if (!launched && mounted) AppToast.error(context, errorMessage);
    } catch (_) {
      if (mounted) AppToast.error(context, errorMessage);
    }
  }

  Future<void> _openTelegram() async {
    final isBound = ref.read(telegramBindingProvider).valueOrNull ?? false;
    if (isBound) {
      await _launchUrl(
        Uri.parse('https://t.me/moneko_ai_bot'),
        errorMessage: context.l10n.couldNotLaunchTelegram,
      );
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const TelegramTutorialModal(),
    );
    if (result == true) ref.invalidate(telegramBindingProvider);
  }

  Future<void> _openWhatsApp() async {
    final isBound = ref.read(whatsAppBindingProvider).valueOrNull ?? false;
    if (isBound) {
      await _launchUrl(
        Uri.parse('https://wa.link/zxwtld'),
        errorMessage: context.l10n.couldNotLaunchWhatsApp,
      );
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const WhatsAppTutorialModal(),
    );
    if (result == true) ref.invalidate(whatsAppBindingProvider);
  }

  Future<void> _changeHoldQuickAction() async {
    final cancelLabel = context.l10n.cancel;
    final result = await MonekoActionSheet.show<String>(
      context: context,
      title: context.l10n.pressAndHoldQuickAction,
      actions: [
        MonekoActionSheetAction<String>(
          label: context.l10n.takePhotoWithCamera,
          value: 'camera',
        ),
        MonekoActionSheetAction<String>(
          label: context.l10n.choosePhotoFromLibrary,
          value: 'photoLibrary',
        ),
        MonekoActionSheetAction<String>(
          label: context.l10n.recordWithAudio,
          value: 'recordAudio',
        ),
        MonekoActionSheetAction<String>(
          label: context.l10n.showTextInputDrawer,
          value: 'textInputDrawer',
        ),
        MonekoActionSheetAction<String>(
          label: context.l10n.manualInputQuickActionLabel,
          value: 'manualEntry',
        ),
      ],
      cancelAction: MonekoActionSheetAction<String>(
        label: cancelLabel,
        value: cancelLabel,
      ),
    );
    if (result == null || result == cancelLabel) return;

    final nextAction = switch (result) {
      'camera' => AiHoldQuickAction.camera,
      'photoLibrary' => AiHoldQuickAction.photoLibrary,
      'recordAudio' => AiHoldQuickAction.recordAudio,
      'textInputDrawer' => AiHoldQuickAction.textInputDrawer,
      'manualEntry' => AiHoldQuickAction.manualEntry,
      _ => null,
    };
    await writeAiHoldQuickActionPreference(
      ref.read(sharedPreferencesProvider),
      nextAction,
    );
    if (mounted) {
      AppToast.success(context, context.l10n.quickActionUpdated(result));
    }
  }

  Future<void> _handleNotificationToggle() async {
    try {
      final status = await Permission.notification.status;

      if (status.isDenied || status.isPermanentlyDenied) {
        await AppSettings.openAppSettings(
          type: AppSettingsType.notification,
          asAnotherTask: true,
        );

        if (mounted) {
          AppToast.info(context, context.l10n.enableNotificationsInSettings);
        }
      } else if (status.isGranted) {
        try {
          await ref.read(deviceRegistrationServiceProvider).initialize();
        } catch (error) {
          debugPrint('Error initializing notifications: $error');
        }
      } else {
        final newStatus = await Permission.notification.request();
        if (newStatus.isGranted) {
          try {
            await ref.read(deviceRegistrationServiceProvider).initialize();
          } catch (error) {
            debugPrint('Error initializing notifications: $error');
          }
        }
      }
    } catch (error) {
      debugPrint('Error handling notification toggle: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final subscriptionAsync = ref.watch(subscriptionNotifierProvider);
    final canUsePlusFeatures = !subscriptionAsync.hasValue ||
        hasPremiumFeatureAccess(subscriptionAsync.valueOrNull);

    final tools = _browseTools(
      context,
      canUsePlusFeatures: canUsePlusFeatures,
    )
        .where(
          (tool) => query.isEmpty || tool.title.toLowerCase().contains(query),
        )
        .toList(growable: false);

    final groupedTools = <String, List<_BrowseTool>>{};
    for (final tool in tools) {
      groupedTools.putIfAbsent(tool.category, () => <_BrowseTool>[]).add(tool);
    }
    for (final group in groupedTools.values) {
      group.sort(
        (left, right) => _browseToolOrder(left).compareTo(
          _browseToolOrder(right),
        ),
      );
    }
    final orderedGroups = groupedTools.entries.toList()
      ..sort(
        (left, right) => _browseCategoryOrder(left.key).compareTo(
          _browseCategoryOrder(right.key),
        ),
      );

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // Search Field
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.search,
                  hintStyle: TextStyle(
                    color: colorScheme.mutedForeground,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.mutedForeground,
                    size: 22,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: colorScheme.mutedForeground,
                            size: 20,
                          ),
                        ),
                  filled: true,
                  fillColor: colorScheme.inputBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorScheme.controlBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorScheme.controlBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (tools.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No tools match your search.',
                    style: TextStyle(
                      color: colorScheme.mutedForeground,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else ...[
            ...orderedGroups.expand(
              (entry) => <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                    child: Text(
                      _browseCategoryTitle(context, entry.key),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.foreground,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, rowIndex) {
                        final leftIndex = rowIndex * 2;
                        final leftTool = entry.value[leftIndex];
                        final rightTool = leftIndex + 1 < entry.value.length
                            ? entry.value[leftIndex + 1]
                            : null;
                        final rowCount = (entry.value.length + 1) ~/ 2;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: rowIndex == rowCount - 1 ? 0 : 12,
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _BrowseToolCard(
                                    tool: leftTool,
                                    onTap: () => _openTool(leftTool),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: rightTool == null
                                      ? const SizedBox.shrink()
                                      : _BrowseToolCard(
                                          tool: rightTool,
                                          onTap: () => _openTool(rightTool),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: (entry.value.length + 1) ~/ 2,
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: PlatformInfo.isIOS26OrHigher() ? 120 : 40,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int _browseToolOrder(_BrowseTool tool) {
  return switch (tool.destination) {
    _BrowseDestination.report => 0,
    _BrowseDestination.scenario => 1,
    _BrowseDestination.accountOverview => 0,
    _BrowseDestination.membership => 1,
    _BrowseDestination.bankConnections => 2,
    _BrowseDestination.categories => 3,
    _BrowseDestination.importData => 0,
    _BrowseDestination.telegram => 1,
    _BrowseDestination.whatsapp => 2,
    _BrowseDestination.homeScreenWidgets => 3,
    _BrowseDestination.siri => 4,
    _BrowseDestination.currencyConverter => 5,
    _BrowseDestination.emailReceipt => 6,
    _BrowseDestination.applePay => 7,
    _BrowseDestination.androidNotifications => 8,
    _BrowseDestination.quickAction => 0,
    _BrowseDestination.pushNotifications => 1,
    _BrowseDestination.rateApp => 0,
    _BrowseDestination.changelog => 1,
    _BrowseDestination.reportBug => 2,
    _BrowseDestination.featureRequest => 3,
  };
}

String _browseCategoryTitle(BuildContext context, String category) {
  return switch (category) {
    'Account' => context.l10n.account,
    'Financial health' => context.l10n.financialHealth,
    'Capture & integrations' => context.l10n.captureAndIntegrations,
    'App experience' => context.l10n.appExperience,
    'Support' => context.l10n.support,
    _ => category,
  };
}

int _browseCategoryOrder(String category) {
  return switch (category) {
    'Account' => 0,
    'Financial health' => 1,
    'Capture & integrations' => 2,
    'App experience' => 3,
    'Support' => 4,
    _ => 5,
  };
}

Color _browseCategoryAccent(ColorScheme colorScheme, String category) {
  return switch (category) {
    'Financial health' => colorScheme.browseIconBackground(colorScheme.success),
    'Account' => colorScheme.browseIconBackground(colorScheme.info),
    'Capture & integrations' =>
      colorScheme.browseIconBackground(colorScheme.warning),
    'App experience' =>
      colorScheme.browseIconBackground(colorScheme.progressOrange),
    'Support' => colorScheme.browseIconBackground(colorScheme.errorAccent),
    _ => colorScheme.browseIconBackground(colorScheme.primary),
  };
}

enum _BrowseDestination {
  report,
  scenario,
  membership,
  accountOverview,
  bankConnections,
  categories,
  homeScreenWidgets,
  siri,
  importData,
  currencyConverter,
  emailReceipt,
  telegram,
  whatsapp,
  applePay,
  androidNotifications,
  quickAction,
  pushNotifications,
  rateApp,
  changelog,
  reportBug,
  featureRequest,
}

class _BrowseTool {
  const _BrowseTool({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.destination,
    this.plusFeature,
    this.customIcon,
    this.isLocked = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color Function(ColorScheme) accent;
  final _BrowseDestination destination;
  final PlusFeature? plusFeature;
  final MessagingAppLogoType? customIcon;
  final bool isLocked;

  String get category => switch (destination) {
        _BrowseDestination.report ||
        _BrowseDestination.scenario =>
          'Financial health',
        _BrowseDestination.membership ||
        _BrowseDestination.accountOverview ||
        _BrowseDestination.bankConnections ||
        _BrowseDestination.categories =>
          'Account',
        _BrowseDestination.homeScreenWidgets ||
        _BrowseDestination.siri ||
        _BrowseDestination.importData ||
        _BrowseDestination.currencyConverter ||
        _BrowseDestination.emailReceipt ||
        _BrowseDestination.telegram ||
        _BrowseDestination.whatsapp ||
        _BrowseDestination.applePay ||
        _BrowseDestination.androidNotifications =>
          'Capture & integrations',
        _BrowseDestination.quickAction ||
        _BrowseDestination.pushNotifications =>
          'App experience',
        _BrowseDestination.rateApp ||
        _BrowseDestination.changelog ||
        _BrowseDestination.reportBug ||
        _BrowseDestination.featureRequest =>
          'Support',
      };
}

List<_BrowseTool> _browseTools(
  BuildContext context, {
  required bool canUsePlusFeatures,
}) =>
    [
      _BrowseTool(
        title: context.l10n.healthReport,
        description: 'See your financial health at a glance.',
        icon: Icons.health_and_safety_rounded,
        accent: (scheme) => scheme.successSurface,
        destination: _BrowseDestination.report,
      ),
      _BrowseTool(
        title: context.l10n.scenarioTab,
        description: 'Ask what-if questions before you spend.',
        icon: Icons.auto_awesome_rounded,
        accent: (scheme) => scheme.secondaryContainer,
        destination: _BrowseDestination.scenario,
      ),
      _BrowseTool(
        title: context.l10n.membership,
        description: 'Manage your Moneko plan and access.',
        icon: Icons.star_outline_rounded,
        accent: (scheme) => scheme.tertiaryContainer,
        destination: _BrowseDestination.membership,
      ),
      _BrowseTool(
        title: context.l10n.accountOverview,
        description: 'Review your financial dashboard.',
        icon: Icons.pie_chart,
        accent: (scheme) => scheme.primaryContainer,
        destination: _BrowseDestination.accountOverview,
      ),
      _BrowseTool(
        title: context.l10n.bankConnections,
        description: 'Connect and manage linked bank accounts.',
        icon: Icons.account_balance_outlined,
        accent: (scheme) => scheme.secondaryContainer,
        destination: _BrowseDestination.bankConnections,
      ),
      _BrowseTool(
        title: context.l10n.categories,
        description: 'Customize categories for your transactions.',
        icon: Icons.category_rounded,
        accent: (scheme) => scheme.tertiaryContainer,
        destination: _BrowseDestination.categories,
      ),
      if (Platform.isIOS)
        _BrowseTool(
          title: context.l10n.homeScreenWidgets,
          description: 'Add Moneko widgets to your Home Screen.',
          icon: Icons.widgets_rounded,
          accent: (scheme) => scheme.primaryContainer,
          destination: _BrowseDestination.homeScreenWidgets,
        ),
      if (Platform.isIOS)
        _BrowseTool(
          title: context.l10n.logExpenseWithSiri,
          description: 'Learn how to log an expense with Siri.',
          icon: Icons.mic_rounded,
          accent: (scheme) => scheme.secondaryContainer,
          destination: _BrowseDestination.siri,
        ),
      _BrowseTool(
        title: context.l10n.importData,
        description: 'Bring your existing financial history into Moneko.',
        icon: Icons.upload_file_rounded,
        accent: (scheme) => scheme.primaryContainer,
        destination: _BrowseDestination.importData,
      ),
      _BrowseTool(
        title: context.l10n.currencyConverter,
        description: 'Explore exchange rates across currencies.',
        icon: Icons.currency_exchange_rounded,
        accent: (scheme) => scheme.secondaryContainer,
        destination: _BrowseDestination.currencyConverter,
        plusFeature: PlusFeature.currencyConverter,
        isLocked: !canUsePlusFeatures,
      ),
      _BrowseTool(
        title: context.l10n.emailFileImportEnableSwitchTitle,
        description: 'Capture receipts sent to your Moneko email.',
        icon: Icons.forward_to_inbox_rounded,
        accent: (scheme) => scheme.tertiaryContainer,
        destination: _BrowseDestination.emailReceipt,
        plusFeature: PlusFeature.emailReceiptImport,
        isLocked: !canUsePlusFeatures,
      ),
      _BrowseTool(
        title: context.l10n.connectTelegram,
        description: 'Capture expenses through Telegram.',
        icon: Icons.send_rounded,
        customIcon: MessagingAppLogoType.telegram,
        accent: (scheme) => scheme.primaryContainer,
        destination: _BrowseDestination.telegram,
        plusFeature: PlusFeature.messagingAppCapture,
        isLocked: !canUsePlusFeatures,
      ),
      _BrowseTool(
        title: context.l10n.whatsAppConnected,
        description: 'Capture expenses through WhatsApp.',
        icon: Icons.chat_rounded,
        customIcon: MessagingAppLogoType.whatsapp,
        accent: (scheme) => scheme.successSurface,
        destination: _BrowseDestination.whatsapp,
        plusFeature: PlusFeature.messagingAppCapture,
        isLocked: !canUsePlusFeatures,
      ),
      if (Platform.isIOS)
        _BrowseTool(
          title: context.l10n.applePayIntegration,
          description: 'Automatically capture Apple Pay transactions.',
          icon: Icons.account_balance_wallet_rounded,
          accent: (scheme) => scheme.primaryContainer,
          destination: _BrowseDestination.applePay,
          plusFeature: PlusFeature.messagingAppCapture,
          isLocked: !canUsePlusFeatures,
        ),
      if (Platform.isAndroid)
        _BrowseTool(
          title: context.l10n.autoTransactionCapture,
          description: 'Capture transactions from Android notifications.',
          icon: Icons.notifications_active_rounded,
          accent: (scheme) => scheme.secondaryContainer,
          destination: _BrowseDestination.androidNotifications,
          plusFeature: PlusFeature.messagingAppCapture,
          isLocked: !canUsePlusFeatures,
        ),
      _BrowseTool(
        title: context.l10n.pressAndHoldQuickAction,
        description: 'Choose what the home action responds to.',
        icon: Icons.touch_app_rounded,
        accent: (scheme) => scheme.tertiaryContainer,
        destination: _BrowseDestination.quickAction,
      ),
      _BrowseTool(
        title: context.l10n.pushNotifications,
        description: 'Manage notifications from Moneko.',
        icon: Icons.notifications_active_rounded,
        accent: (scheme) => scheme.primaryContainer,
        destination: _BrowseDestination.pushNotifications,
      ),
      _BrowseTool(
        title: context.l10n.rateUs,
        description: 'Tell us how Moneko is working for you.',
        icon: Icons.star_rounded,
        accent: (scheme) => scheme.primaryContainer,
        destination: _BrowseDestination.rateApp,
      ),
      _BrowseTool(
        title: context.l10n.changelog,
        description: 'See what is new in Moneko.',
        icon: Icons.new_releases_rounded,
        accent: (scheme) => scheme.secondaryContainer,
        destination: _BrowseDestination.changelog,
      ),
      _BrowseTool(
        title: context.l10n.reportABug,
        description: 'Send the team a report about a problem.',
        icon: Icons.bug_report_rounded,
        accent: (scheme) => scheme.errorSurface,
        destination: _BrowseDestination.reportBug,
      ),
      _BrowseTool(
        title: context.l10n.submitNewFeatureRequest,
        description: 'Share an idea for a future improvement.',
        icon: Icons.chat_bubble_rounded,
        accent: (scheme) => scheme.tertiaryContainer,
        destination: _BrowseDestination.featureRequest,
      ),
    ];

class _BrowseToolCard extends StatefulWidget {
  const _BrowseToolCard({
    required this.tool,
    required this.onTap,
  });

  final _BrowseTool tool;
  final VoidCallback onTap;

  @override
  State<_BrowseToolCard> createState() => _BrowseToolCardState();
}

class _BrowseToolCardState extends State<_BrowseToolCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final iconBackground = _browseCategoryAccent(
      colorScheme,
      widget.tool.category,
    );

    return Semantics(
      button: true,
      label: widget.tool.title,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.surfaceBorder,
            ),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: colorScheme.foreground.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: colorScheme.surface.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: widget.tool.customIcon == null
                                ? Icon(
                                    widget.tool.icon,
                                    color: colorScheme.foreground,
                                    size: 22,
                                  )
                                : MessagingAppLogo(
                                    type: widget.tool.customIcon!,
                                    color: colorScheme.foreground,
                                    size: 22,
                                  ),
                          ),
                        ),
                        if (widget.tool.isLocked)
                          Icon(
                            Icons.lock_outline_rounded,
                            color: colorScheme.mutedForeground,
                            size: 17,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.tool.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScenarioToolPage extends ConsumerStatefulWidget {
  const _ScenarioToolPage();

  @override
  ConsumerState<_ScenarioToolPage> createState() => _ScenarioToolPageState();
}

class _ScenarioToolPageState extends ConsumerState<_ScenarioToolPage> {
  late final SpotlightTourController _spotlightController;

  @override
  void initState() {
    super.initState();
    _spotlightController =
        SpotlightTourController(tourId: 'browse_ai_scenario_v1');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final analyticsData = ref.watch(analyticsProvider);
    final selectedCurrency = ref.watch(selectedHomeCurrencyCodeProvider);
    final auth = ref.watch(authProvider);

    if (auth.uid.isNotEmpty &&
        analyticsData.allExpenses.isEmpty &&
        !analyticsData.isLoading &&
        analyticsData.hasLoadedOnce != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(analyticsProvider.notifier).loadData(auth.uid);
        }
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        title: Text(context.l10n.scenarioTab),
        backgroundColor: colorScheme.appBackground,
      ),
      body: buildScenarioPlanningTab(
        context,
        analyticsData,
        selectedCurrency: selectedCurrency,
        spotlightController: _spotlightController,
      ),
    );
  }
}
