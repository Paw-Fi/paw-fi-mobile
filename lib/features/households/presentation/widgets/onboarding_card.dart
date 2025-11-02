import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

/// Onboarding flashcard component for household feature education
class OnboardingCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String body;
  final Widget? visual;

  const OnboardingCard({
    super.key,
    required this.imagePath,
    required this.title,
    required this.body,
    this.visual,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image icon with gradient background
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.1),
                  colorScheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Body text
          Flexible(
            child: Text(
              body,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.mutedForeground,
                height: 1.5,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          if (visual != null) ...[
            const SizedBox(height: 24),
            visual!,
          ],
        ],
      ),
    );
  }
}

/// Page indicator dots for onboarding carousel
class PageIndicator extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const PageIndicator({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: currentPage == index ? 32 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: currentPage == index
                ? colorScheme.primary
                : colorScheme.muted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
