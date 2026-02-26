import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/navigation/custom_drawer.dart';
import 'package:moneko/core/navigation/zoom_drawer_provider.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_target.dart';
import 'package:moneko/features/home/presentation/state/home_spotlight_providers.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';

import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:moneko/features/pockets/presentation/state/pockets_providers.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/households/presentation/pages/create_space_page.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';
import 'package:moneko/shared/widgets/moneko_avatar.dart';
import 'package:moneko/features/home/presentation/utils/transaction_exporter.dart';
import 'package:moneko/features/home/presentation/pages/overview_dashboard_page.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';

enum _ExportAction {
  exportExcel,
  exportReceipts,
  cancel,
}

Household? _resolveSelectedHousehold(
  SelectedHouseholdState selectedState,
  List<Household> households,
) {
  if (households.isEmpty) {
    return selectedState.household;
  }

  final selectedId = selectedState.householdId ?? selectedState.household?.id;
  if (selectedId == null) return households.first;

  return households.firstWhere(
    (h) => h.id == selectedId,
    orElse: () => households.first,
  );
}

String _truncateMenuLabel(String label, {int maxLength = 20}) {
  final trimmed = label.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength - 1)}…';
}

String _emailLocalPart(String email) {
  final trimmed = email.trim();
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) return trimmed;
  return trimmed.substring(0, atIndex);
}

String _userLabel(AppUser user, {required bool shortenEmail}) {
  final displayName = user.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;

  return shortenEmail ? _emailLocalPart(user.email) : user.email.trim();
}

/// Leading widget for app bar that includes:
/// - Profile/Household avatar
/// - Personal/Household name
class HomeHeaderLeading extends ConsumerWidget {
  const HomeHeaderLeading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final user = ref.watch(authProvider);
    final preview = ref.watch(previewModeProvider);
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final previewPrivateSpaces = preview.isActive
        ? [
            Household(
              id: 'preview-card',
              name: 'Chase Sapphire',
              ownerId: user.uid.isNotEmpty ? user.uid : 'preview-user',
              currency: 'USD',
              themeColor: '#0EA5E9',
              createdAt: DateTime.now().subtract(const Duration(days: 45)),
              updatedAt: DateTime.now(),
              isPortfolio: true,
              coverImageUrl: null,
            ),
            Household(
              id: 'preview-savings',
              name: 'High-Yield Savings',
              ownerId: user.uid.isNotEmpty ? user.uid : 'preview-user',
              currency: 'USD',
              themeColor: '#10B981',
              createdAt: DateTime.now().subtract(const Duration(days: 90)),
              updatedAt: DateTime.now(),
              isPortfolio: true,
              coverImageUrl: null,
            ),
          ]
        : const <Household>[];
    final AppDrawerController zoomController =
        ref.read(zoomDrawerControllerProvider);

    final name = preview.isActive
        ? 'Moneko Preview'
        : viewMode.mode == ViewMode.personal
            ? _userLabel(user, shortenEmail: false)
            : householdsAsync.when(
                loading: () => _userLabel(user, shortenEmail: false),
                error: (_, __) => _userLabel(user, shortenEmail: false),
                data: (households) {
                  final combined = [
                    ...households,
                    ...previewPrivateSpaces,
                  ];
                  if (combined.isEmpty) {
                    return _userLabel(user, shortenEmail: false);
                  }
                  final resolved =
                      _resolveSelectedHousehold(selectedHouseholdState, combined);
                  return resolved?.name ?? _userLabel(user, shortenEmail: false);
                },
              );

