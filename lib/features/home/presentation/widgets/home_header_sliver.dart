import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/navigation/custom_drawer.dart';
import 'package:moneko/core/navigation/navigation_providers.dart';
import 'package:moneko/core/navigation/zoom_drawer_provider.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_controller.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_target.dart';
import 'package:moneko/features/home/presentation/state/home_spotlight_providers.dart';
import 'package:moneko/features/home/presentation/state/home_debug_tracing.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/state.dart';
import 'package:moneko/features/home/presentation/state/dashboard_lazy_providers.dart';
import 'package:moneko/features/home/presentation/widgets/currency_selector_modal.dart';
import 'package:moneko/features/utils/currency_flags.dart';
import 'package:moneko/features/home/presentation/widgets/customizable_dashboard/dashboard_state.dart';
import 'package:moneko/features/home/presentation/widgets/connect_social_banner.dart';
import 'package:moneko/features/home/presentation/widgets/transaction_export_options_sheet.dart';
import 'package:moneko/shared/widgets/spotlight/spotlight_step.dart';

import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/households/presentation/pages/create_space_page.dart';
import 'package:moneko/features/households/presentation/pages/household_settings_page.dart';
import 'package:moneko/features/profile/presentation/pages/settings_page.dart';
import 'package:moneko/shared/widgets/moneko_avatar.dart';
import 'package:moneko/features/home/presentation/utils/transaction_export_data_source.dart';
import 'package:moneko/features/home/presentation/utils/export_date_range.dart';
import 'package:moneko/features/home/presentation/utils/transaction_exporter.dart';
import 'package:moneko/features/home/presentation/pages/overview_dashboard_page.dart';
import 'package:moneko/shared/widgets/blocking_processing_dialog.dart';
import 'package:moneko/core/preview/preview_mode_provider.dart';

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

String _exportFileNamePrefix(
  String exportType,
  TransactionExportRequest request,
) {
  final start = formatExportDate(request.dateRange.start);
  final end = formatExportDate(request.dateRange.end);
  return 'moneko_${exportType}_${_exportSpaceFileSlug(request.space)}_${start}_to_$end';
}

String _exportSpaceFileSlug(TransactionExportSpaceOption space) {
  switch (space.type) {
    case TransactionExportSpaceType.all:
      return 'all_spaces';
    case TransactionExportSpaceType.personal:
      return 'personal';
    case TransactionExportSpaceType.household:
      return _slugFileSegment(space.label, fallback: 'space');
  }
}

