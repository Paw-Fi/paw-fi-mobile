import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:chewie/chewie.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
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
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHandle(colorScheme),
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
                            title: 'Open the Shortcuts app',
                            description:
                                'Open Shortcuts and tap the **Automations** tab at the bottom.',
                            action: SizedBox(
                              height: 48,
                              child: PrimaryAdaptiveButton(
                                onPressed: isSyncing ? null : onFinish,
                                child: isSyncing
                                    ? const CircularProgressIndicator.adaptive()
                                    : const Text(
                                        'Open Shortcuts',
                                        style: TextStyle(
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
                            title: 'Create a Personal Automation',
                            description:
                                'Tap **+**, choose **Wallet**, and tap **Next** to continue.',
                          ),
                          _buildStep(
                            context: context,
                            step: 3,
                            title: 'Add Moneko Action',
                            description:
                                'Tap **New Blank Automation**, search **Moneko**, and select **"Capture Wallet Transaction"**.',
                          ),
                          _buildStep(
                            context: context,
                            step: 4,
                            title: 'Map Amount from Shortcut Input',
                            description:
                                'Tap **Amount**, choose **Select Variable**, and pick **Shortcut Input**. Tap the token again to select **Amount**.',
                          ),
                          _buildStep(
                            context: context,
                            step: 5,
                            title: 'Map Merchant from Shortcut Input',
                            description:
                                'Tap **Merchant**, choose **Select Variable**, and pick **Shortcut Input**. Tap the token again to select **Merchant**.',
                          ),
                          _buildStep(
                            context: context,
                            step: 6,
                            title: 'Save and Re-open',
                            description:
                                'Tap the **Check icon** (top right) to save. Then, tap the automation you just created to edit it.',
                          ),
                          _buildStep(
                            context: context,
                            step: 7,
                            title: 'Enable Run Immediately',
                            description:
                                'Select **Run Immediately** so transactions log automatically without needing confirmation.',
                          ),
                          const SizedBox(height: 16),
                          _TutorialVideoButton(onPressed: () {
                            _showTutorialVideo(context);
                          }),
                          const SizedBox(height: 12),
                          _buildFooter(colorScheme),
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

  Widget _buildHandle(ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set Up Apple Pay Integration',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.foreground,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Follow these steps in the Shortcuts app.',
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
    const cardColor = Color(0xFFF4F4F4);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
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

  Widget _buildFooter(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_rounded, size: 14, color: colorScheme.mutedForeground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your credentials are stored securely in the iOS Keychain and only used to authenticate with your Moneko account. Moneko never accesses your bank, card, or wallet data directly.',
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
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        foregroundColor: scheme.primary,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.play_circle_fill_rounded),
      label: const Text(
        'Watch tutorial video',
        style: TextStyle(fontWeight: FontWeight.w600),
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
