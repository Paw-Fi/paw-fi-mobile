import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/core.dart';
import 'package:moneko/features/households/presentation/providers/selected_household_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/features/home/presentation/state/home_filter_provider.dart';
import 'package:moneko/features/households/domain/entities/household.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart';
import 'package:moneko/features/households/presentation/providers/household_scope_provider.dart';
import 'package:moneko/features/home/presentation/utils/ai_input_wallet_filter.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_providers.dart';

import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';

import 'package:moneko/features/home/presentation/widgets/ai_space_label_utils.dart';
import 'package:moneko/features/home/presentation/widgets/ai_input_target.dart';

const int _minimumAudioRecordingMs = 1000;
const double _silentRecordingPeakDb = -160.0;
const double _minimumVoicePeakDb = -55.0;

typedef AiTextInputSubmit = Future<void> Function(
  String text,
  AiInputTarget target,
);

typedef AiAudioInputSubmit = Future<void> Function(
  Uint8List audioBytes,
  String contentType,
  AiInputTarget target,
);

Future<void> showTextInputDrawer(
  BuildContext parentContext,
  AiTextInputSubmit onSubmit, {
  AiAudioInputSubmit? onSubmitAudio,
}) {
  final colorScheme = Theme.of(parentContext).colorScheme;

  return showModalBottomSheet<void>(
    context: parentContext,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    enableDrag: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: colorScheme.sheetBackground,
    builder: (modalContext) => _TextInputContent(
      parentContext: parentContext,
      colorScheme: colorScheme,
      onSubmit: onSubmit,
      onSubmitAudio: onSubmitAudio,
    ),
  );
}

class _TextInputContent extends ConsumerStatefulWidget {
  final BuildContext parentContext;
  final ColorScheme colorScheme;
  final AiTextInputSubmit onSubmit;
  final AiAudioInputSubmit? onSubmitAudio;

  const _TextInputContent({
    required this.parentContext,
    required this.colorScheme,
    required this.onSubmit,
    this.onSubmitAudio,
  });

  @override
  ConsumerState<_TextInputContent> createState() => _TextInputContentState();
}

