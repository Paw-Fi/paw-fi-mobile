// Stub implementation for web platform
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
          title: const Text('Select color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: startingColor,
              onColorChanged: onColorChanged,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Done'),
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
