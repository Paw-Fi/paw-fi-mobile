import 'package:flutter/material.dart';

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
  final Color menuBackgroundColor;
  final Color drawerShadowsBackgroundColor;
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
    this.menuBackgroundColor = Colors.grey,
    this.drawerShadowsBackgroundColor = Colors.black12,
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
    _animationController.value += delta;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_animationController.value > 0.5 || details.primaryVelocity! > 500) {
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: widget.menuBackgroundColor,
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
                      color: widget.drawerShadowsBackgroundColor,
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
                          color: Colors.white, // Will be covered by child
                          borderRadius: BorderRadius.circular(radiusValue),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(0.05 * slideValue),
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
                            color: Colors.transparent,
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
            width: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}
