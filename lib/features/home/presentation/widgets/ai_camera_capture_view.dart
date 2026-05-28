import 'dart:async';
import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/core/utils/error_handler.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/home/presentation/utils/ai_input_wallet_filter.dart';
import 'package:moneko/features/home/presentation/widgets/ai_input_target.dart';
import 'package:moneko/features/home/presentation/widgets/ai_space_label_utils.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:moneko/features/auth/auth.dart';

class AiCameraCaptureResult {
  const AiCameraCaptureResult({
    required this.imagePath,
    required this.target,
  });

  final String imagePath;
  final AiInputTarget target;
}

class AiCameraCaptureView extends ConsumerStatefulWidget {
  const AiCameraCaptureView({super.key, this.initialTarget});

  final AiInputTarget? initialTarget;

  @override
  ConsumerState<AiCameraCaptureView> createState() =>
      _AiCameraCaptureViewState();
}

class _AiCameraCaptureViewState extends ConsumerState<AiCameraCaptureView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  Object? _cameraError;
  ActiveWalletType _selectedAccountType = ActiveWalletType.personal;
  String? _selectedHouseholdId;
  String? _selectedWalletId;
  bool _hasManuallySelectedWallet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialTarget = widget.initialTarget;
    if (initialTarget != null) {
      _selectedAccountType = initialTarget.accountType;
      _selectedHouseholdId = initialTarget.householdId;
      _selectedWalletId = initialTarget.accountId;
      _hasManuallySelectedWallet = initialTarget.accountId != null;
    } else {
      final scope = ref.read(householdScopeProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      final savedType = aiInputTargetAccountTypeFromStorage(
        prefs.getString(aiInputTargetSpaceTypePreferenceKey),
      );
      _selectedAccountType = savedType ?? scope.activeAccountType;
      _selectedHouseholdId = savedType == null
          ? scope.activeAccountHouseholdId
          : prefs.getString(aiInputTargetSpaceHouseholdPreferenceKey);
      if (_selectedAccountType == ActiveWalletType.personal) {
        _selectedHouseholdId = null;
      }
    }
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(controller.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera available');
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller?.dispose();
      _controller = controller;
      await controller.initialize();
    } catch (error) {
      _cameraError = error;
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  List<AiInputSpaceOption> _spaceOptions(List<Household> households) {
    final personalLabel = resolveAiPersonalSpaceLabel(ref.read(authProvider));
    return buildAiInputSpaceOptions(
      context,
      households: households,
      personalLabel: personalLabel,
    );
  }

  String _spaceLabel(List<Household> households) {
    return resolveAiSelectedSpaceLabel(
      context,
      accountType: _selectedAccountType,
      selectedHouseholdId: _selectedHouseholdId,
      households: households,
      personalLabel: resolveAiPersonalSpaceLabel(ref.read(authProvider)),
    );
  }

  Future<void> _applySpaceSelection(AiInputSpaceOption selected) async {
    if (selected.accountType == _selectedAccountType &&
        selected.householdId == _selectedHouseholdId) {
      return;
    }
    setState(() {
      _selectedAccountType = selected.accountType;
      _selectedHouseholdId = selected.accountType == ActiveWalletType.personal
          ? null
          : selected.householdId;
      _selectedWalletId = null;
      _hasManuallySelectedWallet = false;
    });
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      aiInputTargetSpaceTypePreferenceKey,
      aiInputTargetAccountTypeToStorage(selected.accountType),
    );
    if (selected.householdId == null) {
      await prefs.remove(aiInputTargetSpaceHouseholdPreferenceKey);
    } else {
      await prefs.setString(
        aiInputTargetSpaceHouseholdPreferenceKey,
        selected.householdId!,
      );
    }
  }

  String? _defaultWalletId(List<WalletEntity> wallets) {
    for (final wallet in wallets) {
      if (wallet.isDefault) return wallet.id;
    }
    return wallets.isNotEmpty ? wallets.first.id : null;
  }

  String _walletLabel(List<WalletEntity> wallets) {
    if (wallets.isEmpty) return context.l10n.tapToSet;
    final selectedId = _selectedWalletId;
    if (selectedId != null) {
      for (final wallet in wallets) {
        if (wallet.id == selectedId) return wallet.name;
      }
    }
    final savedId = _savedWalletId();
    if (savedId != null) {
      for (final wallet in wallets) {
        if (wallet.id == savedId) return wallet.name;
      }
    }
    final defaultId = _defaultWalletId(wallets);
    if (defaultId != null) {
      for (final wallet in wallets) {
        if (wallet.id == defaultId) return wallet.name;
      }
    }
    return wallets.first.name;
  }

  String? _savedWalletId() {
    return ref.read(sharedPreferencesProvider).getString(
          aiInputTargetWalletPreferenceKey(
            accountType: _selectedAccountType,
            householdId: _selectedHouseholdId,
            currency: ref.read(selectedHomeCurrencyCodeProvider),
          ),
        );
  }

  Future<void> _applyWalletSelection(WalletEntity selected) async {
    if (selected.id == _selectedWalletId) return;
    setState(() {
      _selectedWalletId = selected.id;
      _hasManuallySelectedWallet = true;
    });
    await ref.read(sharedPreferencesProvider).setString(
          aiInputTargetWalletPreferenceKey(
            accountType: _selectedAccountType,
            householdId: _selectedHouseholdId,
            currency: ref.read(selectedHomeCurrencyCodeProvider),
          ),
          selected.id,
        );
  }

  void _syncWalletSelection(List<WalletEntity> wallets) {
    final desiredId = () {
      if (wallets.isEmpty) return null;
      final currentId = _selectedWalletId;
      final currentExists =
          currentId != null && wallets.any((wallet) => wallet.id == currentId);
      if (_hasManuallySelectedWallet && currentExists) return currentId;
      final savedId = _savedWalletId();
      final savedExists =
          savedId != null && wallets.any((wallet) => wallet.id == savedId);
      if (savedExists) return savedId;
      return _defaultWalletId(wallets);
    }();
    if (desiredId == _selectedWalletId) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedWalletId == desiredId) return;
      setState(() {
        _selectedWalletId = desiredId;
      });
    });
  }

  void _syncSpaceSelectionWithHeader(List<Household> households) {
    if (_selectedAccountType == ActiveWalletType.personal) return;
    final hasSelectedSpace = _selectedHouseholdId != null &&
        households.any((household) => household.id == _selectedHouseholdId);
    if (hasSelectedSpace) return;

    final scope = ref.read(householdScopeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedAccountType = scope.activeAccountType;
        _selectedHouseholdId = scope.activeAccountHouseholdId;
        _selectedWalletId = null;
        _hasManuallySelectedWallet = false;
      });
    });
  }

  AiInputTarget _target(
      List<Household> households, List<WalletEntity> wallets) {
    final effectiveWalletId =
        _selectedWalletId ?? _savedWalletId() ?? _defaultWalletId(wallets);
    WalletEntity? selectedWallet;
    for (final wallet in wallets) {
      if (wallet.id == effectiveWalletId) {
        selectedWallet = wallet;
        break;
      }
    }
    final isPortfolio = _selectedAccountType == ActiveWalletType.portfolio ||
        households.any(
          (household) =>
              household.id == _selectedHouseholdId && household.isPortfolio,
        );
    return AiInputTarget(
      accountType: _selectedAccountType,
      householdId: _selectedAccountType == ActiveWalletType.personal
          ? null
          : _selectedHouseholdId,
      isPortfolio: isPortfolio,
      accountId: effectiveWalletId,
      accountCurrency: selectedWallet?.currency.trim().toUpperCase(),
      spaceLabel: _spaceLabel(households),
    );
  }

  Future<void> _capture(
    List<Household> households,
    List<WalletEntity> wallets,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final image = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(
        AiCameraCaptureResult(
          imagePath: image.path,
          target: _target(households, wallets),
        ),
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          ErrorHandler.getUserFriendlyMessage(
            error,
            context: BackendErrorContext.analyzeExpense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(authProvider).uid;
    final householdsAsync = userId.isEmpty
        ? const AsyncValue<List<Household>>.data([])
        : ref.watch(userHouseholdsProvider(userId));
    final households = householdsAsync.valueOrNull ?? const <Household>[];
    if (householdsAsync.hasValue) {
      _syncSpaceSelectionWithHeader(households);
    }
    final homeFilter = ref.watch(homeFilterProvider);
    final targetHouseholdId = _selectedAccountType == ActiveWalletType.personal
        ? null
        : _selectedHouseholdId;
    final walletsAsync = ref.watch(walletsByHouseholdIdProvider(
      targetHouseholdId,
    ));
    final wallets = filterAiInputTargetWallets(
      walletsAsync.valueOrNull ?? const <WalletEntity>[],
      homeFilter,
    );
    final spaceOptions = _spaceOptions(households);
    _syncWalletSelection(wallets);
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _isInitializing
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colorScheme.primary,
                        ),
                      )
                    : _cameraError != null || !isReady
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                context.l10n.failedToCapturePhoto,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio,
                              child: CameraPreview(controller),
                            ),
                          ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: colorScheme.onSurfaceVariant,
                  iconSize: 22,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 116,
              child: Row(
                children: [               
                  Expanded(
                    child: AdaptivePopupMenuButton.widget(
                      child: CameraTargetChip(
                        icon: Icons.grid_view_rounded,
                        value: _spaceLabel(households),
                      ),
                      items: spaceOptions.reversed
                          .map(
                            (option) => AdaptivePopupMenuItem(
                              label: option.label,
                              icon: option.accountType ==
                                      ActiveWalletType.personal
                                  ? Icons.person_outline
                                  : Icons.people_outline,
                              value: option,
                            ),
                          )
                          .toList(growable: false),
                      onSelected: (index, item) async {
                        final selected = item.value;
                        if (selected is! AiInputSpaceOption) return;
                        HapticFeedback.selectionClick();
                        await _applySpaceSelection(selected);
                      },
                    ),
                  ),
                  if (walletsAsync.isLoading || wallets.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdaptivePopupMenuButton.widget(
                        child: CameraTargetChip(
                          icon: Icons.account_balance_wallet_rounded,
                          value: walletsAsync.when(
                            data: (_) => _walletLabel(wallets),
                            loading: () => context.l10n.loading,
                            error: (_, __) => context.l10n.tapToSet,
                          ),
                        ),
                        items: wallets.reversed
                            .map(
                              (wallet) => AdaptivePopupMenuItem(
                                label: wallet.name,
                                icon: Icons.account_balance_wallet_rounded,
                                value: wallet,
                              ),
                            )
                            .toList(growable: false),
                        onSelected: (index, item) async {
                          final selected = item.value;
                          if (selected is! WalletEntity) return;
                          HapticFeedback.selectionClick();
                          await _applyWalletSelection(selected);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: GestureDetector(
                  onTap: isReady && !_isCapturing
                      ? () => _capture(households, wallets)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.onSurface,
                      border: Border.all(
                        color: colorScheme.surface.withValues(alpha: 0.92),
                        width: 6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isCapturing
                        ? Padding(
                            padding: const EdgeInsets.all(22),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: colorScheme.surface,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraTargetChip extends StatelessWidget {
  const CameraTargetChip({
    super.key,
    required this.value,
    this.onTap,
    required this.icon,
  });

  final String value;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
