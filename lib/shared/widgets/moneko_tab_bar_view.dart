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
    this.tabBarKey,
  });

  final List<String> tabs;
  final List<Widget> children;
  final ValueChanged<int>? onTabChanged;
  final Key? tabBarKey;

  @override
  State<MonekoTabBarView> createState() => _MonekoTabBarViewState();
}

class MonekoSegmentedControl extends StatelessWidget {
  const MonekoSegmentedControl({
    super.key,
    required this.labels,
    this.icons,
    required this.selectedIndex,
    required this.onValueChanged,
    this.height = 40,
    this.iconSize,
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onValueChanged;
  final double height;
  final double? iconSize;

  bool get _usesIcons => icons != null && icons!.isNotEmpty;

  int get _segmentCount => _usesIcons ? icons!.length : labels.length;

  @override
  Widget build(BuildContext context) {
    final colorScheme = _resolveColorScheme(context);

    if (PlatformInfo.isIOS) {
      return _buildCupertinoSegmentedControl(colorScheme);
    }

    return _buildAndroidSegmentedControl(colorScheme);
  }

  ColorScheme _resolveColorScheme(BuildContext context) {
    return Theme.of(context).colorScheme;
  }

  Widget _buildCupertinoSegmentedControl(ColorScheme colorScheme) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_segmentCount == 0) {
            return const SizedBox.shrink();
          }

          final segmentWidth = constraints.maxWidth / _segmentCount;

          return CupertinoSlidingSegmentedControl<int>(
            groupValue: selectedIndex,
            backgroundColor: colorScheme.muted,
            thumbColor: colorScheme.tabThumb,
            children: {
              for (int i = 0; i < _segmentCount; i++)
                i: SizedBox(
                  width: segmentWidth,
                  child: Center(
                    child: _buildSegmentContent(
                      colorScheme,
                      i,
                      isSelected: i == selectedIndex,
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

  Widget _buildAndroidSegmentedControl(ColorScheme colorScheme) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_segmentCount == 0) {
            return const SizedBox.shrink();
          }

          final segmentWidth = constraints.maxWidth / _segmentCount;
          final thumbLeft =
              segmentWidth * selectedIndex.clamp(0, _segmentCount - 1);

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
                    for (int i = 0; i < _segmentCount; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(height / 2),
                          onTap: () => onValueChanged(i),
                          child: Center(
                            child: _buildSegmentContent(
                              colorScheme,
                              i,
                              isSelected: i == selectedIndex,
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

  Widget _buildSegmentContent(
    ColorScheme colorScheme,
    int index, {
    required bool isSelected,
  }) {
    final color = isSelected
        ? colorScheme.tabSelectedForeground
        : colorScheme.tabUnselectedForeground;

    if (_usesIcons) {
      return Icon(
        icons![index],
        size: iconSize ?? 18,
        color: color,
      );
    }

    return Text(
      labels[index],
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
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
          key: widget.tabBarKey,
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