class _TextInputContentState extends ConsumerState<_TextInputContent>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _mockTranscribingTimer;
  Timer? _recordingAmplitudeTimer;
  final AudioRecorder _recorder = AudioRecorder();
  final FocusNode _textFocusNode = FocusNode();
  late final TextEditingController _textController;
  double? _keyboardInsetOnRecordStart;
  double _recordingPeakDb = _silentRecordingPeakDb;
  ActiveWalletType _selectedAccountType = ActiveWalletType.personal;
  String? _selectedHouseholdId;
  String? _selectedWalletId;
  bool _hasManuallySelectedWallet = false;

  // Animation for the mic button scale
  late AnimationController _micScaleController;
  late Animation<double> _micScaleAnimation;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
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
    _micScaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micScaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _micScaleController.dispose();
    _mockTranscribingTimer?.cancel();
    _recordingAmplitudeTimer?.cancel();
    _recorder.dispose();
    _textFocusNode.dispose();
    super.dispose();
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

  String? _savedWalletId() {
    return ref.read(sharedPreferencesProvider).getString(
          aiInputTargetWalletPreferenceKey(
            accountType: _selectedAccountType,
            householdId: _selectedHouseholdId,
            currency: ref.read(selectedHomeCurrencyCodeProvider),
          ),
        );
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

  AiInputTarget _targetFromSelection(
    List<Household> households,
    List<WalletEntity> wallets,
  ) {
    final isPortfolio = _selectedAccountType == ActiveWalletType.portfolio ||
        households.any(
          (household) =>
              household.id == _selectedHouseholdId && household.isPortfolio,
        );
    final effectiveWalletId =
        _selectedWalletId ?? _savedWalletId() ?? _defaultWalletId(wallets);
    WalletEntity? selectedWallet;
    for (final wallet in wallets) {
      if (wallet.id == effectiveWalletId) {
        selectedWallet = wallet;
        break;
      }
    }
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

  List<WalletEntity> _currentWallets() {
    final wallets = ref
            .read(walletsByHouseholdIdProvider(
              _selectedAccountType == ActiveWalletType.personal
                  ? null
                  : _selectedHouseholdId,
            ))
            .valueOrNull ??
        const <WalletEntity>[];
    return filterAiInputTargetWallets(wallets, ref.read(homeFilterProvider));
  }

  Widget _buildTargetSelector({
    required ColorScheme scheme,
    required List<Household> households,
    required AsyncValue<List<WalletEntity>> walletsAsync,
    required List<WalletEntity> wallets,
  }) {
    final spaceOptions = _spaceOptions(households);
    return Row(
      children: [  
        Expanded(
          child: AdaptivePopupMenuButton.widget(
            child: _TargetPickerPill(
              icon: Icons.grid_view_rounded,
              value: _spaceLabel(households),
            ),
            items: spaceOptions.reversed
                .map(
                  (option) => AdaptivePopupMenuItem(
                    label: option.label,
                    icon: option.accountType == ActiveWalletType.personal
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
              child: _TargetPickerPill(
                icon: Icons.account_balance_wallet_rounded,
                value: walletsAsync.when(
                  data: (_) => _walletLabel(wallets),
                  loading: () => context.l10n.loading,
                  error: (_, __) => context.l10n.tapToSet,
                ),
                isPlaceholder: wallets.isEmpty,
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
    );
  }

  Future<void> _processExpense() async {
    if (_isProcessing) return;

    final text = _textController.text.trim();
    if (text.isEmpty) {
      AppToast.info(widget.parentContext,
          widget.parentContext.l10n.pleaseEnterExpenseDetails);
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    if (mounted) {
      try {
        final households = ref
                .read(userHouseholdsProvider(ref.read(authProvider).uid))
                .valueOrNull ??
            const <Household>[];
        await widget.onSubmit(
          text,
          _targetFromSelection(households, _currentWallets()),
        );
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  Future<void> _onRecordStart() async {
    if (_isProcessing) return;

    HapticFeedback.heavyImpact();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (widget.parentContext.mounted) {
        AppToast.error(
          widget.parentContext,
          widget.parentContext.l10n.failedToAnalyze,
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      final currentInset = MediaQuery.of(context).viewInsets.bottom;
      _keyboardInsetOnRecordStart =
          currentInset > 0 ? currentInset : _keyboardInsetOnRecordStart;
    });
    _micScaleController.forward();

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/moneko_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );
    _startRecordingAmplitudeProbe();
  }

  void _startRecordingAmplitudeProbe() {
    _recordingPeakDb = _silentRecordingPeakDb;
    _recordingAmplitudeTimer?.cancel();
    _recordingAmplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) {
      unawaited(_captureRecordingAmplitude());
    });
  }

  Future<void> _captureRecordingAmplitude() async {
    try {
      final amp = await _recorder.getAmplitude();
      final peak = max(amp.current, amp.max);
      if (peak > _recordingPeakDb) {
        _recordingPeakDb = peak;
      }
    } catch (_) {}
  }

  void _onRecordEnd() async {
    if (_isProcessing) return;

    _micScaleController.reverse();
    final startedAt = _recordingStartTime;
    if (startedAt == null) {
      return;
    }
    _recordingStartTime = null;

    final duration = DateTime.now().difference(startedAt);
    debugPrint(
        '🎙️ Recording finished. Duration: ${duration.inMilliseconds} ms');

    final isTooShort = duration.inMilliseconds < _minimumAudioRecordingMs;
    if (isTooShort) {
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _isRecording = false;
    });

    await _captureRecordingAmplitude();
    _recordingAmplitudeTimer?.cancel();
    final path = await _recorder.stop();
    if (isTooShort) {
      if (widget.parentContext.mounted) {
        AppToast.error(
            widget.parentContext, widget.parentContext.l10n.recordingTooShort);
      }
      if (path != null) {
        final file = File(path);
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      return;
    }

    if (path == null) {
      if (widget.parentContext.mounted) {
        AppToast.error(
            widget.parentContext, widget.parentContext.l10n.recordingFailed);
      }
      return;
    }

    final hasVoiceInput = _recordingPeakDb > _minimumVoicePeakDb;
    if (!hasVoiceInput) {
      if (widget.parentContext.mounted) {
        AppToast.error(
            widget.parentContext, widget.parentContext.l10n.recordingIsEmpty);
      }
      final file = File(path);
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      if (widget.parentContext.mounted) {
        AppToast.error(widget.parentContext,
            widget.parentContext.l10n.recordingFileMissing);
      }
      return;
    }

    final bytes = await file.readAsBytes();
    debugPrint('🎙️ Recording file path: $path');
    debugPrint('🎙️ Recording byte length: ${bytes.length}');
    if (bytes.isEmpty) {
      if (widget.parentContext.mounted) {
        AppToast.error(
            widget.parentContext, widget.parentContext.l10n.recordingIsEmpty);
      }
      return;
    }

    if (widget.onSubmitAudio != null) {
      setState(() {
        _isProcessing = true;
      });
      try {
        final households = ref
                .read(userHouseholdsProvider(ref.read(authProvider).uid))
                .valueOrNull ??
            const <Household>[];
        await widget.onSubmitAudio!(
          bytes,
          'audio/aac',
          _targetFromSelection(households, _currentWallets()),
        );
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.colorScheme;
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
    _syncWalletSelection(wallets);
    final rawBottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottomInset = MediaQuery.of(context).viewPadding.bottom;
    final minimumBottomPadding = max(20.0, safeBottomInset + 12);
    final effectiveBottomInset = _isRecording
        ? (_keyboardInsetOnRecordStart ?? rawBottomInset)
        : rawBottomInset;

    final String dynamicTitle = context.l10n.addEntry;
    final String placeholder = context.l10n.enterExpenseDetails;

    return Container(
      decoration: BoxDecoration(
        color: scheme.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 10,
          bottom: effectiveBottomInset > 0
              ? effectiveBottomInset
              : minimumBottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Sheet Drag Handle
            const ModalSheetHandle(),

            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    dynamicTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Guidance text
            Text(
              context.l10n.describeYourExpense,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                letterSpacing: -0.1,
              ),
            ),

            const SizedBox(height: 16),

            _buildTargetSelector(
              scheme: scheme,
              households: households,
              walletsAsync: walletsAsync,
              wallets: wallets,
            ),

            const SizedBox(height: 16),

            // Content Area (Stack to maintain TextField focus/keyboard stability)
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: scheme.sheetElementBackground.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Stack(
                children: [
                  // TextField always in tree to prevent keyboard dismissal
                  TextField(
                    key: const ValueKey('textField'),
                    controller: _textController,
                    focusNode: _textFocusNode,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: scheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),

                  // Visualizer Overlay
                  if (_isRecording)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.sheetElementBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _RecordingVisualizer(
                          colorScheme: scheme,
                          recorder: _recorder,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: PrimaryAdaptiveButton(
                      onPressed: _isProcessing ? null : _processExpense,
                      child: _isProcessing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    scheme.onPrimary),
                              ),
                            )
                          : Text(
                              dynamicTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTapDown: (_) => _onRecordStart(),
                  onTapUp: (_) => _onRecordEnd(),
                  onTapCancel: () => _onRecordEnd(),
                  child: ScaleTransition(
                    scale: _micScaleAnimation,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? scheme.error
                            : scheme.sheetElementBackground.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording
                              ? scheme.error
                              : scheme.outlineVariant.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                        boxShadow: [
                          if (_isRecording)
                            BoxShadow(
                              color: scheme.error.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isRecording
                            ? scheme.onError
                            : scheme.primary,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RecordingVisualizer extends StatefulWidget {
  final ColorScheme colorScheme;
  final AudioRecorder recorder;

  const _RecordingVisualizer({
    required this.colorScheme,
    required this.recorder,
  });

  @override
  State<_RecordingVisualizer> createState() => _RecordingVisualizerState();
}

class _TargetPickerPill extends StatelessWidget {
  const _TargetPickerPill({
    required this.value,
    required this.icon,
    this.onTap,
    this.isPlaceholder = false,
  });

  final String value;
  final VoidCallback? onTap;
  final IconData icon;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.sheetElementBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
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
                    color: isPlaceholder
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingVisualizerState extends State<_RecordingVisualizer> {
  Timer? _timer;
  // Initialize with small values for a "ready" state
  final List<double> _history = List.filled(15, 0.0);
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    // Update frequency: 50ms for smoother animation (20fps)
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateAmplitude();
    });
  }

  Future<void> _updateAmplitude() async {
    try {
      final amp = await widget.recorder.getAmplitude();
      final currentDb = amp.current;

      // Normalize dBFS (-160 to 0)
      // Lower noise floor to -60dB to catch quieter input
      double normalized;

      // Map a practical voice range (around -60dB..-20dB) into 0..1
      const double minDb = -60.0;
      const double maxDb = -20.0;
      final double clampedDb = currentDb.clamp(minDb, maxDb);
      normalized = (clampedDb - minDb) / (maxDb - minDb);

      if (normalized < 0) normalized = 0;
      if (normalized > 1.0) normalized = 1.0;

      debugPrint('🎙️ Amplitude current: $currentDb, normalized: $normalized');

      if (mounted) {
        setState(() {
          _phase += 0.7;
          for (var i = 0; i < _history.length; i++) {
            final angle = ((_phase + i) / _history.length) * 2 * pi;
            final wave = sin(angle).abs(); // 0..1

            // Silence → almost flat, loud voice → tall moving wave
            final double value = 0.005 + (normalized * wave);
            _history[i] = value.clamp(0.005, 1.0);
          }
        });
      }
    } catch (e) {
      // Ignore errors when recorder is not ready or disposed
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_history.length, (index) {
            // Visualize history from left to right
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutQuad,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 4,
              // Further lower baseline when silent, still within visual bounds
              height: 12 + (_history[index] * 80),
              decoration: BoxDecoration(
                color: widget.colorScheme.primary
                    .withValues(alpha: 0.8 + (_history[index] * 0.2)),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ),
    );
  }
}
