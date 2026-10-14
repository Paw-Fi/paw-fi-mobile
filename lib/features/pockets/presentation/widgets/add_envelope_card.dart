import 'package:flutter/material.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/mesh_gradient_painter.dart';

class AddEnvelopeCard extends StatelessWidget {
  const AddEnvelopeCard({
    super.key,
    required this.colorScheme,
    required this.onTap,
    required this.isEnabled,
    this.onDisabledTap,
  });

  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final bool isEnabled;
  final VoidCallback? onDisabledTap;

  @override
  Widget build(BuildContext context) {
    final title =
        isEnabled ? context.l10n.newPocketTitle : context.l10n.monthlyBudget;
    final subtitle =
        isEnabled ? null : context.l10n.pleaseSetMonthlyBudgetFirst;
    final palette = colorScheme.pocketPalette(colorScheme.primary);

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: subtitle == null ? title : '$title. $subtitle',
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.0),
        child: InkWell(
          onTap: isEnabled ? onTap : onDisabledTap,
          borderRadius: BorderRadius.circular(32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isEnabled
                  ? palette.surface.base
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isEnabled
                    ? palette.border
                    : colorScheme.outline.withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow: isEnabled ? palette.cardShadows : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    opacity: isEnabled ? 1 : 0,
                    child: CustomPaint(
                      painter: MeshGradientPainter(
                        surface: palette.surface,
                        shape: const RoundedRectClipper(32),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isEnabled ? null : colorScheme.surface,
                          gradient:
                              isEnabled ? palette.iconSurfaceGradient : null,
                          border: Border.all(
                            color: isEnabled
                                ? palette.iconRim
                                : colorScheme.outline.withValues(alpha: 0.2),
                          ),
                          boxShadow: isEnabled ? palette.iconShadows : null,
                        ),
                        child: Icon(
                          isEnabled
                              ? Icons.add_rounded
                              : Icons.account_balance_wallet_outlined,
                          color: isEnabled
                              ? palette.iconForeground
                              : colorScheme.mutedForeground,
                          size: 29,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color:
                              isEnabled ? palette.title : colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: subtitle == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.25,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
