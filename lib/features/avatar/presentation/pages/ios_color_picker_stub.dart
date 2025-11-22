// Stub implementation for web platform
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:moneko/core/l10n/l10n.dart';

class IOSColorPickerController {
  void showIOSCustomColorPicker({
    required Color startingColor,
    required Function(Color) onColorChanged,
    required BuildContext context,
  }) {
    // Fallback to flutter_colorpicker on web
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.l10n.selectColor),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: startingColor,
              onColorChanged: onColorChanged,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(context.l10n.done),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
