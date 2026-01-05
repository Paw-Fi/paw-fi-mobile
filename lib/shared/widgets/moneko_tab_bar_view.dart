import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// A segmented tab view that keeps styling consistent across platforms.
class MonekoTabBarView extends StatefulWidget {
  const MonekoTabBarView({
    super.key,
    required this.tabs,
    required this.children,
    this.onTabChanged,
  });

  final List<String> tabs;
  final List<Widget> children;
  final ValueChanged<int>? onTabChanged;

  @override
  State<MonekoTabBarView> createState() => _MonekoTabBarViewState();
}

class MonekoSegmentedControl extends StatelessWidget {
  const MonekoSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onValueChanged,
    this.height = 40,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onValueChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (PlatformInfo.isIOS && !PlatformInfo.isIOS26OrHigher()) {
      return SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth =
                labels.isEmpty ? 0.0 : constraints.maxWidth / labels.length;

            return CupertinoSlidingSegmentedControl<int>(
              groupValue: selectedIndex,
              backgroundColor: colorScheme.muted,
              thumbColor: colorScheme.tabThumb,
              children: {
                for (int i = 0; i < labels.length; i++)
                  i: SizedBox(
                    width: segmentWidth,
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: i == selectedIndex
                              ? colorScheme.tabSelectedForeground
                              : colorScheme.tabUnselectedForeground,
                        ),
                      ),
                    ),
                  ),
              },
              onValueChanged: (value) {
                if (value == null) return;
                onValueChanged(value);
              },
            );
          },
        ),
      );
    }

    if (PlatformInfo.isAndroid) {
      return SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (labels.isEmpty) {
              return const SizedBox.shrink();
            }

            final segmentWidth = constraints.maxWidth / labels.length;
            final thumbLeft = segmentWidth *
                selectedIndex.clamp(0, labels.length - 1);

            return ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: Stack(
                children: [
                  Container(
                    color: colorScheme.muted,
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    left: thumbLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: segmentWidth,
                      decoration: BoxDecoration(
                        color: colorScheme.tabThumb,
                        borderRadius: BorderRadius.circular(height / 2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (int i = 0; i < labels.length; i++)
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(height / 2),
                            onTap: () => onValueChanged(i),
                            child: Center(
                              child: Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: i == selectedIndex
                                      ? colorScheme.tabSelectedForeground
                                      : colorScheme.tabUnselectedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return SizedBox(
      height: height,
      child: AdaptiveSegmentedControl(
        labels: labels,
        selectedIndex: selectedIndex,
        onValueChanged: onValueChanged,
        height: height,
      ),
    );
  }
}

class _MonekoTabBarViewState extends State<MonekoTabBarView> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSegmentChanged(int index) {
    if (index == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    widget.onTabChanged?.call(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: MonekoSegmentedControl(
            labels: widget.tabs,
            selectedIndex: _currentIndex,
            onValueChanged: _onSegmentChanged,
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: widget.children,
          ),
        ),
      ],
    );
  }
}
