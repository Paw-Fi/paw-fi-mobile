import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';

class AppDrawerController {
  void Function()? open;
  void Function()? close;
  void Function()? toggle;
  ValueNotifier<bool> isOpen = ValueNotifier(false);

  void dispose() {
    isOpen.dispose();
  }
}

class CustomDrawer extends StatefulWidget {
  final Widget menuScreen;
  final Widget mainScreen;
  final AppDrawerController? controller;
  final double slideWidth;
  final double menuScreenWidth;
  final double borderRadius;
  final double angle;
  final Color? menuBackgroundColor;
  final Color? drawerShadowsBackgroundColor;
  final bool showShadow;

  const CustomDrawer({
    super.key,
    required this.menuScreen,
    required this.mainScreen,
    this.controller,
    this.slideWidth = 275.0,
    this.menuScreenWidth = 275.0,
    this.borderRadius = 16.0,
    this.angle = -12.0,
    this.menuBackgroundColor,
    this.drawerShadowsBackgroundColor,
    this.showShadow = false,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _setupAnimations();
    _setupController();
  }

  void _setupAnimations() {
    const curve = Curves.easeOutCubic;

    _slideAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: curve),
    );
  }

  void _setupController() {
    if (widget.controller != null) {
      widget.controller!.open = open;
      widget.controller!.close = close;
      widget.controller!.toggle = toggle;
    }
  }

  void open() {
    _animationController.forward();
    widget.controller?.isOpen.value = true;
  }

  void close() {
    _animationController.reverse();
    widget.controller?.isOpen.value = false;
  }

  void toggle() {
    if (_animationController.isCompleted) {
      close();
    } else {
      open();
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta! / widget.slideWidth;
    _animationController.value =
        (_animationController.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    // High velocity swipes
    if (details.primaryVelocity! > 1400) {
      open();
      return;
    }
    if (details.primaryVelocity! < -400) {
      close();
      return;
    }

    // Drag position threshold
    // > 0.65 means you have to drag 65% of the way to open it (more deliberate)
    // < 0.65 means you only have to drag 35% of the way back to close it (easier)
    if (_animationController.value > 0.65) {
      open();
    } else {
      close();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final menuBackground =
        widget.menuBackgroundColor ?? colorScheme.appBackground;
    final shadowBackground = widget.drawerShadowsBackgroundColor ??
        colorScheme.shadow.withValues(alpha: 0.12);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: menuBackground,
      body: Stack(
        children: [
          // Menu Screen
          SizedBox(
            width: widget.menuScreenWidth,
            height: size.height,
            child: widget.menuScreen,
          ),

          // Shadow
          if (widget.showShadow)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                      (widget.slideWidth - 5) * _slideAnimation.value, 0),
                  child: Container(
                    width: size.width,
                    height: size.height,
                    decoration: BoxDecoration(
                      color: shadowBackground,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                );
              },
            ),

          // Main Screen
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final slideValue = _slideAnimation.value;
              const scaleValue = 1.0; // Force scale to 1.0
              const radiusValue = 0.0; // Force radius to 0.0
              final isClosed = slideValue == 0;

              return Transform.translate(
                offset: Offset(widget.slideWidth * slideValue, 0),
                child: Transform.scale(
                  scale: scaleValue,
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    children: [
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(radiusValue),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow
                                  .withValues(alpha: 0.05 * slideValue),
                              blurRadius: 8,
                              offset: const Offset(-2, 0),
                            ),
                          ],
                        ),
                        child: widget.mainScreen,
                      ),
                      // Overlay to prevent interaction when open and handle close drag
                      if (!isClosed)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: _onDragUpdate,
                          onHorizontalDragEnd: _onDragEnd,
                          onTap: close,
                          child: Container(
                            color: colorScheme.shadow
                                .withValues(alpha: 0.2 * slideValue),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Edge Swipe Detector
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 12,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Container(
                color: colorScheme.surface.withValues(alpha: 0.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
