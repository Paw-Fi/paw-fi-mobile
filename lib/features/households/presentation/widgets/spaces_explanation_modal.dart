import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

class SpacesExplanationModal extends StatelessWidget {
  const SpacesExplanationModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surface.withValues(alpha: 0.7)
                    : colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Bar / Header
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 24, right: 16, top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.chooseYourSpace, // Friendly title
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Close button
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: colorScheme.mutedForeground,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                colorScheme.onSurface.withValues(alpha: 0.05),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.spacesHelpOrganize,
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.mutedForeground,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Private Space Card
                          _buildSpaceCard(
                            context,
                            title: context.l10n.privateSpace,
                            subtitle: context.l10n.yourPersonalVault,
                            description:
                                context.l10n.privateSpaceDescription,
                            imagePath:
                                "lib/assets/images/household/private_space_illustration.png",
                            accentColor: const Color(0xFF6366F1), // Indigo
                            isDark: isDark,
                          ),

                          const SizedBox(height: 20),

                          // Shared Space Card
                          _buildSpaceCard(
                            context,
                            title: context.l10n.sharedSpace,
                            subtitle: context.l10n.betterTogether,
                            description:
                                context.l10n.sharedSpaceDescription2,
                            imagePath:
                                "lib/assets/images/household/shared_space_illustration.png",
                            accentColor: const Color(0xFFEC4899), // Pink
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.border.withValues(alpha: 0.1),
                        ),
                      ),
                      color: colorScheme.surface.withValues(alpha: 0.5),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: PrimaryAdaptiveButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.l10n.gotIt,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpaceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required String imagePath,
    required Color accentColor,
    required bool isDark,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.card.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Header
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accentColor.withValues(alpha: 0.1),
                    accentColor.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.6),
                errorBuilder: (context, error, stackTrace) => Container(
                  color: accentColor.withValues(alpha: 0.1),
                  child: Center(
                    child: Icon(
                      Icons.home_outlined,
                      size: 48,
                      color: accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        subtitle.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.mutedForeground,
                    height: 1.5,
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