    return GestureDetector(
      onTap: () => zoomController.toggle?.call(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderAvatarButton(
            user: user,
            viewMode: viewMode,
            householdsAsync: householdsAsync,
            selectedHouseholdState: selectedHouseholdState,
            isPreview: preview.isActive,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: colorScheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trailing widget for app bar that includes:
/// - Personal/Household mode switch list
class HomeHeaderTrailing extends ConsumerWidget {
  const HomeHeaderTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

/// Header for pages that includes:
/// - Profile/Household cover photo (Pill shape)
/// - Currency Selector
/// - Settings Menu
class HomeHeaderSliver extends ConsumerWidget {
  const HomeHeaderSliver({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewMode = ref.watch(viewModeProvider);
    final user = ref.watch(authProvider);
    final preview = ref.watch(previewModeProvider);
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final spotlightController = ref.read(homeSpotlightControllerProvider);
    // Move currency state reading here
    final currencyCode =
        ref.watch(homeFilterProvider).selectedCurrency ?? 'USD';
    final isEditMode = ref.watch(isEditModeProvider);

    Future<void> handleBankSyncResult(BankSyncResult next) async {
      if (user.uid.isEmpty) return;

      ref.invalidate(userHouseholdsProvider(user.uid));
      if (next.householdId != null && next.householdId!.isNotEmpty) {
        await ref
            .read(selectedHouseholdProvider.notifier)
            .selectHousehold(next.householdId!);
        ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
      }

      final targetCurrency = next.currencyCode?.toUpperCase();
      if (targetCurrency != null && targetCurrency.isNotEmpty) {
        ref
            .read(homeFilterProvider.notifier)
            .setSelectedCurrency(targetCurrency);
      }

      await ref.read(analyticsProvider.notifier).loadData(user.uid);
    }

    Future<void> refreshHomeDataForSelectedAccount({
      bool refreshCurrenciesNow = false,
    }) async {
      if (user.uid.isEmpty) return;

      ref.read(analyticsProvider.notifier).refresh(user.uid);

      final currentViewMode = ref.read(viewModeProvider);
      final currentSelectedHousehold = ref.read(selectedHouseholdProvider);
      final rawHouseholdId = currentViewMode.mode == ViewMode.household
          ? currentSelectedHousehold.householdId
          : null;
      final householdId =
          (rawHouseholdId != null && rawHouseholdId.trim().isNotEmpty)
              ? rawHouseholdId
              : null;

      ref
          .read(recurringTransactionsProvider(householdId).notifier)
          .refresh(user.uid);
      ref.invalidate(pocketsProvider);

      if (refreshCurrenciesNow) {
        ref.invalidate(currencySummariesProvider);
        ref.invalidate(currencyTransactionCountsProvider);
        ref.read(currencySummariesProvider);
        await ref.read(currencyTransactionCountsProvider.future);
      } else {
        ref.invalidate(currencySummariesProvider);
        ref.invalidate(currencyTransactionCountsProvider);
      }
    }

    ref.listen<BankSyncResult?>(bankSyncResultProvider, (previous, next) {
      if (next == null) return;

      // Clear immediately to prevent duplicate scheduling across rebuilds.
      ref.read(bankSyncResultProvider.notifier).state = null;
      Future<void>(() => handleBankSyncResult(next));
    });

    // If the result was set before this widget mounted, ref.listen won't fire.
    // Handle any pending result on first build.
    final pendingResult = ref.read(bankSyncResultProvider);
    if (pendingResult != null) {
      ref.read(bankSyncResultProvider.notifier).state = null;
      Future<void>(() => handleBankSyncResult(pendingResult));
    }

    final selectedHouseholdIdForSettings = viewMode.mode == ViewMode.household
        ? (selectedHouseholdState.householdId ??
            selectedHouseholdState.household?.id)
        : null;

    final previewLabel = 'Sarah Collins';

    final personalLabel = _truncateMenuLabel(
      preview.isActive ? previewLabel : _userLabel(user, shortenEmail: true),
    );

    final profilePillLabel = _truncateMenuLabel(
      preview.isActive
          ? previewLabel
          : viewMode.mode == ViewMode.personal
              ? _userLabel(user, shortenEmail: true)
              : householdsAsync.when(
                  loading: () => _userLabel(user, shortenEmail: true),
                  error: (_, __) => _userLabel(user, shortenEmail: true),
                  data: (households) {
                    if (households.isEmpty) {
                      return _userLabel(user, shortenEmail: true);
                    }
                    final resolved = _resolveSelectedHousehold(
                        selectedHouseholdState, households);
                    return resolved?.name ?? _userLabel(user, shortenEmail: true);
                  },
                ),
      maxLength: 18,
    );

    Future<void> exportAllTransactions() async {
      _ExportAction? selection;
      await AdaptiveAlertDialog.show(
        context: context,
        title: context.l10n.exportTransactions,
        message: context.l10n.chooseSourceForAnalysis,
        actions: [
          AlertAction(
            title: context.l10n.exportReceiptsZip,
            style: AlertActionStyle.primary,
            onPressed: () {
              selection = _ExportAction.exportReceipts;
            },
          ),
          AlertAction(
            title: context.l10n.exportExcel,
            style: AlertActionStyle.primary,
            onPressed: () {
              selection = _ExportAction.exportExcel;
            },
          ),
          AlertAction(
            title: context.l10n.cancel,
            style: AlertActionStyle.cancel,
            onPressed: () {
              selection = _ExportAction.cancel;
            },
          ),
        ],
      );
      if (!context.mounted || selection == null) return;
      if (selection == _ExportAction.cancel) return;

      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.exportTransactions,
      );
      var dialogClosed = false;
      void closeBlockingDialog() {
        if (!context.mounted || dialogClosed) return;
        dialogClosed = true;
        Navigator.of(context, rootNavigator: true).maybePop();
      }

      final analyticsData = ref.read(analyticsProvider);
      final exportableExpenses = analyticsData.allExpenses
          .where((e) => !e.isRecurring)
          .toList(growable: false);
      final households = householdsAsync.valueOrNull ?? const <Household>[];
      final householdNames = {
        for (final household in households) household.id: household.name,
      };
      final personalLabel = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email;
      try {
        if (selection == _ExportAction.exportExcel) {
          await exportAllTransactionsAsExcelSheet(
            context,
            exportableExpenses,
            personalLabel: personalLabel,
            householdNames: householdNames,
            onBeforeShare: closeBlockingDialog,
          );
        } else if (selection == _ExportAction.exportReceipts) {
          await exportAllReceiptsAsZip(
            context,
            exportableExpenses,
            onBeforeShare: closeBlockingDialog,
          );
        }
      } finally {
        closeBlockingDialog();
      }
    }

    // Profile Pill (Left)
    final profilePill = AdaptivePopupMenuButton.widget(
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: colorScheme.cardSurface, // Adaptive light/dark gray
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderAvatarButton(
              user: user,
              viewMode: viewMode,
              householdsAsync: householdsAsync,
              selectedHouseholdState: selectedHouseholdState,
              isPreview: preview.isActive,
              size: 32, // Smaller size for the pill
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                profilePillLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: colorScheme.mutedForeground,
            ),
          ],
        ),
      ),
      items: [
        AdaptivePopupMenuItem(
          label: context.l10n.accountOverview,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'chart.pie.fill'
              : Icons.pie_chart,
          value: 'overview',
        ),
        AdaptivePopupMenuItem(
          label: personalLabel,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'person.crop.circle.fill'
              : Icons.account_circle,
          value: 'personal',
        ),
        ...householdsAsync.when(
          data: (households) => households
              .map(
                (household) => AdaptivePopupMenuItem(
                  label: _truncateMenuLabel(household.name),
                  icon: household.isPortfolio
                      ? (PlatformInfo.isIOS26OrHigher()
                          ? 'person.crop.circle.fill'
                          : Icons.person)
                      : (PlatformInfo.isIOS26OrHigher()
                          ? 'person.2.fill'
                          : Icons.group),
                  value: 'household:${household.id}',
                ),
              )
              .toList(),
          loading: () => <AdaptivePopupMenuItem>[
            AdaptivePopupMenuItem(
              label: context.l10n.loading,
              icon: PlatformInfo.isIOS26OrHigher()
                  ? 'arrow.clockwise'
                  : Icons.sync,
              value: 'loading',
            ),
          ],
          error: (_, __) => <AdaptivePopupMenuItem>[
            AdaptivePopupMenuItem(
              label: context.l10n.errorTitle,
              icon: PlatformInfo.isIOS26OrHigher()
                  ? 'exclamationmark.triangle.fill'
                  : Icons.error,
              value: 'error',
            ),
          ],
        ),
        AdaptivePopupMenuItem(
          label: context.l10n.createSpace,
          icon: PlatformInfo.isIOS26OrHigher() ? 'plus' : Icons.add,
          value: 'create_space',
        ),
      ],
      onSelected: (index, item) async {
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);

        if (item.value == 'overview') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const OverviewDashboardPage(),
            ),
          );
          return;
        }

        if (item.value == 'personal') {
          if (viewMode.mode != ViewMode.personal) {
            ref.read(viewModeProvider.notifier).setPersonalMode();
            await refreshHomeDataForSelectedAccount(
              refreshCurrenciesNow: true,
            );
          }
          return;
        }

        if (item.value == 'create_space') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateSpacePage(),
            ),
          );
          return;
        }

        if (item.value is String &&
            (item.value as String).startsWith('household:')) {
          final householdId = (item.value as String).split(':').last;
          await ref
              .read(selectedHouseholdProvider.notifier)
              .selectHousehold(householdId);

          if (kDebugMode) {
            debugPrint('🔄 Switching to household mode');
          }
          ref.invalidate(userHouseholdsProvider(user.uid));
          ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
          await refreshHomeDataForSelectedAccount(
            refreshCurrenciesNow: true,
          );
        }
      },
    );

    // Currency Pill (Right)
    final currencyPill = GestureDetector(
      onTap: () async {
        await showCurrencySelectorModal(context, ref);
        await refreshHomeDataForSelectedAccount(refreshCurrenciesNow: true);
      },
      child: SpotlightTarget(
        controller: spotlightController,
        id: 'home_header_currency',
        title: context.l10n.change_currency_title,
        description: context.l10n.change_currency_desc,
        padding: 6,
        borderRadius: 24,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.cardSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currencyCode,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );

    // Build menu items dynamically - ordered by frequency/context priority
    // 1. Shared Space & Members (most relevant, household context)
    // 2. Customize Widgets (high frequency)
    // 3. Export Transactions (low frequency, grouped separately)
    // 4. Settings (system, always at bottom)
    final menuItems = <AdaptivePopupMenuItem>[];

    if (selectedHouseholdIdForSettings != null) {
      final currentHousehold = householdsAsync.when(
        data: (households) {
          if (households.isEmpty) return null;
          return households.firstWhere(
            (h) => h.id == selectedHouseholdIdForSettings,
            orElse: () => households.first,
          );
        },
        loading: () => null,
        error: (_, __) => null,
      );

      if (currentHousehold != null) {
        menuItems.add(AdaptivePopupMenuItem(
          label: currentHousehold.isPortfolio
              ? context.l10n.managePrivateSpace
              : context.l10n.manageSharedSpace,
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'person.2.badge.gearshape'
              : Icons.manage_accounts_outlined,
          value: 'manage_household',
        ));
      } else {
        menuItems.add(AdaptivePopupMenuItem(
          label: '${context.l10n.manage} ${context.l10n.household}',
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'person.2.badge.gearshape'
              : Icons.manage_accounts_outlined,
          value: 'manage_household',
        ));
      }
    }

    menuItems.add(AdaptivePopupMenuItem(
      label: context.l10n.editWidgets,
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'square.grid.2x2'
          : Icons.dashboard_customize_outlined,
      value: 'edit_widgets',
    ));

    menuItems.add(AdaptivePopupMenuItem(
      label: context.l10n.exportTransactions,
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'square.and.arrow.up'
          : Icons.file_download_rounded,
      value: 'export_all',
    ));

    menuItems.add(AdaptivePopupMenuItem(
      label: context.l10n.settings,
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'gearshape'
          : Icons.settings_outlined,
      value: 'settings',
    ));

    // Animated switcher swaps between check button (edit mode) and menu button (normal mode)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              EdgeInsets.fromLTRB(12.0, Platform.isAndroid ? 12 : 0, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Profile Pill
              SpotlightTarget(
                controller: spotlightController,
                id: 'home_header_mode_switch',
                title: context.l10n.homeModeTourTitle,
                description: context.l10n.homeModeTourDescription,
                padding: 4,
                borderRadius: 20,
                placement: SpotlightPlacement.bottom,
                child: profilePill,
              ),

// Right side: Currency + AnimatedSwitcher (Menu/Check button)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: isEditMode
                        ? const SizedBox.shrink(key: ValueKey('currencyHidden'))
                        : SizedBox(
                            key: const ValueKey('currencyVisible'),
                            child: currencyPill,
                          ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: isEditMode
                        ? GestureDetector(
                            key: const ValueKey('doneButton'),
                            onTap: () {
                              ref.read(isEditModeProvider.notifier).state =
                                  false;
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 24,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : AdaptivePopupMenuButton.widget(
                            key: const ValueKey('menuButton'),
                            child: Container(
                              height: 40,
                              width: 40,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: colorScheme.foreground,
                                size: 24,
                              ),
                            ),
                            items: menuItems,
                            onSelected: (index, item) async {
                              if (item.value == 'manage_household' &&
                                  selectedHouseholdIdForSettings != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => HouseholdSettingsPage(
                                      householdId:
                                          selectedHouseholdIdForSettings,
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (item.value == 'edit_widgets') {
                                ref.read(isEditModeProvider.notifier).state =
                                    true;
                                return;
                              }

                              if (item.value == 'export_all') {
                                await exportAllTransactions();
                                return;
                              }

                              if (item.value == 'settings') {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsPage(),
                                  ),
                                );
                                return;
                              }
                            },
                          ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.bug_report_outlined, size: 20),
                      tooltip: 'Reset tours',
                      onPressed: () async {
                        await SpotlightTourController.resetAllTours();
                        debugPrint('🔁 Spotlight tours reset for debugging');
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderAvatarButton extends StatelessWidget {
  const _HeaderAvatarButton({
    required this.user,
    required this.viewMode,
    required this.householdsAsync,
    required this.selectedHouseholdState,
    required this.isPreview,
    this.size = 44,
  });

  final AppUser user;
  final ViewModeState viewMode;
  final AsyncValue<List<Household>> householdsAsync;
  final SelectedHouseholdState selectedHouseholdState;
  final bool isPreview;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isPreview) {
      return ClipOval(
        child: Image.asset(
          'lib/assets/mascots/moneko.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    if (viewMode.mode == ViewMode.personal) {
      return MonekoAvatar.supabaseUser(
        size: size,
        userId: user.uid,
        fallbackImageUrl: user.photoUrl,
      );
    }

    return householdsAsync.when(
      loading: () => MonekoAvatar.placeholder(size: size),
      error: (_, __) => MonekoAvatar.placeholder(size: size),
      data: (households) {
        if (households.isEmpty) {
          return MonekoAvatar.placeholder(size: size);
        }

        final household = selectedHouseholdState.household ?? households.first;
        return MonekoAvatar.network(
          size: size,
          fallbackIcon: Icons.home_rounded,
          imageUrl: household.coverImageUrl,
        );
      },
    );
  }
}
