import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:chewie/chewie.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:moneko/shared/widgets/modal_sheet_handle.dart';
import 'package:video_player/video_player.dart';

class WalletSyncSetupSheet extends StatelessWidget {
  final VoidCallback onFinish;
  final bool isSyncing;

  const WalletSyncSetupSheet({
    super.key,
    required this.onFinish,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final safeAreaLimit = mediaQuery.size.height -
              mediaQuery.padding.top -
              mediaQuery.padding.bottom -
              30;
          final maxHeight = safeAreaLimit < constraints.maxHeight
              ? safeAreaLimit
              : constraints.maxHeight;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.sheetBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Sheet Drag Handle
                  const ModalSheetHandle(),
                  _buildHeader(context, colorScheme),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        0,
                        24,
                        mediaQuery.padding.bottom + 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStep(
                            context: context,
                            step: 1,
                            title: l10n.openTheShortcutsApp,
                            description:
                                l10n.openShortcutsAndTapTheAutomationsTabAtTheBottom,
                            action: SizedBox(
                              height: 48,
                              child: PrimaryAdaptiveButton(
                                onPressed: isSyncing ? null : onFinish,
                                child: isSyncing
                                    ? const CircularProgressIndicator.adaptive()
                                    : Text(
                                        l10n.openShortcuts,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          _buildStep(
                            context: context,
                            step: 2,
                            title: l10n.createAPersonalAutomation,
                            description:
                                l10n.tapPlusChooseWalletAndTapNextToContinue,
                          ),
                          _buildStep(
                            context: context,
                            step: 3,
                            title: l10n.addMonekoAction,
                            description:
                                l10n.tapNewBlankAutomationSearchMonekoAndSelectCaptureWalletTransaction,
                          ),
                          _buildStep(
                            context: context,
                            step: 4,
                            title: l10n.mapAmountFromShortcutInput,
                            description:
                                l10n.tapAmountChooseSelectVariableAndPickShortcutInputTapTheTokenAgainToSelectAmount,
                          ),
                          _buildStep(
                            context: context,
                            step: 5,
                            title: l10n.mapMerchantFromShortcutInput,
                            description:
                                l10n.tapMerchantChooseSelectVariableAndPickShortcutInputTapTheTokenAgainToSelectMerchant,
                          ),
                          _buildStep(
                            context: context,
                            step: 6,
                            title: l10n.saveAndReopen,
                            description:
                                l10n.tapTheCheckIconTopRightToSaveThenTapTheAutomationYouJustCreatedToEditIt,
                          ),
                          _buildStep(
                            context: context,
                            step: 7,
                            title: l10n.enableRunImmediately,
                            description:
                                l10n.selectRunImmediatelySoTransactionsLogAutomaticallyWithoutNeedingConfirmation,
                          ),
                          const SizedBox(height: 16),
                          _TutorialVideoButton(onPressed: () {
                            _showTutorialVideo(context);
                          }),
                          const SizedBox(height: 12),
                          _buildFooter(context, colorScheme),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showTutorialVideo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return const _TutorialVideoModal(
          assetPath: 'lib/assets/images/wallet_sync/apple-shortcuts-setup.mp4',
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.setUpApplePayIntegration,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.followTheseStepsInTheShortcutsApp,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: colorScheme.foreground, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required BuildContext context,
    required int step,
    required String title,
    required String description,
    Widget? action,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.sheetElementBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                MarkdownBlock(
                  data: description,
                  config: MarkdownConfig(
                    configs: [
                      PConfig(
                        textStyle: TextStyle(
                          fontSize: 13,
                          color: colorScheme.mutedForeground,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ColorScheme colorScheme) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_rounded, size: 14, color: colorScheme.mutedForeground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n
                .yourCredentialsAreStoredSecurelyInTheIosKeychainAndOnlyUsedToAuthenticateWithYourMonekoAccountMonekoNeverAccessesYourBankCardOrWalletDataDirectly,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.mutedForeground,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _TutorialVideoButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _TutorialVideoButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: scheme.primary,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.play_circle_fill_rounded),
      label: Text(
        l10n.watchTutorialVideo,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TutorialVideoModal extends StatefulWidget {
  final String assetPath;

  const _TutorialVideoModal({required this.assetPath});

  @override
  State<_TutorialVideoModal> createState() => _TutorialVideoModalState();
}

class _TutorialVideoModalState extends State<_TutorialVideoModal> {
  late final VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        if (!mounted) return;
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: false,
          allowMuting: true,
          allowFullScreen: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
            handleColor: Theme.of(context).colorScheme.primary,
            bufferedColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
        );
        setState(() {});
      });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final size = MediaQuery.of(context).size;
    return SizedBox(
      height: size.height,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: padding.bottom + 24,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: _chewieController != null &&
                        _chewieController!.videoPlayerController.value.isInitialized
                    ? Chewie(controller: _chewieController!)
                    : const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
