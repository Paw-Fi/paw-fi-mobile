import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/shared/widgets/moneko_avatar.dart';

class DashboardSpaceCard extends StatelessWidget {
  final String spaceName;
  final double income;
  final double expense;
  final String currency;
  final String? coverImageUrl;
  final VoidCallback? onTap;

  const DashboardSpaceCard({
    super.key,
    required this.spaceName,
    required this.income,
    required this.expense,
    required this.currency,
    this.coverImageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balance = income - expense;
    final formatter = NumberFormat.compactSimpleCurrency(name: currency);

    // Gradient based on space name hash to have varied colors
    final colors = _getGradientColors(spaceName);

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Banner / Physical Card Look
              Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle pattern overlay
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: CustomPaint(
                          painter: _WavePainter(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              spaceName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (coverImageUrl != null)
                            MonekoAvatar.network(
                              size: 28,
                              fallbackIcon: Icons.workspaces_rounded,
                              imageUrl: coverImageUrl!,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspaces_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content Area
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatter.format(balance),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            context,
                            context.l10n.income,
                            income,
                            Icons.arrow_downward_rounded,
                            colorScheme.success,
                            formatter,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: colorScheme.border.withValues(alpha: 0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        Expanded(
                          child: _buildMiniStat(
                            context,
                            context.l10n.expense,
                            expense,
                            Icons.arrow_upward_rounded,
                            colorScheme.error,
                            formatter,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color,
    NumberFormat formatter,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatter.format(amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Color> _getGradientColors(String name) {
    final hash = name.hashCode;
    final palettes = [
      [const Color(0xFF00C6FF), const Color(0xFF0072FF)], // Deep blue
      [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Green
      [const Color(0xFFF2994A), const Color(0xFFF2C94C)], // Orange
      [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)], // Purple
      [const Color(0xFFFC466B), const Color(0xFF3F5EFB)], // Pink/Blue
      [const Color(0xFFFF416C), const Color(0xFFFF4B2B)], // Red/Orange
    ];
    return palettes[hash.abs() % palettes.length];
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.7,
          size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.3, size.width, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
