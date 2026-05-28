import 'dart:async';
import 'dart:ui';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
    final initialSelection = resolveInitialAiInputTargetSelection(
      ref,
      initialTarget: widget.initialTarget,
    );
    _selectedAccountType = initialSelection.accountType;
    _selectedHouseholdId = initialSelection.householdId;
    _selectedWalletId = initialSelection.walletId;
    _hasManuallySelectedWallet = initialSelection.hasManuallySelectedWallet;
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
    final defaultId = resolveAiInputTargetDefaultWalletId(wallets);
    if (defaultId != null) {
      for (final wallet in wallets) {
        if (wallet.id == defaultId) return wallet.name;
      }
    }
    return wallets.first.name;
  }

  String? _savedWalletId() {
    return resolveAiInputTargetSavedWalletId(
      ref,
      accountType: _selectedAccountType,
      householdId: _selectedHouseholdId,
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
      return resolveAiInputTargetWalletId(
        ref,
        accountType: _selectedAccountType,
        householdId: _selectedHouseholdId,
        wallets: wallets,
        selectedWalletId: _hasManuallySelectedWallet ? currentId : null,
      );
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
    return buildAiInputTargetFromSelection(
      ref,
      accountType: _selectedAccountType,
      householdId: _selectedHouseholdId,
      selectedWalletId: _selectedWalletId,
      households: households,
      wallets: wallets,
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

  Widget _buildCameraStage(
    BuildContext context,
    CameraController? controller,
    bool isReady,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isInitializing) {
      return Center(
        child: CircularProgressIndicator(
          color: colorScheme.primary,
        ),
      );
    }
    if (_cameraError != null || !isReady || controller == null) {
      return Center(
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
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewAspectRatio = 1 / controller.value.aspectRatio;
        final previewHeight = constraints.maxWidth / previewAspectRatio;
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: constraints.maxWidth,
              height: previewHeight,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
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
    const shutterOuterColor = Color(0xB82F2F33);
    const shutterBorderColor = Color(0xFF5A5B60);
    const shutterInnerColor = Color(0xFFF5F5F5);
    const shutterProgressColor = Color(0xFF101114);

    return Scaffold(
      backgroundColor: colorScheme.scrim,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewPadding = MediaQuery.paddingOf(context);
          final topHeight = constraints.maxHeight * 0.14;
          final cameraHeight = constraints.maxHeight * 0.64;
          final bottomHeight = constraints.maxHeight - topHeight - cameraHeight;

          return Column(
            children: [
              SizedBox(
                height: topHeight,
                child: Container(
                  width: double.infinity,
                  color: colorScheme.scrim.withValues(alpha: 0.98),
                  padding: EdgeInsets.only(
                    top: viewPadding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 8,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: _CameraGlassButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icons.close_rounded,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: cameraHeight,
                width: double.infinity,
                child: _buildCameraStage(context, controller, isReady),
              ),
              SizedBox(
                height: bottomHeight,
                child: Container(
                  width: double.infinity,
                  color: colorScheme.scrim.withValues(alpha: 0.98),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    viewPadding.bottom + 14,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                            const SizedBox(width: 10),
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
                                        icon: Icons
                                            .account_balance_wallet_rounded,
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
                      GestureDetector(
                        onTap: isReady && !_isCapturing
                            ? () => _capture(households, wallets)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          width: _isCapturing ? 72 : 82,
                          height: _isCapturing ? 72 : 82,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: shutterOuterColor,
                            border: Border.all(
                              color: shutterBorderColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.shadow.withValues(alpha: 0.26),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: shutterInnerColor,
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: shutterProgressColor,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CameraGlassButton extends StatelessWidget {
  const _CameraGlassButton({
    required this.onPressed,
    required this.icon,
  });

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.24),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            color: Colors.white,
            iconSize: 24,
            constraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 46,
            ),
          ),
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
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.32),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 21,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.84),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.64),
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
