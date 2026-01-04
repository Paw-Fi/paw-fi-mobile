import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/theme/app_theme.dart';

/// A wrapper around [AdaptiveTabBarView] that ensures correct text styling
/// in both light and dark modes, specifically fixing visibility issues
/// for unselected tabs in dark mode on iOS.
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
    final colorScheme = Theme.of(context).colorScheme;

    if (PlatformInfo.isIOS) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth = constraints.maxWidth / widget.tabs.length;

                return CupertinoSlidingSegmentedControl<int>(
                  groupValue: _currentIndex,
                  backgroundColor: colorScheme.muted,
                  thumbColor: colorScheme.tabThumb,
                  children: {
                    for (int i = 0; i < widget.tabs.length; i++)
                      i: SizedBox(
                        width: segmentWidth,
                        child: Center(
                          child: Text(
                            widget.tabs[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: i == _currentIndex
                                  ? colorScheme.tabSelectedForeground
                                  : colorScheme.tabUnselectedForeground,
                            ),
                          ),
                        ),
                      ),
                  },
                  onValueChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _onSegmentChanged(value);
                  },
                );
              },
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

    return DefaultTextStyle.merge(
      style: TextStyle(
        color: colorScheme.tabDefaultForeground,
      ),
      child: AdaptiveTabBarView(
        tabs: widget.tabs,
        children: widget.children,
        onTabChanged: widget.onTabChanged,
        unselectedColor: colorScheme.tabUnselectedForeground,
      ),
    );
  }
}