String _slugFileSegment(String value, {required String fallback}) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? fallback : slug;
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
                  final resolved = _resolveSelectedHousehold(
                      selectedHouseholdState, combined);
                  return resolved?.name ??
                      _userLabel(user, shortenEmail: false);
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
    final currencyCode = ref.watch(selectedHomeCurrencyCodeProvider);
    final isEditMode = ref.watch(isEditModeProvider);
    final headerTrace = HomeDebugTrace(
      label: 'HomeHeaderSpaceSwitch',
      enabled: ref.read(homeDebugLoggingEnabledProvider),
      logSink: ref.read(homeDebugLogSinkProvider),
      contextFields: {'user': user.uid.isEmpty ? '<empty>' : user.uid},
    );

    Future<void> handleBankSyncResult(BankSyncResult next) async {
      if (user.uid.isEmpty) return;

      ref.invalidate(userHouseholdsProvider(user.uid));

      final targetCurrency = next.currencyCode?.toUpperCase();
      if (targetCurrency != null && targetCurrency.isNotEmpty) {
        ref
            .read(homeFilterProvider.notifier)
            .setSelectedCurrency(targetCurrency);
      }

      await ref.read(analyticsProvider.notifier).loadData(user.uid);
      ref.read(dashboardRefreshSignalProvider.notifier).state += 1;
    }

    Future<void> refreshHomeDataForSelectedAccount({
      bool refreshCurrenciesNow = false,
    }) async {
      if (refreshCurrenciesNow) {
        ref.invalidate(currencyTransactionCountsProvider);
        ref.invalidate(dashboardCurrencySummariesProvider);
        ref
            .read(dashboardCurrencySummariesRefreshSignalProvider.notifier)
            .state++;
      }
      // Home analytics is loaded once during app initialization and filtered
      // locally by `householdScopeProvider` + `homeFilterProvider`, so space /
      // currency changes recompute immediately without a refetch. Currency
      // summary RPC data is scoped and refreshed only when the header asks for
      // it, while still serving cached rows for quick modal paint.
      //
      // Recurring and pockets pages lazy-load off their active tab using the
      // current scope/currency, so changing the header selection updates the
      // parameters they will use the next time those tabs become visible.
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

    const previewLabel = 'Sarah Collins';

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
                    return resolved?.name ??
                        _userLabel(user, shortenEmail: true);
                  },
                ),
      maxLength: 18,
    );

    Future<void> exportAllTransactions() async {
      final households = householdsAsync.valueOrNull ?? const <Household>[];
      final exportPersonalLabel = preview.isActive
          ? previewLabel
          : user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : user.email;
      final exportRequest = await showTransactionExportOptionsSheet(
        context: context,
        spaces: households,
        personalLabel: exportPersonalLabel,
      );
      if (!context.mounted || exportRequest == null) {
        debugPrint('[HomeHeaderSliver.export] export options canceled');
        return;
      }
      debugPrint(
        '[HomeHeaderSliver.export] selected format=${exportRequest.format.name} '
        'space=${exportRequest.space.type.name}:${exportRequest.space.householdId ?? "<all>"} '
        'range=${formatExportDateRange(exportRequest.dateRange)}',
      );

      final rootNavigator = Navigator.of(context, rootNavigator: true);
      var dialogClosed = false;
      void closeBlockingDialog() {
        if (dialogClosed || !rootNavigator.mounted) return;
        debugPrint('[HomeHeaderSliver.export] closing blocking dialog');
        rootNavigator.pop();
        dialogClosed = true;
      }

      debugPrint('[HomeHeaderSliver.export] showing blocking dialog');
      showBlockingProcessingDialog(
        context: context,
        message: context.l10n.exportTransactions,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) {
        debugPrint('[HomeHeaderSliver.export] context unmounted after dialog');
        closeBlockingDialog();
        return;
      }

      final exportableExpenses = await TransactionExportDataSource(
        ref.read(supabaseClientProvider),
      ).fetchExportExpenses(
        userId: user.uid,
        dateRange: exportRequest.dateRange,
        space: exportRequest.space,
      );
      if (!context.mounted) {
        closeBlockingDialog();
        return;
      }
      debugPrint(
        '[HomeHeaderSliver.export] fetched ${exportableExpenses.length} rows '
        'from expenses table',
      );
      final householdNames = {
        for (final household in households) household.id: household.name,
      };
      try {
        if (exportRequest.format == TransactionExportFormat.excel) {
          debugPrint(
            '[HomeHeaderSliver.export] exporting Excel '
            'transactions=${exportableExpenses.length} '
            'space=${exportRequest.space.label}',
          );
          await exportAllTransactionsAsExcelSheet(
            context,
            exportableExpenses,
            personalLabel: exportPersonalLabel,
            householdNames: householdNames,
            selectedDateRange: exportRequest.dateRange,
            fileNamePrefix:
                _exportFileNamePrefix('transactions', exportRequest),
            onBeforeShare: closeBlockingDialog,
          );
        } else if (exportRequest.format ==
            TransactionExportFormat.receiptsZip) {
          debugPrint(
            '[HomeHeaderSliver.export] exporting receipts '
            'transactions=${exportableExpenses.length} '
            'space=${exportRequest.space.label}',
          );
          await exportAllReceiptsAsZip(
            context,
            exportableExpenses,
            fileNamePrefix: _exportFileNamePrefix('receipts', exportRequest),
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
            headerTrace
                .mark('space-switch-start', const {'target': 'personal-space'});
            ref.read(viewModeProvider.notifier).setPersonalMode();
            await refreshHomeDataForSelectedAccount(
              refreshCurrenciesNow: true,
            );
            headerTrace.mark(
                'space-switch-complete', const {'target': 'personal-space'});
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
          headerTrace.mark('space-switch-start', {
            'target': 'shared-or-private-space',
            'spaceId': householdId,
          });
          await ref
              .read(selectedHouseholdProvider.notifier)
              .selectHousehold(householdId);

          if (kDebugMode) {
            debugPrint('🔄 Switching to household mode');
          }
          ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
          await refreshHomeDataForSelectedAccount(
            refreshCurrenciesNow: true,
          );
          headerTrace.mark('space-switch-complete', {
            'target': 'shared-or-private-space',
            'spaceId': householdId,
          });
        }
      },
    );

    final filterState = ref.watch(homeFilterProvider);
    final allSelectedCurrencies =
        filterState.normalizedSelectedCurrencies ?? [currencyCode];
    final isMultiCurrency = allSelectedCurrencies.length > 1;

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
              if (!isMultiCurrency)
                Text(
                  currencyCode,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.foreground,
                  ),
                )
              else ...[
                // Show only 1 flag (primary) and a +N indicator for the rest
                ...allSelectedCurrencies.take(1).map((code) {
                  final flagPath = getCurrencyFlagPath(code);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: ClipOval(
                        child: flagPath != null
                            ? Image.asset(flagPath, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  code.substring(0, 1),
                                  style: const TextStyle(fontSize: 8),
                                ),
                              ),
                      ),
                    ),
                  );
                }),
                if (allSelectedCurrencies.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '+${allSelectedCurrencies.length - 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
              ],
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
    // 3. Export Transactions (low frequency, organized separately)
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

    final currentIndex = ref.watch(mainShellTabIndexProvider);
    if (currentIndex == 0) {
      menuItems.add(AdaptivePopupMenuItem(
        label: context.l10n.editWidgets,
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'square.grid.2x2'
            : Icons.dashboard_customize_outlined,
        value: 'edit_widgets',
      ));
    }

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
                        final prefs = ref.read(sharedPreferencesProvider);
                        final userId = ref.read(authProvider).uid;
                        final trialBannerDismissedPrefix = userId.isEmpty
                            ? 'trial_reminder_banner_dismissed_milestone:'
                            : 'trial_reminder_banner_dismissed_milestone:$userId:';
                        await prefs.remove(
                          'home_connect_social_dismissed_steps_v1',
                        );
                        await prefs.remove(
                            'accounts_month_swipe_hint_dismissed:$userId');
                        await prefs.remove(
                            'pockets_month_swipe_hint_dismissed:$userId');
                        final trialBannerKeys = prefs
                            .getKeys()
                            .where((key) =>
                                key.startsWith(trialBannerDismissedPrefix))
                            .toList(growable: false);
                        for (final key in trialBannerKeys) {
                          await prefs.remove(key);
                        }
                        ref.invalidate(dismissedChecklistStepsProvider);
                        debugPrint(
                          '🔁 Spotlight tours + accounts/pockets swipe hints + trial reminder banner state reset for debugging',
                        );
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

        final household = _resolveSelectedHousehold(
              selectedHouseholdState,
              households,
            ) ??
            households.first;
        return MonekoAvatar.network(
          size: size,
          fallbackIcon: Icons.home_rounded,
          imageUrl: household.coverImageUrl,
        );
      },
    );
  }
}
