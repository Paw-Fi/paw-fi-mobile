import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
//import 'package:ios_color_picker/show_ios_color_picker.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/l10n/l10n.dart';

/// A reusable adaptive color picker that automatically selects the appropriate
/// color picker based on the platform or configuration.
class AdaptiveColorPicker {
  /// Shows a color picker dialog adapted for the current platform.
  /// 
  /// [context] - The build context
  /// [startingColor] - The initial color to display
  /// [onColorChanged] - Callback called when color is selected
  /// [label] - Optional label for the color picker title
  static void show({
    required BuildContext context,
    required Color startingColor,
    required ValueChanged<Color> onColorChanged,
    String? label,
  }) {
    // ===========================================
    // COLOR PICKER SELECTION - MANUAL SWITCHING
    // ===========================================
    // 
    // FOR iOS BUILD: Uncomment iOS section, comment Web section
    // FOR WEB BUILD: Comment iOS section, uncomment Web section
    //
    // IMPORTANT: When switching to web, you must also:
    // 1. Remove 'ios_color_picker' from pubspec.yaml dependencies
    // 2. Comment out the ios_color_picker import above
    //

    // ========== iOS COLOR PICKER (USE FOR iOS BUILDS) ==========
    // if (PlatformInfo.isIOS) {
    //   // iOS: Use native iOS color picker
    //   final iosColorPickerController = IOSColorPickerController();
    //   iosColorPickerController.showIOSCustomColorPicker(
    //     startingColor: startingColor,
    //     onColorChanged: onColorChanged,
    //     context: context,
    //   );
    // } else {
    //   // Android/Other: Use flutter_colorpicker
    //   showDialog(
    //     context: context,
    //     builder: (BuildContext context) {
    //       return AlertDialog(
    //         title: Text(label ?? '${context.l10n.selectColor}'),
    //         content: SingleChildScrollView(
    //           child: ColorPicker(
    //             pickerColor: startingColor,
    //             onColorChanged: onColorChanged,
    //           ),
    //         ),
    //         actions: <Widget>[
    //           TextButton(
    //             child: Text(context.l10n.done),
    //             onPressed: () {
    //               Navigator.of(context).pop();
    //             },
    //           ),
    //         ],
    //       );
    //     },
    //   );
    // }
    /*
    // ========== WEB COLOR PICKER (USE FOR WEB BUILDS) ==========
    // showDialog(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return AlertDialog(
    //       title: Text(label ?? '${context.l10n.selectColor}'),
    //       content: SingleChildScrollView(
    //         child: ColorPicker(
    //           pickerColor: startingColor,
    //           onColorChanged: onColorChanged,
    //         ),
    //       ),
    //       actions: <Widget>[
    //         TextButton(
    //           child: Text(context.l10n.done),
    //           onPressed: () {
    //             Navigator.of(context).pop();
    //           },
    //         ),
    //       ],
    //     );
    //   },
    // );
    */

    // ===========================================
    // END COLOR PICKER SELECTION
    // ===========================================
  }
}
