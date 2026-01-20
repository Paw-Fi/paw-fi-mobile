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

Household _resolveSelectedHousehold(
  SelectedHouseholdState selectedState,
  List<Household> households,
) {
  if (households.isEmpty) {
    throw ArgumentError.value(
      households,
      'households',
      'Must not be empty when resolving selection',
    );
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
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final AppDrawerController zoomController =
        ref.read(zoomDrawerControllerProvider);

    final name = viewMode.mode == ViewMode.personal
        ? (user.displayName?.isNotEmpty == true
            ? user.displayName!
            : user.email)
        : householdsAsync.when(
            loading: () => context.l10n.forUs,
            error: (_, __) => context.l10n.forUs,
            data: (households) {
              if (households.isEmpty) return context.l10n.forUs;
              return _resolveSelectedHousehold(
                      selectedHouseholdState, households)
                  .name;
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
    final selectedHouseholdState = ref.watch(selectedHouseholdProvider);
    final householdsAsync = ref.watch(userHouseholdsProvider(user.uid));
    final spotlightController = ref.read(homeSpotlightControllerProvider);
    // Move currency state reading here
    final currencyCode =
        ref.watch(homeFilterProvider).selectedCurrency ?? 'USD';

    final selectedHouseholdIdForSettings = viewMode.mode == ViewMode.household
        ? (selectedHouseholdState.householdId ??
            selectedHouseholdState.household?.id)
        : null;

    final personalLabel = _truncateMenuLabel(
      (user.displayName?.trim().isNotEmpty == true)
          ? user.displayName!
          : (user.email.contains('@')
              ? user.email.split('@').first
              : user.email),
    );

    final profilePillLabel = _truncateMenuLabel(
      viewMode.mode == ViewMode.personal
          ? ((user.displayName?.trim().isNotEmpty == true)
              ? user.displayName!
              : (user.email.contains('@')
                  ? user.email.split('@').first
                  : user.email))
          : householdsAsync.when(
              loading: () => context.l10n.forUs,
              error: (_, __) => context.l10n.forUs,
              data: (households) {
                if (households.isEmpty) return context.l10n.forUs;
                return _resolveSelectedHousehold(
                  selectedHouseholdState,
                  households,
                ).name;
              },
            ),
      maxLength: 18,
    );

    Future<void> exportAllTransactions() async {
      final analyticsData = ref.read(analyticsProvider);
      final households = householdsAsync.valueOrNull ?? const <Household>[];
      final householdNames = {
        for (final household in households) household.id: household.name,
      };
      final personalLabel = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : user.email;

      await exportAllTransactionsAsExcelSheet(
        context,
        analyticsData.allExpenses,
        personalLabel: personalLabel,
        householdNames: householdNames,
      );
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
          loading: () => <AdaptivePopupMenuItem>[],
          error: (_, __) => <AdaptivePopupMenuItem>[],
        ),
        AdaptivePopupMenuItem(
          label: context.l10n.createSpace, // TODO: Localize
          icon: PlatformInfo.isIOS26OrHigher() ? 'plus' : Icons.add,
          value: 'create_space',
        ),
      ],
      onSelected: (index, item) async {
        HapticFeedback.selectionClick();
        SystemSound.play(SystemSoundType.click);

        if (item.value == 'personal') {
          if (viewMode.mode != ViewMode.personal) {
            ref.read(viewModeProvider.notifier).setPersonalMode();
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

          debugPrint('🔄 Switching to household mode');
          ref.invalidate(userHouseholdsProvider(user.uid));
          ref.read(viewModeProvider.notifier).setMode(ViewMode.household);
        }
      },
    );

    // Currency Pill (Right)
    final currencyPill = GestureDetector(
      onTap: () async {
        await showCurrencySelectorModal(context, ref);
        // Logic from main_menu_screen.dart to refresh data after currency change
        if (user.uid.isEmpty) return;
        ref.read(analyticsProvider.notifier).refresh(user.uid);

        final currentViewMode = ref.read(viewModeProvider);
        final currentSelectedHousehold = ref.read(selectedHouseholdProvider);
        final householdId = currentViewMode.mode == ViewMode.household
            ? currentSelectedHousehold.householdId
            : null;

        ref
            .read(recurringTransactionsProvider(householdId).notifier)
            .refresh(user.uid);
        ref.invalidate(pocketsProvider);
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

    // Build menu items dynamically
    final menuItems = <AdaptivePopupMenuItem>[
      AdaptivePopupMenuItem(
        label: context.l10n.settings,
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'gearshape'
            : Icons.settings_outlined,
        value: 'settings',
      ),
      AdaptivePopupMenuItem(
        label: context.l10n.exportTransactions,
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'square.and.arrow.up'
            : Icons.file_download_rounded,
        value: 'export_all',
      ),
    ];

    if (selectedHouseholdIdForSettings != null) {
      final currentHousehold = householdsAsync.when(
        data: (households) => households.firstWhere(
          (h) => h.id == selectedHouseholdIdForSettings,
          orElse: () => households.first,
        ),
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

    // Menu Button (Right)
    final menuButton = AdaptivePopupMenuButton.widget(
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
        if (item.value == 'settings') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SettingsPage(),
            ),
          );
        }

        if (item.value == 'export_all') {
          await exportAllTransactions();
        }

        if (item.value == 'manage_household' &&
            selectedHouseholdIdForSettings != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HouseholdSettingsPage(
                householdId: selectedHouseholdIdForSettings,
              ),
            ),
          );
        }
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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

              // Right side: Currency + Menu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  currencyPill,
                  const SizedBox(width: 8),
                  menuButton,
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
    this.size = 44,
  });

  final AppUser user;
  final ViewModeState viewMode;
  final AsyncValue<List<Household>> householdsAsync;
  final SelectedHouseholdState selectedHouseholdState;
  final double size;

  @override
  Widget build(BuildContext context) {
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
