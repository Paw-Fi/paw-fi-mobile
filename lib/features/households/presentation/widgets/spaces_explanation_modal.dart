import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/theme/app_theme.dart';

class SpacesExplanationModal extends StatelessWidget {
  const SpacesExplanationModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "How Spaces Work", // TODO: Localize
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.mutedForeground,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            colorScheme.mutedForeground.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Introduction
                      Text(
                        "Spaces help you organize your financial life by separating different contexts.", // TODO: Localize
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.mutedForeground,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Personal Space Section
                      _buildSection(
                        context,
                        title: "Personal Space", // TODO: Localize
                        description:
                            "A private space unique to you. Use it to separate specific transactions from your main account or track personal goals in isolation.", // TODO: Localize
                        imageUrl:
                            "https://placehold.co/600x300/4F46E5/FFFFFF.png?text=Personal+Space",
                        icon: Icons.person_rounded,
                        iconColor: Colors.blueAccent,
                      ),

                      const SizedBox(height: 24),

                      // Shared Space Section
                      _buildSection(
                        context,
                        title: "Shared Space", // TODO: Localize
                        description:
                            "Collaborate with others. Create budgets together, split bills seamlessly, and share financial information with group members.", // TODO: Localize
                        imageUrl:
                            "https://placehold.co/600x300/EC4899/FFFFFF.png?text=Shared+Space",
                        icon: Icons.groups_rounded,
                        iconColor: Colors.pinkAccent,
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: AdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: "Got it", // TODO: Localize
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String description,
    required String imageUrl,
    required IconData icon,
    required Color iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            imageUrl,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 140,
                color: colorScheme.muted.withValues(alpha: 0.3),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback if network image fails (or usually for offline dev)
              return Container(
                height: 140,
                decoration: BoxDecoration(
                  color: colorScheme.muted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: colorScheme.border.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_rounded,
                          color: colorScheme.mutedForeground),
                      const SizedBox(height: 8),
                      Text("Image placeholder",
                          style: TextStyle(
                              color: colorScheme.mutedForeground,
                              fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.mutedForeground,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
