import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spotlight_step.dart';
import 'spotlight_tour.dart';

class SpotlightTourController {
  /// Tracks the globally active spotlight tour to prevent multiple
  /// overlapping overlays from being shown at the same time.
  static SpotlightTourController? _activeController;

  final String tourId;
  final List<SpotlightStep> _steps = [];

  List<SpotlightStep> get steps => List.unmodifiable(_steps);

  SpotlightTourController({
    required this.tourId,
    List<SpotlightStep> steps = const [],
  }) {
    _steps.addAll(steps);
  }

  OverlayEntry? _overlayEntry;

  /// ValueNotifier to drive the current step index in the overlay.
  final ValueNotifier<int> currentStepNotifier = ValueNotifier(0);

  /// Starts the tour if it hasn't been completed yet.
  Future<void> start(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'onboarding_tour_completed_$tourId';
    final hasCompleted = prefs.getBool(key) ?? false;

    if (hasCompleted) {
      return;
    }
    // Ensure we are ensuring the widget is mounted or context is valid if possible,
    // though start() is usually called from valid context usage.
    if (!context.mounted) return;

    // Wait until all spotlight targets are actually laid out so that
    // their GlobalKeys have a valid context and size before we
    // compute highlight rectangles in the overlay.
    await _waitForTargetsToBeReady();

    if (!context.mounted) return;

    _showOverlay(context);
  }

  /// Forces the tour to start ignoring the completion status (useful for debugging or manual triggers)
  void forceStart(BuildContext context) {
    // If another tour is currently active, finish it before starting
    // this one so that we never have overlapping overlays.
    if (_activeController != null && _activeController != this) {
      _activeController!._finish();
    }
    _showOverlay(context);
  }

  /// Waits until all step target widgets have a mounted context and a
  /// valid RenderBox with size. This prevents starting the tour while
  /// the layout tree is still building, which would otherwise cause
  /// null contexts and zero-sized highlight rects.
  Future<void> _waitForTargetsToBeReady() async {
    const maxAttempts = 20;
    var attempt = 0;

    while (attempt < maxAttempts) {
      final allReady = _steps.every((step) {
        final context = step.targetKey.currentContext;
        if (context == null) return false;

        final renderObject = context.findRenderObject();
        if (renderObject is! RenderBox) return false;

        return renderObject.attached && renderObject.hasSize;
      });

      if (allReady) {
        return;
      }

      attempt++;
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) return; // Already showing

    // Do not start if there are no steps registered.
    if (_steps.isEmpty) return;

    // If another controller is already active and it's not this one,
    // skip starting to avoid multiple spotlight overlays.
    if (_activeController != null && _activeController != this) {
      return;
    }

    currentStepNotifier.value = 0;

    _overlayEntry = OverlayEntry(builder: (ctx) {
      return SpotlightTourOverlay(
        controller: this,
        steps: steps,
      );
    });

    _activeController = this;
    Overlay.of(context).insert(_overlayEntry!);
  }

  void next() {
    if (currentStepNotifier.value < _steps.length - 1) {
      currentStepNotifier.value++;
    } else {
      skip(); // Finish logic is the same
    }
  }

  void skip() {
    _finish();
  }

  Future<void> _finish() async {
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (_activeController == this) {
      _activeController = null;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_tour_completed_$tourId', true);
  }

  void registerStep(SpotlightStep step) {
    final existingIndex = _steps.indexWhere((s) => s.id == step.id);
    if (existingIndex >= 0) {
      _steps[existingIndex] = step;
    } else {
      _steps.add(step);
    }
  }

  void unregisterStep(String id) {
    _steps.removeWhere((s) => s.id == id);
  }
}
