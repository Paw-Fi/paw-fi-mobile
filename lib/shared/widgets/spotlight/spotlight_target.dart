import 'package:flutter/widgets.dart';

import 'spotlight_controller.dart';
import 'spotlight_step.dart';

class SpotlightTarget extends StatefulWidget {
  const SpotlightTarget({
    super.key,
    required this.controller,
    required this.id,
    required this.title,
    required this.description,
    this.placement = SpotlightPlacement.bottom,
    this.padding = 4,
    this.borderRadius = 8,
    required this.child,
  });

  final SpotlightTourController controller;
  final String id;
  final String title;
  final String description;
  final SpotlightPlacement placement;
  final double padding;
  final double borderRadius;
  final Widget child;

  @override
  State<SpotlightTarget> createState() => _SpotlightTargetState();
}

class _SpotlightTargetState extends State<SpotlightTarget> {
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _registerStep();
  }

  @override
  void didUpdateWidget(covariant SpotlightTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.title != widget.title ||
        oldWidget.description != widget.description ||
        oldWidget.placement != widget.placement) {
      _registerStep();
    }
  }

  void _registerStep() {
    widget.controller.registerStep(
      SpotlightStep(
        id: widget.id,
        targetKey: _targetKey,
        title: widget.title,
        description: widget.description,
        placement: widget.placement,
        padding: widget.padding,
        borderRadius: widget.borderRadius,
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.unregisterStep(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _targetKey,
      child: widget.child,
    );
  }
}
