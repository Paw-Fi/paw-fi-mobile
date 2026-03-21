import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneko/core/app/flutter_error_reporter.dart';

void main() {
  test('shouldReportFatalFlutterError returns false for HttpException', () {
    final result = shouldReportFatalFlutterError(
      const HttpException('Connection closed before full header was received'),
    );

    expect(result, isFalse);
  });

  test('shouldReportFatalFlutterError returns true for non-network errors', () {
    final result = shouldReportFatalFlutterError(StateError('bad state'));

    expect(result, isTrue);
  });
}
